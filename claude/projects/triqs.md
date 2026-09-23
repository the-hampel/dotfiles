# TRIQS development tree

`~/git/triqs` holds local git checkouts of the TRIQS core library and its
applications. Each subdirectory is an independent git repo with its own branch
and its own out-of-source `build/` directory.

This file is machine agnostic except for the environment section below. It
lives in `~/git/dotfiles/claude/projects/triqs.md` and is symlinked to
`~/git/triqs/CLAUDE.md`, so edit it there and it follows to every machine.

## Environment (do this first, in this order)

Pick the block for the machine you are on; everything after this section is the
same everywhere.

### VASP cluster (hostname `*.vasp.co`)

```bash
module load vasp-gnu_mkl-dev/15.2_mkl-2026.0.0_ompi-5.0.10_py-3.14
source ~/pyvenv/devpy/bin/activate
```

- The **module** provides the toolchain (gcc / MKL / OpenMPI) and the scientific
  Python stack (numpy, scipy, h5py, mpi4py, matplotlib, ase, …), exposed via
  `PYTHONPATH`. Without it `import numpy` fails.
- The **venv** `~/pyvenv/devpy` is created with `--system-site-packages` on top
  of that Python. **It is also the CMake install prefix**
  (`CMAKE_INSTALL_PREFIX=$VIRTUAL_ENV`), so `make install` drops compiled
  modules and Python packages into the venv's `site-packages`. Activating the
  venv is what makes `triqs`, `triqs_dft_tools`, `triqs_dftkit`, … importable.
