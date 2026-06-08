---
name: vasp-build
description: |
  Build VASP (Vienna Ab initio Simulation Package) on the VASP-dev cluster using the
  loaded environment module toolchain. Prefers the CMake build (cmake/ is a git submodule);
  falls back to the classic makefile.include build only when asked. Handles toolchain/module
  selection (intel / gnu / nvhpc), CPU vs GPU builds, the vasp_std/vasp_gam/vasp_ncl targets,
  and the right per-toolchain build directory.
  Use when: building VASP, compiling VASP, "build vasp_std", "recompile VASP", rebuilding after
  source edits, setting up a VASP build dir, configuring cmake for VASP, or doing a GPU/OpenACC VASP build.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
---

# Building VASP

Build VASP from a source tree (a dir containing `src/`, `arch/`, `CMakeLists.txt` → `cmake/CMakeLists/...`,
and `makefile.include`). **Prefer CMake.** Only use the classic makefile build if the user asks for it.

Work from the VASP source root (where `src/` lives). If the cwd isn't a VASP tree, ask which one.

---

## Step 0 — Inspect the environment (always do this first)

```bash
module list 2>&1 | grep -i vasp     # which vasp-*-dev toolchain is loaded?
hostname                            # which box?
nvidia-smi -L 2>/dev/null || echo "no GPU"   # GPU present?
nproc                               # cores for -j
```

Decide the **toolchain family** from the loaded module name:

| loaded module prefix | family | CMake build dir | GPU? |
|---|---|---|---|
| `vasp-intel-dev/*` | Intel oneAPI + MKL | `build_intel` | CPU |
| `vasp-gnu_mkl-dev/*`, `vasp-gnu-dev/*`, `vasp-gnu_aocl-dev/*` | GNU | `build_gnu` | CPU |
| `vasp-aocc-dev/*` | AOCC + AOCL | `build_aocc` | CPU |
| `vasp-nvhpc-dev/*`, `vasp-nvhpc_mkl-dev/*` | NVHPC | `build_nvhpc` | **GPU** (OpenACC) |

**Module rules:**
- If a `vasp-*-dev` module is already loaded, **use it** — do not switch it.
- If none is loaded, pick one from context (the user's request, the source tree's notes, the host).
  If still unclear, ask — or default to:
  `module load vasp-gnu_mkl-dev/15.2_mkl-2026.0.0_ompi-5.0.9_py-3.14`
- **GPU build trigger:** an `vasp-nvhpc*` module is loaded **and** `nvidia-smi` shows a GPU →
  build the OpenACC GPU binary. An nvhpc module with no GPU on the host → usually still a
  CPU/host build; confirm intent.
- **Python** (needed by some build/codegen steps) lives in a venv, activated with:
  `source $HOME/pyvenv/devpy/bin/activate`
  (the default gnu module bundles `py-3.14`; activate the venv when a step needs Python.)

Also check the source tree for project-specific build notes (`CLAUDE.md`, `AGENTS.md`, `PLAN.md`) —
some branches pin a CPU target flag (e.g. `-tp=haswell`) or a specific cmake submodule commit. Honor those.

---

## Step 1 — CMake build (preferred)

`cmake/` is a **git submodule**. The top-level `CMakeLists.txt` is a symlink into
`cmake/CMakeLists/`. **Only ever modify files inside the `cmake/` subdirectory** — never the
generated symlinks or the source tree's build scaffolding outside `cmake/`. Do **not** bump the
submodule to a newer commit unless explicitly asked (it can flip target flags and break the build).

### 1a. One-time setup (if needed)
```bash
git submodule update --init cmake          # if cmake/ is empty
test -e CMakeLists.txt || cmake/setup.sh   # creates the CMakeLists.txt symlinks
```

### 1b. Choose / find the build directory
Reuse an existing per-toolchain build dir if present (it may be a symlink to fast local disk);
otherwise create one named for the family (`build_gnu`, `build_intel`, `build_nvhpc`).
```bash
BUILD=build_gnu        # set per the table in Step 0
ls -d "$BUILD" 2>/dev/null || echo "will create $BUILD"
```

### 1c. Configure

