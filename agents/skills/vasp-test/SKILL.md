---
name: vasp-test
description: |
  Run VASP's regression testsuite (testsuite/runtest, invoked by `make test`). Tests are FULL
  VASP runs whose energies/forces/stress are compared against stored references. Selects specific
  tests via VASP_TESTSUITE_TESTS, wires up the VASP_TESTSUITE_EXE_{STD,NCL,GAM} launch commands
  (using the toolchain .conf templates in ~/git/vasp/*.conf), uses 4 MPI ranks (refs were generated
  with 4), binds one MPI rank per GPU for GPU builds, and scans output for "ERROR:" failures.
  Use when: running VASP tests, "run the testsuite", "make test", testing a VASP code change,
  running a regression/reference test, checking a specific test case (e.g. CrS_RPR), or validating a build.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
---

# Running the VASP testsuite

## What the tests actually are (read this first)
Each entry under `testsuite/tests/<name>/` is a **complete VASP calculation** (its own INCAR/POSCAR/
KPOINTS/POTCAR) plus a `runrecipe.sh` that runs VASP and then compares the result against committed
reference values — typically `check_energy` / `check_forces` / `check_stress` (see any
`runrecipe.sh`). So these are **end-to-end regression tests of full SCF/relaxation/GW/… runs**, not
unit tests. A test passes if its numbers match the reference within tolerance; it **fails by printing
a line containing `ERROR:`**. Because the references were generated with a specific parallel layout,
the run setup (rank count, mapping) matters — see below.

## How it's driven
- Top dir: `make test` → `testsuite/runtest --fast`. CMake build: `make test` (or
  `cmake --build <builddir> --target test`) copies the testsuite into the build dir and runs the
  same `runtest --fast`.
- **CMake caveat — the testsuite is copied into the build dir only when the `test` target runs.**
  The cmake `test` target depends on `copy_tests`, which rsyncs `testsuite/` →
  `<builddir>/testsuite/` (including `runtest`). So on a fresh build dir `<builddir>/testsuite/runtest`
  does **not** exist yet. Before invoking `runtest` directly in a build dir, **check it's there**;
  if not, either run `make test` (or `--target test`) once to populate it, or run from the source
  tree's `testsuite/` instead:
  ```bash
  ls <builddir>/testsuite/runtest 2>/dev/null || echo "not copied yet — run 'make test' once, or use <src>/testsuite"
  ```
- `runtest [--fast|--all] [conf]` sources the optional **conf** file (`$1`), which must export the
  launch commands and (optionally) the test list. A **non-empty `VASP_TESTSUITE_TESTS` overrules**
  the `--fast`/category selection, so it's the clean way to run exactly the tests you want.
- You **must** set, before running, the executables (else it falls back to `mpirun -np 4 ../bin/vasp_std`):
  - `VASP_TESTSUITE_EXE_STD`, `VASP_TESTSUITE_EXE_NCL`, `VASP_TESTSUITE_EXE_GAM`
  - each is a full launch line: `mpirun <mpi flags> [<gpu -x flags>] <VASP_PATH>/bin/vasp_<std|ncl|gam>`
  - if `EXE_NCL`/`EXE_GAM` are empty, the NCL/Γ tests are skipped.

## Step 0 — environment
The **same toolchain module used to build** must be loaded (runtime MKL/MPI/CUDA come from it) — see
the `vasp-build` skill. Then:
```bash
module list 2>&1 | grep -i vasp
nvidia-smi -L 2>/dev/null || echo "no GPU"     # GPU build? how many GPUs?
nproc
```
Know your **VASP_PATH** = the dir that contains `bin/vasp_std` (a CMake `build_<tc>/` dir, or the
source root for the classic build).

## Step 1 — pick the test(s)
- If the user named tests, use them. Names are exactly the folder names in `testsuite/tests/`.
- To find tests relevant to a code change, **ask the user**, or grep the category tags:
  ```bash
  grep -l 'CATEGORY=.*\bSOC\b' testsuite/tests/*/runrecipe.sh     # e.g. all SOC tests
  sed -n '1,15p' testsuite/tests/CrS_RPR/runrecipe.sh             # see one test's CATEGORY + checks
  ```
  Categories (from `runtest`): `ACFDT BSE CRPA DIEL EFOR ELPHON FAST GAMMA GW HDF5 HYB IVDW KOPT
  LIBXC LREAL LRESP LTMP2 MD ML NCL NCORE1 NOSYM OPTIC PEAD PHELEL PYTHON RPA SOC TBMD TDDFT VASP6
  WAN90 LFS META LASPH ISPIN`. A good cheap smoke test is `CrS_RPR` (LREAL FAST ISPIN).

## Step 2 — choose the launch layout
- **CPU:** **4 MPI ranks** — this is how the references were generated, so it's the safe default.
  8 or 16 ranks are also fine. **Avoid non‑power‑of‑two rank counts (e.g. 6) and odd PE mappings** —
  they change the parallel reduction order and can push results past the reference tolerance (false
  failures). Use a clean NUMA/core binding:
  ```bash
  nranks=4; nthrds=4
  mpi="-np $nranks --map-by numa:PE=$nthrds --bind-to core"
  export OMP_NUM_THREADS=$nthrds MKL_NUM_THREADS=$nthrds OMP_STACKSIZE=2048m \
         OMP_PLACES=cores OMP_PROC_BIND=close OMP_WAIT_POLICY=PASSIVE
  ```
- **GPU:** **one MPI rank is bound to one GPU, always.** So set **`nranks` = number of GPUs**
  (`nvidia-smi -L | wc -l`). On a single-GPU box that means `nranks=1`. Do not over/under-subscribe.
  ```bash
  nranks=1; nthrds=4    # nranks == #GPUs
  mpi="-np $nranks --map-by node:PE=$nthrds --bind-to core"
  gpu=""                # optional -x passthroughs, e.g. -x VASP_CUBLAS_MATH_MODE=...
  ```

## Step 3 — run
**Preferred: use a toolchain conf template** in `~/git/vasp/` (these set the OMP/MPI/GPU env, the EXE
lines, and the test list in one place): `gnu.conf`, `intel.conf`, `nvidia_gpu.conf`, `amd_gpu.conf`,
`intel_gpu.conf`, `cray_cpu.conf`, `nec.conf`. Copy one, set **`VASP_PATH`** (explicit, not `$PWD`),
set **`VASP_TESTSUITE_TESTS`**, and run:
```bash
cd <vasp-source-root>/testsuite
./runtest /abs/path/to/your.conf 2>&1 | tee testsuite.log
```
**Or inline**, without a conf file:
```bash
cd <vasp-source-root>/testsuite
VASP_PATH=/abs/path/to/build_or_src
export VASP_TESTSUITE_TESTS="CrS_RPR"
export VASP_TESTSUITE_EXE_STD="mpirun $mpi $gpu $VASP_PATH/bin/vasp_std"
export VASP_TESTSUITE_EXE_NCL="mpirun $mpi $gpu $VASP_PATH/bin/vasp_ncl"
export VASP_TESTSUITE_EXE_GAM="mpirun $mpi $gpu $VASP_PATH/bin/vasp_gam"
./runtest 2>&1 | tee testsuite.log     # no --fast: the explicit TESTS list is run
```
(`make test` from the root / cmake build dir also works once `VASP_TESTSUITE_TESTS` and the EXE vars
are exported — it just adds `--fast`, which the explicit list overrules.)

## Step 4 — read the result
```bash
grep -nE "ERROR:|CASE:|PASSED|FAILED" testsuite.log | tail -40
grep -c "ERROR:" testsuite.log        # 0 = all selected tests passed
```
- **Any `ERROR:` line = a failed check.** Report which test and which check (energy/forces/stress) and
  the expected-vs-actual numbers that `runtest` prints around it.
- A test can also be **skipped** (e.g. `SKIP_NCL`, missing HDF5/Wannier90/Python, or a category set to
  `Y` to skip) — skipped ≠ passed; say so.
- Per-test work happens under a scratch `WORK/<test>/` (the recipe does `cd $WORK/$JOB`); the run's
  OUTCAR/OSZICAR live there if you need to inspect a failure.

## Step 5 — clean up test output
Test runs leave output (`WORK/`, per-test artifacts, `testsuite.log`, the compiled `compare_numbertable_new`
tool) inside the `testsuite/` dir. Clean it with the dedicated **`cleantest`** target (run inside the
`testsuite/` folder, or the build dir's copy):
```bash
cd <vasp-source-root>/testsuite   # or <builddir>/testsuite
make cleantest                    # runs tests/cleanall + removes the numbertable tool
```
Note: `cleantest` is a **testsuite** target, separate from the **build's** `make veryclean` (vasp-build
skill). It only touches test output, not the compiled binaries. The top-level makefile exposes
`test`/`test_all` but not `cleantest`, so call it from `testsuite/` (or `make -C testsuite cleantest`).

## Gotchas
- **Load the build's toolchain module** before testing; a mismatch (wrong MKL/MPI/CUDA) causes crashes
  or bogus diffs.
- **CMake: `runtest` is only in the build dir after the `test` target has run once** (it's rsynced by
  `copy_tests`). Check before calling it directly; otherwise run from the source `testsuite/`.
- **Rank count discipline:** 4 (default) / 8 / 16 on CPU; `#GPUs` on GPU. Never 6 or odd mappings.
- **`VASP_PATH` must point at the dir containing `bin/`** — for a CMake build that's `build_<tc>/`,
  not the source root.
- Don't commit edits to the shared `~/git/vasp/*.conf` templates unless asked; copy them per-run.
- GPU `-x` passthroughs (e.g. `VASP_CUBLAS_MATH_MODE`, `CUDA_VISIBLE_DEVICES`) go in the `gpu=` string;
  see `~/git/vasp/nvidia_gpu.conf` for worked examples.