- Order matters: load the module **before** activating the venv (the venv
  inherits the module's `PYTHONPATH`).
- **The module name drifts** when the toolchain is rebuilt (the OpenMPI part has
  already moved 5.0.9 → 5.0.10). Check `module -t avail | grep vasp-gnu_mkl-dev`
  before trusting the string above. Loading a name that no longer exists fails
  *quietly* if you redirect stderr, and the next symptom is `ImportError:
  libhdf5.so.310: cannot open shared object file` from `import h5`. That looks
  like a broken TRIQS install but is only a missing module — check `ldd` on a
  `.so` under the venv's `site-packages` before rebuilding anything.

### macOS

<!-- TODO: fill in (homebrew/conda toolchain, venv path, any DYLD/PATH notes) -->

## Repos and how they relate

Build in dependency order; `update_triqs_stack.sh` (below) encodes it as:

```
triqs dftkit modest cthyb ctseg hubbardI hartree_fock maxent dft_tools solid_dmft
```

| dir              | what it is                          |
|------------------|-------------------------------------|
| `triqs/`         | TRIQS core library (build first)    |
| `dftkit/`        | DFT converters (PLOVASP/VASP, w90, …) |
| `dft_tools/`     | DFTTools (VASP/Wien2k/… interfaces) |
| `modest/`        | VASP CSC driver / interface         |
| `solid_dmft/`    | solid_dmft (DMFT workflow)          |
| `cthyb/`, `ctseg/`, `hubbardI/`, `hartree_fock/`, `maxent/` | impurity solvers / tools |
| `nda/`, `h5/`    | C++ dependencies of TRIQS core      |
| `solid_dmft33x/` | solid_dmft pinned to the 3.3.x line |

## Updating the whole stack

`./update_triqs_stack.sh` (symlink to `~/git/dotfiles/tools/`) is the normal way
to bring everything up to date. It walks the repos in dependency order and, for
each one that actually received new commits (or whose build is unconfigured),
cleans the build dir and runs configure → make → ctest → `make install`.

- Tests pass → installs automatically. Tests fail → prompts, unless
  `--install-on-fail` / `--no-install-on-fail`.
- A successful **triqs** install forces every dependent repo to rebuild.
- Useful flags: `--force` (rebuild everything), `--no-test`, `--no-pull`.
- Per-repo logs plus a `summary.txt` land in `~/git/triqs/triqs_stack_logs/<timestamp>/`.
- Preconditions: a venv must be active (`$VIRTUAL_ENV`) and the toolchain module
  loaded. Only the venv is enforced; the module name in the script header is not
  checked and can go stale like the one above.

Use the manual loop below when iterating on a single repo.

## Building and installing (single repo)

**The code only lives in the Python environment after you build AND install it.**
The runtime imports the **installed copies** in the venv's `site-packages`, not
the source tree. Editing a `.py` (or `.cpp`) has *no* runtime effect until you
rebuild and `make install`.

```bash
cd <repo>/build
cmake ..          # only needed the first time / after CMakeLists changes
make -j           # or: make -j <n>
make test         # optional: run the ctest suite
make install      # REQUIRED so the change lands in the venv site-packages
```

Skip `make install` and you will be running the previously installed version —
a common source of "my edit did nothing" confusion. For a quick Python-only
check without installing, point at the source with `PYTHONPATH=<repo>/python`.

## Running tests

`make test` runs the whole ctest suite for a repo. To iterate on one Python test
without installing, copy the fixture files next to it — the tests open data by
**relative** path, so they only work from a directory that holds them:

```bash
mkdir -p /tmp/t && cd /tmp/t
cp <repo>/test/python/<test>.py .            # plus its .h5 / data files
PYTHONPATH=<repo>/python:$PYTHONPATH python3 -m unittest <test>
```

The data is not always next to the test: solid_dmft's
`test_plot_correlated_bands` reads `svo*.h5` / `svo_hr.dat` from
`doc/tutorials/correlated_bandstructure/`, copied in by
`test/python/CMakeLists.txt`.

Integration tests run under MPI: ctest launches `mpirun -n ${TEST_NUM_PROC}
python3 test.py`, with `TEST_NUM_PROC` defaulting to 4 (or the core count if
lower) and overridable with `-DTEST_NUM_PROC=N`.

**OpenMPI 5 renamed the MCA env vars.** Mapping and binding moved to PRRTE, so
`PRTE_MCA_hwloc_default_binding_policy` / `PRTE_MCA_rmaps_default_mapping_policy`
are the ones that take effect; the old `OMPI_MCA_hwloc_base_binding_policy` /
`OMPI_MCA_rmaps_base_oversubscribe` are **silently ignored**. Without binding
disabled, concurrent `ctest -j` jobs each start their mpirun at core 0 and pile
onto the same cores.

## Failures that are not caused by your change

Check these before debugging your own diff:

- **Monte-Carlo solver tests are not reproducible under `mpirun`, whatever seed
  you set.** `mc_generic`'s `continue_after_ncycles_done` (default `true`) lets a
  rank that finished its cycles keep doing moves *and measurements* until the
  others land, and that stop is polled on **wall clock**
  (`check_cycles_interval = 1 s`). So the sample count depends on machine load,
  and short runs are dominated by it. It applies at `-n 1` too, because the
  monitor is created whenever `mpi::has_env` is true, i.e. whenever launched by
  `mpirun`. Neither cthyb nor ctseg exposes the flag (TRIQS/cthyb#193). Running
  `python3 test.py` *without* `mpirun` is bit-reproducible. Practical
  consequence: an intermittent cthyb/ctseg failure is usually thin statistics,
  not a regression — re-run before investigating, and fix it by raising
  `n_cycles_tot`, not by pinning `random_seed`.
- **Stale `ref.h5` after an h5/TRIQS change.** h5 PR#45 flipped the stored GF
  block order (`up_*` now before `down_*`) and `assert_block_gfs_are_close` needs
  matching order, so old references fail with `block name up_0 does not match
  down_0`. Regenerate the reference and confirm only the order moved.
- **`mesh_dlr_stability` in TRIQS core.** `deps/CMakeLists.txt` pins cppdlr with
  `GIT_TAG main`, a moving branch, while the test locks DLR node selection to
  1e-14 and *exact* integer `ifnodes`. Any cppdlr change breaks it with no TRIQS
  commit involved.

Reading CI logs without leaving the shell: GitHub Actions via `gh run list` /
`gh run view <id> --log-failed`; Flatiron Jenkins is public, so
`curl -sS <build-url>/consoleText` beats the web UI (and beats `WebFetch`, which
truncates long logs).

## ChangeLog convention

Released sections are frozen. Entries for unreleased work go in a `## Unstable`
section at the top of `doc/ChangeLog.md`, renamed to the version number when the
release is cut; on a maintenance branch use the concrete `## Version X.Y.Z`
instead. Before moving an entry out of a released section, verify it really is
unreleased with `git show <tag>:doc/ChangeLog.md` — **`git tag --contains <sha>`
is not a reliable test**, since content can reach a release through a different
commit than the one on `unstable`.

## dft_tools ↔ dftkit

The PLOVASP / VASP converter code lives in **`dftkit`**. `dft_tools` no longer
contains it on `unstable`; `dft_tools/python/triqs_dft_tools/converters/` just
re-exports from `triqs_dftkit`.

dftkit is consumed as a **separately installed package**, not vendored: build
and install `dftkit` before `dft_tools` and `modest`, which is why it sits
second in the dependency order above. (It used to be fetched via CPM from
GitHub; that is no longer the case, so there is no `CPM_dftkit_SOURCE` override
to worry about.) Since the link is a plain Python import, a change in the local
`dftkit` checkout reaches `dft_tools` as soon as dftkit is reinstalled.

On the older **3.3.x** branch of `dft_tools` the converter code still lives
in-tree (`python/triqs_dft_tools/converters/plovasp/`); there is no dftkit there.

## Branches

Most repos sit on `unstable` (the development branch); maintenance happens on
`X.Y.x` branches (e.g. `3.3.x`). Some repos are checked out on feature branches.
Check with `git -C <repo> branch --show-current` before committing.
