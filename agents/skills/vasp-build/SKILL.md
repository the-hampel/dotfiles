---
name: vasp-build
description: |
  Build VASP (Vienna Ab initio Simulation Package) on the VASP-dev cluster using the
  loaded environment module toolchain. Prefers the CMake build (cmake/ is a git submodule);
  falls back to the classic makefile.include build only when asked. Handles toolchain/module
  selection (intel / gnu / nvhpc / Cray CCE), CPU vs GPU builds, the vasp_std/vasp_gam/vasp_ncl
  targets, and the right per-toolchain build directory. Carries the cluster's node-to-GPU map:
  which slurm node has NVIDIA vs AMD vs Intel cards, and the build recipe for each
  (OpenACC on nvhpc, OpenMP target offload on ifx and crayftn).
  Use when: building VASP, compiling VASP, "build vasp_std", "recompile VASP", rebuilding after
  source edits, setting up a VASP build dir, configuring cmake for VASP, doing a GPU build
  (OpenACC / NVIDIA, OpenMP-offload / AMD MI210, OpenMP-offload / Intel Max), or asking which
  machine in the cluster has which GPU.
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
hostname                            # which box? -> cross-check against Step 0b
nproc                               # cores for -j
# which accelerator, if any -- only one of these will answer:
nvidia-smi -L 2>/dev/null || rocm-smi --showproductname 2>/dev/null \
  || xpu-smi discovery 2>/dev/null || echo "no GPU on this host"