**CPU build** — add these unless the user specifies otherwise:
```bash
cmake -S . -B "$BUILD" \
  -DCMAKE_BUILD_TYPE=Release \
  -DVASP_HDF5=ON -DVASP_OPENMP=ON -DVASP_WANNIER90=ON -DVASP_LIBXC=ON -DVASP_PROFILING=ON
```

**GPU build (NVHPC / OpenACC)** — CUDA is auto-detected; do **not** force LibXC (CMake disables it
for the NVIDIA OpenACC port) and leave Wannier/OpenMP off unless asked:
```bash
cmake -S . -B "$BUILD" \
  -DCMAKE_BUILD_TYPE=Release \
  -DVASP_HDF5=ON -DVASP_PROFILING=ON \
  -DCMAKE_CUDA_ARCHITECTURES=native
# If nvhpc's bundled gcc is too old for a CUDA/C++ dependency, point nvcc at a newer host g++:
#   -DCMAKE_CUDA_HOST_COMPILER=g++     (needs gcc 10–14)
```
Re-configuring an existing build dir preserves prior cache values; only pass the `-D` flags you want
to change. Pass any extra `-D...` the user requests verbatim.

### 1d. Build the target(s)
CMake targets are **`vasp_std`, `vasp_gam`, `vasp_ncl`**. Build the one the user named; if none
specified, build all three.
```bash
cmake --build "$BUILD" --target vasp_std -j"$(nproc)"
# all three:
# for t in vasp_std vasp_gam vasp_ncl; do cmake --build "$BUILD" --target $t -j"$(nproc)"; done
```
The binaries land in `"$BUILD"/bin/` (and/or the install prefix). Report the path and confirm it's
freshly built (`ls -la "$BUILD"/bin/vasp_std`).

---

## Step 2 — Classic makefile build (only when the user asks for "the old build" / "without cmake")

Targets here are **`std`, `gam`, `ncl`** (not the `vasp_` names). The build is **not** auto-parallel —
you must pass `-j` yourself, and `DEPS=1` regenerates dependencies.

### 2a. Pick a toolchain template
`arch/` holds `makefile.include.<toolchain>` templates (e.g. `gnu`, `gnu_ompi_mkl_omp`, `intel`,
`intel_ompi_mkl_omp`, `nvhpc_acc`, `nvhpc_ompi_mkl_omp_acc`, `aocc_ompi_aocl`, …). `./makefile.include`
is a symlink/copy of the chosen template. The `CPP_OPTIONS` precompiler flags in it enable VASP
features (MPI, scaLAPACK, HDF5, OpenACC `-DACC_OFFLOAD -DNVCUDA`, profiling `-DPROFILING`, etc.) —
they matter; pick the template matching the loaded module + CPU/GPU intent.
```bash
ls arch/makefile.include.*                       # list templates
ln -sf arch/makefile.include.gnu_ompi_mkl_omp makefile.include   # or the matching one
# GPU example: ln -sf arch/makefile.include.nvhpc_ompi_mkl_omp_acc makefile.include
```
(If the tree already has a working `makefile.include` symlink, keep it unless told otherwise.)

### 2b. Build (manual parallelism)
```bash
make DEPS=1 -j"$(nproc)" std        # or gam / ncl ; DEPS=1 = (re)build dependency lists
```

### 2c. Clean
`make clean` does **not** exist. Use:
```bash
make veryclean
```

Binaries land in `bin/{vasp_std,vasp_gam,vasp_ncl}`.

---

## Gotchas / rules

- **CMake submodule:** edit only under `cmake/`; don't change the pinned submodule commit unless asked.
- **CPU default flags** (HDF5/OpenMP/Wannier90/LibXC/Profiling) apply to CMake CPU builds only;
  drop LibXC for GPU/OpenACC builds.
- **Don't switch a loaded module.** Reuse it. Only load one if none is active.
- **`make veryclean`**, never `make clean`, for the classic build.
- **Per-toolchain build dirs** keep CPU/GPU/intel/gnu artifacts from clobbering each other.
- After a successful build, state which binary/binaries were produced and where, and whether it was
  a CPU or GPU build and with which module.
- If a build fails, surface the first real compiler error (not just the final make error), and check:
  right module loaded? cmake submodule initialized? stale build dir (reconfigure or recreate)?
