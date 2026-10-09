
# TRIQS family rules

- **Read `~/git/triqs/CLAUDE.md` first.** It is binding for environment, build/install,
  tests, failure triage, ChangeLog and the dftkit/dft_tools split.
- **Environment** (wahoo06 only, in this order):
  `module load vasp-gnu_mkl-dev/15.2_mkl-2026.0.0_ompi-5.0.10_py-3.14`, then
  `source ~/pyvenv/devpy/bin/activate`.
  - The module provides numpy, scipy, matplotlib and meson. Never `pip install` those into
    devpy; that shadowed them before.
  - The module name drifts; check `module -t avail | grep vasp-gnu_mkl-dev`.
- **devpy is the human's install prefix:** `make install` changes their working stack.
  Ask before installing.
- **Threads:** `OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1` for builds and
  tests. Use `ctest -j4` with ≤4 ranks per test. Every MPI rank otherwise opens 32 MKL
  threads.
- **Known non-regressions:**
  - Monte-Carlo tests are noisy under `mpirun`: re-run, and raise `n_cycles_tot`, not the
    seed.
  - Stale `ref.h5` after h5/TRIQS changes.
  - `mesh_dlr_stability` moves with cppdlr `main`.
- **GitHub `TRIQS/*` is public:**
  - Development goes on `unstable` (ase-driver: `dev`) via feature branch + PR, so CI runs.
  - Merging, force pushes and pushes to `unstable`/`X.Y.x` are the human's.
  - Branch names `<type>-<slug>`, e.g. `feat-continue-after-ncycles`.
- **ChangeLog:** unreleased entries go under `## Unstable` in `doc/ChangeLog.md`.
