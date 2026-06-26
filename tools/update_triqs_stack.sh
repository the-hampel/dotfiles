#!/bin/bash
#
# update_triqs_stack.sh
# ---------------------
# Traverse the TRIQS source repos under ~/git/triqs (in dependency order),
# pull new changes, and for every repo that actually received new commits
# (or whose build is not yet configured) clean its build dir, then:
#     configure + make   ->   ctest   ->   make install
# The cmake/make flags mirror ~/git/dotfiles/tools/make_dev.sh.
#
# Install policy:
#   * tests pass  -> install automatically
#   * tests fail  -> prompt whether to install anyway (or use a flag below)
#   * --no-test   -> install automatically (no tests run)
# A successful install of triqs forces every dependent repo to rebuild.
#
# Per-repo logs are written under a timestamped log dir:
#   <repo>_build.log   cmake + make + (make install) output
#   <repo>_test.log    ctest output
#   <repo>_pull.log    git pull output
#   summary.txt        the final table + collected failed tests
#
# Preconditions (checked up front, aborts if missing):
#   * a python venv is active   ($VIRTUAL_ENV set)
#   * the module
#     vasp-gnu_mkl-dev/15.2_mkl-2026.0.0_ompi-5.0.9_py-3.14 is loaded
#
# Options:
#   --force                rebuild every repo even if no new changes were pulled
#   --no-test              skip ctest (install runs automatically)
#   --no-pull              don't run git pull (build per --force / unconfigured)
#   --install-on-fail      install even when tests fail (no prompt)
#   --no-install-on-fail   never install when tests fail (no prompt)
#   -h|--help              show this help

# NOTE: deliberately NOT using `set -e` -- we want one failing repo to be
# logged and the traversal to continue.
set -uo pipefail

# ---- configuration ---------------------------------------------------------
ROOT="$HOME/git/triqs"

# repos in build / dependency order
# NB: dftkit must come before the packages that depend on it (dft_tools,
# solid_dmft). It used to be bundled via CPM, but modest (0d82894) and dft_tools
# (09876517) now consume it as a separately-installed package, so it has to be
# built+installed before them.
REPOS=(triqs dftkit modest cthyb ctseg hubbardI hartree_fock maxent dft_tools solid_dmft)

NC_TEST=4                      # MPIEXEC_MAX_NUMPROCS, matches make_dev.sh
NCORE="${NCORE:-8}"            # parallel make jobs (8 = safe default if unset)
CTEST_JOBS=8

# ---- options ---------------------------------------------------------------
FORCE=false
DO_TEST=true
DO_PULL=true
INSTALL_ON_FAIL=ask            # ask | yes | no  -- what to do when tests fail
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)   FORCE=true;   shift ;;
        --no-test) DO_TEST=false; shift ;;
        --no-pull) DO_PULL=false; shift ;;
        --install-on-fail)    INSTALL_ON_FAIL=yes; shift ;;
        --no-install-on-fail) INSTALL_ON_FAIL=no;  shift ;;
        -h|--help)
            sed -n '2,34p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

# ---- preconditions ---------------------------------------------------------
fail() { echo "ERROR: $*" >&2; exit 1; }

[[ -n "${VIRTUAL_ENV:-}" ]] || fail "no python venv active (VIRTUAL_ENV is unset). Activate your venv first."

: "${TRIQS_ROOT:=$VIRTUAL_ENV}"   # install prefix, as in make_dev.sh

# ---- log setup -------------------------------------------------------------
STAMP="$(date +%Y%m%d_%H%M%S)"
LOGDIR="$ROOT/triqs_stack_logs/$STAMP"
mkdir -p "$LOGDIR"
SUMMARY="$LOGDIR/summary.txt"

log() { echo -e "$*" | tee -a "$SUMMARY"; }

log "TRIQS stack update  ($STAMP)"
log "  source root : $ROOT"
log "  install pfx : $TRIQS_ROOT"
log "  venv        : $VIRTUAL_ENV"
log "  make -j     : $NCORE     ctest -j: $CTEST_JOBS     mpi procs: $NC_TEST"
log "  options     : force=$FORCE test=$DO_TEST pull=$DO_PULL"
log "  logs        : $LOGDIR"
log ""

# ---- per-repo work ---------------------------------------------------------
# accumulate summary rows
declare -a ROW_REPO ROW_BRANCH ROW_PULL ROW_BUILD ROW_TEST ROW_INSTALL

# set once triqs has been installed successfully: forces all dependent repos
# to rebuild against the freshly installed triqs even if they had no new commits.
force_rest=false