```

Decide the **toolchain family** from the loaded module name:

| loaded module prefix | family | CMake build dir | GPU? |
|---|---|---|---|
| `vasp-intel-dev/*` | Intel oneAPI + MKL | `build_intel` | CPU |
| `vasp-gnu_mkl-dev/*`, `vasp-gnu-dev/*`, `vasp-gnu_aocl-dev/*` | GNU | `build_gnu` | CPU |
| `vasp-aocc-dev/*` | AOCC + AOCL | `build_aocc` | CPU |
| `vasp-nvhpc-dev/*`, `vasp-nvhpc_mkl-dev/*` | NVHPC | `build_nvhpc` | **GPU** (OpenACC, NVIDIA) |
| `vasp-intel-dev/*` **+ OMP offload asked for** | Intel oneAPI (ifx) | `build_intel_off` | **GPU** (OpenMP target, Intel) |
| Cray PE in the ccpe container (no host module) | Cray CCE 19 (`ftn`) | `build_cray_off` | **GPU** (OpenMP target, AMD) |

**Module rules:**
- If a `vasp-*-dev` module is already loaded, **use it** — do not switch it.
- If none is loaded, pick one from context (the user's request, the source tree's notes, the host).
  If still unclear, ask — or default to:
  `module load vasp-gnu_mkl-dev/15.2_mkl-2026.0.0_ompi-5.0.10_py-3.14`
  (versions churn — confirm with `module avail 2>&1 | tr ' ' '\n' | grep vasp-gnu_mkl-dev | sort -V | tail`)
- **GPU build trigger:** an `vasp-nvhpc*` module is loaded **and** `nvidia-smi` shows a GPU →
  build the OpenACC GPU binary. An nvhpc module with no GPU on the host → usually still a
  CPU/host build; confirm intent.
- **An nvhpc module gets you NVIDIA/OpenACC only.** AMD and Intel GPUs on this cluster use
  *OpenMP target offload* with a different compiler on a different node — see **Step 0b**
  for the node/vendor map and the per-vendor recipes.
- **Python** (needed by some build/codegen steps) lives in a venv, activated with:
  `source $HOME/pyvenv/devpy/bin/activate`
  (the default gnu module bundles `py-3.14`; activate the venv when a step needs Python.)

Also check the source tree for project-specific build notes (`CLAUDE.md`, `AGENTS.md`, `PLAN.md`) —
some branches pin a CPU target flag (e.g. `-tp=haswell`) or a specific cmake submodule commit. Honor those.

---

## Step 0b — Which machine has which GPU (VASP-dev slurm cluster)

**Check this table before assuming what accelerator a host has.** Three GPU vendors live on
three different boxes, the programming model differs per vendor, and the NVIDIA cards span
four compute-capability generations. Partition name == node name (`-p porgy05`);
`porgies` / `wahoos` are aggregate partitions.

The boxes actually worth targeting for GPU work:

| node | CPUs | accelerator | cc | programming model / toolchain |
|---|---|---|---|---|
| **`porgy05`** | 96 | **4x AMD Instinct MI210**, 64 GB (`gfx90a`) | — | **OpenMP target offload** — Cray CCE 19, **only inside the ccpe container** |
| **`guppy07`** | 112 | **2x Intel Data Center GPU Max 1100** (PVC) | — | **OpenMP target offload** — `vasp-intel-dev` (ifx) |
| **`guppy06`** | 48 | **2x NVIDIA A100-SXM4-80GB** | `80` | **OpenACC** — `vasp-nvhpc_mkl-dev` / `vasp-nvhpc-dev` |
| **`wahoo04`** | 64 | **1x RTX PRO 6000 Blackwell Max-Q**, 96 GB | `120` | OpenACC — **needs nvhpc ≥ 25.3** (see below) |

The rest of the NVIDIA fleet, all OpenACC via nvhpc, one card each unless noted:

| node | CPUs | GPU | mem | cc |
|---|---|---|---|---|
| `porgy04` | 128 | 2x A30 | 24 GB | `80` |
| `wahoo07` | 64 | RTX 5060 Ti | 16 GB | `120` (nvhpc ≥ 25.3) |
| `wahoo03` | 64 | RTX 4090 | 24 GB | `89` |
| `wahoo05`, `wahoo06` | 64, 32 | RTX 4060 Ti | 16 GB | `89` |
| `wahoo01`, `wahoo02` | 96 | Quadro GP100 | 16 GB | `60` |

CPU-only: `porgy01`–`porgy03` (128c), `guppy05` (24c).

Don't guess when it matters — verify. **Use `sinfo -a`**: plain `sinfo` hides most of these
partitions, which is an easy way to conclude a node doesn't exist.
```bash
sinfo -a -o "%14N %12P %6c %26G %10T"                    # gres carries no GPU *type*
ssh <node> nvidia-smi --query-gpu=name,compute_cap,memory.total --format=csv,noheader
srun -p <node> -n1 -c1 --gres=gpu:1 rocm-smi --showproductname       # AMD
srun -p <node> -n1 -c1 --gres=gpu:1 xpu-smi discovery                # Intel
```

**`.gitlab-ci.yml` in the source tree is the authoritative build recipe** — jobs
`cray_omp_off_build`, `oneapi_omp_off_build`, `nvhpc*_build` pin the module versions,
partitions and arch templates actually known to work. Read it when in doubt.

### AMD MI210 OpenMP offload → `porgy05`, Cray CCE in a container

There is **no host module for the Cray PE** — compiler, MPI and launcher all live in the
ccpe container, so both build and run must happen inside it:
```bash
CEXEC=/opt/share/singularity/ccpe/bin/container-exec.sh
$CEXEC bash -c "make DEPS=1 -j16 std gam ncl"
```
Prefer the ready-made sbatch wrappers in **`~/git/vasp/porgy05_cray_conf/`** over
hand-rolling one — `build_cray.slurm`, `test_cray.slurm`, `val_cray.slurm`; its
`README.md` documents the whole set, including which legacy scripts are broken:
```bash
sbatch --export=ALL,VASP_DIR=$PWD build_cray.slurm                      # std+gam+ncl
sbatch --export=ALL,VASP_DIR=$PWD,TARGET=std,CLEAN=1 build_cray.slurm
```
- arch template: `arch/makefile.include.cray_omp_off` — `ftn -hnoacc -homp`,
  `-DOMP_OFFLOAD -DCRAYHIP`, `-O2` (`-O1` is much slower in some GPU kernels).
- CMake: `-DVASP_OMP_OFFLOAD=ON` with `FC=ftn` → `VASP_ROCM_HIP` is set and LibXC
  disabled automatically.
- **`container-exec.sh` forwards every `^VASP_*` var, and apptainer's `--env` rejects a
  value with a comma after a second `=`** — exactly the shape of the vasp-dev toolchain's
  `VASP_FC_GPU_TARGETS` / `VASP_LLIBS_EXTRAS`. Submitting from a shell with a
  `vasp-*-dev` module loaded dies in ~3 s on an apptainer usage dump. Unset the `VASP_*`
  build vars first (`build_cray.slurm` already does; CI is immune, having no vasp module).
- HDF5 is added on top, not baked into the arch file:
  `CPP_OPTIONS += -DVASP_HDF5` plus `cray-hdf5` loaded inside the container.
- MPI runs need the helper's `--pals` (job-local palsd, ranks stay in the slurm cgroup);
  a build launches no MPI and does not.

### Intel Max 1100 OpenMP offload → `guppy07`

```bash
module avail 2>&1 | tr ' ' '\n' | grep vasp-intel-dev | sort -V | tail   # pick the latest
module load vasp-intel-dev/<latest>
```
- arch template: `arch/makefile.include.oneapi_omp_off` — `ifx -fiopenmp`,
  `-fopenmp-targets=spir64_gen -Xs "-device pvc"` (ahead-of-time compiled).
- CMake: `-DVASP_OMP_OFFLOAD=ON` with `FC=ifx` → `VASP_INTEL_MKL=ON`, NCCL off, LibXC
  forced off. Retarget with `-DCMAKE_INTELGPU_DEVICE=` / `-DCMAKE_INTELGPU_ARCHITECTURES=`.
- Build dir: **`build_intel_off`**, kept apart from the CPU `build_intel`.
- **LibXC must be out of the way** — CI does `module unload libxc`; CMake disables it itself.
- The AoT device link is slow and memory-hungry; CI builds with `-j4`.
- Runtime (see `~/git/vasp/intel_gpu.conf`): 2 ranks, one per card, `I_MPI_OFFLOAD=1`,
  `OMP_TARGET_OFFLOAD=DEFAULT`, `I_MPI_PIN_DOMAIN=omp`. Persistent
  `NEO_CACHE_DIR`/`SYCL_CACHE_DIR` (+`*_PERSISTENT=1`) saves the JIT on every later run.
- **ifx 2026.0.0 rejects a hard-coded `IF(TARGET:cond)` clause** (error #6997) — the
  portable spelling is the `GPOMPIF(cond)` macro from `symbol.inc`.

### NVIDIA OpenACC → `guppy06` (2x A100), `porgy04`, or most workstations

```bash
module avail 2>&1 | tr ' ' '\n' | grep vasp-nvhpc_mkl-dev | sort -V | tail
module load vasp-nvhpc_mkl-dev/<latest>      # or plain vasp-nvhpc-dev/<latest>
```
- CMake as in Step 1c. OpenACC is attempted automatically once an nvhpc compiler is
  detected — no flag needed. `VASP_CUDA` and `VASP_OMP_OFFLOAD` are mutually exclusive
  (CMake hard-errors).
- `CMAKE_CUDA_ARCHITECTURES=native` resolves against **the card in the machine you
  configure on** — configure on the target node, or pass the arch explicitly (see the `cc`
  column above). Note `cmake/README.md` documents this knob as `VASP_CUDA_ARCH`; the variable
  the code actually reads is `CMAKE_CUDA_ARCHITECTURES`.
- **Blackwell (`cc120`: `wahoo04`, `wahoo07`) needs nvhpc ≥ 25.3.** `vasp-nvhpc-dev/25.1`
  — which is what `.gitlab-ci.yml` pins for the nvhpc jobs — fails with
  `nvfortran-Error-Switch -gpu with unknown keyword cc120`. Verified: 25.1 rejects it,
  25.3 and 26.3 accept it. Load a newer module than CI's for those two nodes.
- arch templates for the classic build: `nvhpc_acc`,
  `nvhpc_ompi_mkl_omp_acc` (OpenMP host threading + OpenACC).

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

## Step 2 — Classic makefile build (when the user asks for "the old build" / "without cmake", or for unit tests)

**Also required for the `unit-test/` suite** — those tests are driven off the classic `build/<variant>/`
object layout and are not wired into CMake at all, so "run the unit tests" implies this build path
even when CMake would otherwise be preferred. See the **vasp-test** skill for running them.

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
- **Never assume a node's GPU vendor or generation from its name.** `porgy05`=AMD MI210,
  `guppy07`=Intel Max 1100, `guppy06`=NVIDIA A100, `wahoo04`=RTX PRO 6000 Blackwell — and the
  `wahoo*` boxes alone span cc60 to cc120. See Step 0b; check the hardware if it matters.
- **One build dir per accelerator target**, not just per toolchain: `build_intel` (CPU) and
  `build_intel_off` (Intel GPU) come from the same module family but are not interchangeable.
- **GPU builds want a compute node.** `CMAKE_CUDA_ARCHITECTURES=native` and Intel AoT device
  detection both read the local hardware, and the Cray toolchain only exists inside the container
  on `porgy05`. Build where you will run.
- **LibXC is incompatible with every OMP-offload build.** CMake turns it off itself; for the
  classic build make sure the module isn't loaded.