# push one summary row from the current per-repo state vars
push_row() {
    ROW_REPO+=("$repo");          ROW_BRANCH+=("${branch:--}")
    ROW_PULL+=("$pull_state");    ROW_BUILD+=("$build_state")
    ROW_TEST+=("$test_state");    ROW_INSTALL+=("$install_state")
}

# decide whether to install after a test failure (echo nothing; return 0=yes 1=no)
ask_install() {
    case "$INSTALL_ON_FAIL" in
        yes) echo "    [--install-on-fail] installing despite test failures"; return 0 ;;
        no)  echo "    [--no-install-on-fail] skipping install";              return 1 ;;
    esac
    if [[ -r /dev/tty ]]; then
        local ans
        read -r -p "    >>> $repo: tests FAILED. Install anyway? [y/N] " ans </dev/tty
        [[ "$ans" =~ ^[Yy] ]]
    else
        echo "    no TTY available for prompt -> skipping install (use --install-on-fail to override)"
        return 1
    fi
}

resolve_build_dir() {
    # echoes the real build directory for repo source dir $1, creating it if
    # needed. Honours an existing build symlink / dir.
    local src="$1" bld
    if [[ -e "$src/build" ]]; then
        bld="$(realpath "$src/build")"
    else
        bld="$src/build"
        mkdir -p "$bld"
    fi
    echo "$bld"
}

clean_build_dir() {
    local bld="$1"
    [[ -n "$bld" && "$bld" != "/" ]] || { echo "refusing to clean '$bld'"; return 1; }
    ( cd "$bld" && rm -rf -- ..?* .[!.]* ./* 2>/dev/null )
    return 0
}

for repo in "${REPOS[@]}"; do
    src="$ROOT/$repo"
    pull_state="-"; build_state="-"; test_state="-"; install_state="-"
    branch="$(git -C "$src" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    echo "============================================================"
    echo ">>> $repo  [${branch:-no-git}]"

    if [[ ! -d "$src/.git" ]]; then
        log ">>> $repo : SKIPPED (not a git repo at $src)"
        pull_state="n/a"; build_state="skip"; push_row
        continue
    fi

    # --- pull -------------------------------------------------------------
    before="$(git -C "$src" rev-parse HEAD 2>/dev/null)"
    changed=false
    if $DO_PULL; then
        pull_log="$LOGDIR/${repo}_pull.log"
        if git -C "$src" pull --ff-only >"$pull_log" 2>&1; then
            after="$(git -C "$src" rev-parse HEAD 2>/dev/null)"
            if [[ "$before" != "$after" ]]; then
                changed=true
                pull_state="updated"
                echo "    pulled new changes: ${before:0:8} -> ${after:0:8}"
            else
                pull_state="up-to-date"
                echo "    already up to date"
            fi
        else
            pull_state="PULL-FAIL"
            echo "    git pull FAILED (see $pull_log)"
            tail -n 3 "$pull_log" | sed 's/^/      /'
        fi
    else
        pull_state="skipped"
    fi

    # --- decide whether to build -----------------------------------------
    bld="$(resolve_build_dir "$src")"
    configured=false
    [[ -f "$bld/CMakeCache.txt" ]] && configured=true

    do_build=false
    if $changed; then do_build=true
    elif $FORCE;   then do_build=true
    elif $force_rest; then do_build=true; echo "    triqs was rebuilt -> forcing rebuild"
    elif ! $configured; then do_build=true; echo "    build not yet configured -> will build"
    fi

    if ! $do_build; then
        echo "    no rebuild needed"
        push_row
        continue
    fi

    # --- clean build dir --------------------------------------------------
    echo "    build dir : $bld"
    echo "    cleaning build dir..."
    if ! clean_build_dir "$bld"; then
        log ">>> $repo : build dir clean FAILED ($bld)"
        build_state="CLEAN-FAIL"; push_row
        continue
    fi

    # --- configure + build  (build log) ----------------------------------
    # NB: install is NOT done here -- it happens after tests pass (or after
    # explicit confirmation if tests fail).
    build_log="$LOGDIR/${repo}_build.log"
    echo "    building (log: $build_log)..."
    (
        unset PYTHON_ROOT
        cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
              -DCMAKE_INSTALL_PREFIX="$TRIQS_ROOT" \
              -DBuild_Documentation=OFF \
              -DUpdate_Python_Bindings=OFF \
              -DMPIEXEC_MAX_NUMPROCS="$NC_TEST" \
              -S "$src" -B "$bld" \
        && make -C "$bld" -j"$NCORE"
    ) >"$build_log" 2>&1
    build_rc=$?

    if [[ $build_rc -ne 0 ]]; then
        build_state="BUILD-FAIL"
        echo "    BUILD FAILED (rc=$build_rc)"
        tail -n 5 "$build_log" | sed 's/^/      /'
        push_row
        continue
    fi
    build_state="ok"
    echo "    build OK"

    # --- test (test log) --------------------------------------------------
    do_install=true        # default: install unless tests fail & not confirmed
    if $DO_TEST; then
        test_log="$LOGDIR/${repo}_test.log"
        echo "    testing (log: $test_log)..."
        ( cd "$bld" && ctest -j"$CTEST_JOBS" ) >"$test_log" 2>&1
        test_rc=$?

        # extract the FAILED block + summary line from the ctest log
        fail_block="$(awk '/The following tests FAILED:/{f=1} f{print} /^Errors while running CTest/{f=0}' "$test_log")"
        summary_line="$(grep -E '[0-9]+% tests passed' "$test_log" | tail -n1)"

        if [[ $test_rc -eq 0 ]]; then
            test_state="all pass${summary_line:+ ($summary_line)}"
            echo "    tests OK  ${summary_line}"
        else
            nfail="$(echo "$fail_block" | grep -cE '^[[:space:]]+[0-9]+ - ')"
            test_state="${nfail} FAILED"
            echo "    TESTS FAILED: $nfail"
            echo "$fail_block" | sed 's/^/      /'
            # tests failed -> ask (or use flag) whether to install anyway
            if ask_install; then do_install=true; else do_install=false; fi
        fi
    else
        test_state="skipped"
    fi

    # --- install (appended to build log) ---------------------------------
    if $do_install; then
        echo "    installing (make install)..."
        echo "=== make install ===" >>"$build_log"
        make -C "$bld" -j"$NCORE" install >>"$build_log" 2>&1
        if [[ $? -eq 0 ]]; then
            install_state="installed"
            [[ "$test_state" == *FAILED* ]] && install_state="installed (tests failed)"
            echo "    install OK"
            # a successful triqs install invalidates every dependent repo
            [[ "$repo" == "triqs" ]] && force_rest=true
        else
            install_state="INSTALL-FAIL"
            echo "    INSTALL FAILED"
            tail -n 5 "$build_log" | sed 's/^/      /'
        fi
    else
        install_state="skipped (tests failed)"
        echo "    install skipped"
    fi

    push_row
done

# ---- final summary ---------------------------------------------------------
log ""
log "============================================================"
log "SUMMARY"
log "============================================================"
printf "%-14s %-22s %-12s %-11s %-22s %s\n" "REPO" "BRANCH" "PULL" "BUILD" "TEST" "INSTALL" | tee -a "$SUMMARY"
for i in "${!ROW_REPO[@]}"; do
    printf "%-14s %-22s %-12s %-11s %-22s %s\n" \
        "${ROW_REPO[$i]}" "${ROW_BRANCH[$i]}" "${ROW_PULL[$i]}" "${ROW_BUILD[$i]}" "${ROW_TEST[$i]}" "${ROW_INSTALL[$i]}" \
        | tee -a "$SUMMARY"
done
log ""

# collect all failed tests across repos for a quick top-level view
echo "----- failed tests (all repos) -----" | tee -a "$SUMMARY"
any_fail=false
for repo in "${REPOS[@]}"; do
    tl="$LOGDIR/${repo}_test.log"
    [[ -f "$tl" ]] || continue
    fb="$(awk '/The following tests FAILED:/{f=1;next} /^Errors while running CTest/{f=0} f' "$tl")"
    if [[ -n "$fb" ]]; then
        any_fail=true
        echo "[$repo]" | tee -a "$SUMMARY"
        echo "$fb" | sed 's/^/  /' | tee -a "$SUMMARY"
    fi
done
$any_fail || echo "  none" | tee -a "$SUMMARY"

log ""
log "logs: $LOGDIR"

# exit non-zero if any build/install failed or any test failed
overall=0
for i in "${!ROW_REPO[@]}"; do
    case "${ROW_BUILD[$i]}"   in *FAIL*) overall=1 ;; esac
    case "${ROW_INSTALL[$i]}" in *FAIL*) overall=1 ;; esac
    case "${ROW_TEST[$i]}"    in *FAILED*) overall=1 ;; esac
done
exit $overall
