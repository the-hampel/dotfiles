---
name: vasp-run
description: |
  Run VASP on the VASP-dev ("deep blue") slurm cluster or on a local workstation: decide
  where the job belongs (CPU vs GPU, which node has which accelerator), write the slurm
  script, submit it with srun, and check that the run actually ran instead of silently
  failing. CPU runs go to wahoo06 by default; GPU runs to guppy06 (2x A100), guppy07
  (2x Intel Max 1100), porgy05 (4x AMD MI210, Cray container) or a wahoo workstation
  (NVIDIA, some outside slurm). Also covers the one REMOTE site, AAC7 (AMD Accelerator
  Cloud, `ssh aac`): MI300A APUs, Cray CCE + ROCm, its own slurm and its own filesystem.
  Carries ready-to-copy job scripts in examples/.
  Use when: running VASP, "submit a VASP job", sbatch/srun for VASP, launching on A100 /
  Intel Max / MI210 / MI300A / AAC / RTX, choosing rank and thread counts, benchmarking a
  VASP run, re-running a case, or diagnosing a job that produced no OUTCAR. For BUILDING
  see the vasp-build skill; for the regression testsuite see vasp-test.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# Running VASP

Companion to **vasp-build** (which compiles and carries the node/accelerator map) and
**vasp-test** (which drives the regression testsuite). This skill is about getting a real
calculation onto the right machine and knowing whether it worked.

**The launch rule for this cluster: plain `srun`.** Slurm's pmix plugin was repaired on
2026-07-31 and `SLURM_MPI_TYPE=pmix` is set site-wide, so

```bash
srun -n $SLURM_NTASKS --cpu-bind=cores $BIN/vasp_std
```

needs **no `--mpi=`, no `--map-by`, no `-c`**, and slurm does the binding. Verified against
hand-mapped `mpirun` on a 2-GPU job: 34.83 s vs 34.86 s, identical masks. Two places differ:
porgy05, where the Cray container brings its own launcher (§5.4), and the remote AAC7 site,
where `srun` is still right but wraps the binary in a NUMA/GPU binding script (§5.6).

---

## Step 0 — Where am I?

Answer this first; it decides everything else.

```bash
hostname                                  # <node>.vasp.co on the cluster
sinfo -a -o "%14N %12P %6c %20G %10T" | head -30   # does slurm answer? which nodes exist?
squeue -u $USER                           # anything of mine already running?
echo "${SLURM_JOB_ID:-no}"                # am I ALREADY inside a job step?
nvidia-smi -L 2>/dev/null || rocm-smi --showproductname 2>/dev/null \
  || xpu-smi discovery 2>/dev/null || echo "no GPU on this host"
```

| what you see | where you are | how to run |
|---|---|---|
| `sinfo` answers, `SLURM_JOB_ID` unset | a cluster login/head node | **write an sbatch script and submit it** (§5) |
| `sinfo` answers, `SLURM_JOB_ID` set | inside an allocation | run `srun` directly, do not nest sbatch |
| `sinfo` fails / not found | a workstation outside slurm, or a laptop | run locally (§5.5), pin by hand |
| hostname is `wahoo04` | Blackwell workstation, **not in slurm** — plain `ssh`, no queue | §5.5 |
| hostname is `uan1`, partitions named `192C4G1H_MI300A_*` | **AAC7**, a remote site — separate filesystem, separate slurm | §5.6 |

**One machine in this skill is not on the cluster at all.** AAC7 (MI300A) is reached with
`ssh aac` and shares **no filesystem** with deep blue — inputs, source and results all travel
by `rsync`. If the task names MI300A, "aac", or an AMD APU, go to §5.6 first; nothing in
Steps 2-4 about local partitions applies there.

**Two slurm controllers coexist on this cluster.** `guppy06`, `guppy07`, `wahoo01/02/06` are on
`slurm/25-05-1-1`; some `porgy*` nodes still answer the old `slurm/23.02.3`. A node reported
`down~ "migrated to new slurm"` and a job stuck in PENDING with *"Nodes required for job are DOWN,
DRAINED or reserved"* means the **wrong client**, not a busy queue. Load the matching client
**after** the vasp toolchain module — the toolchain silently reloads slurm 23.02.3:

```bash
module load vasp-nvhpc_mkl-dev/26.3_mkl-2026.0.0_ompi-5.0.9
module load slurm/25-05-1-1
```

---

## Step 1 — What are you running?

1. **Which binary?** `vasp_std` (k-points, complex) · `vasp_gam` (Γ-only, real, ~1.8-2x faster
   than std on the same Γ cell) · `vasp_ncl` (noncollinear / SOC). Read the case: a `KPOINTS`
   with one Γ point → `vasp_gam`; `LSORBIT`/`LNONCOLLINEAR` → `vasp_ncl`.
2. **Which build?** `ls <tree>/build_*/bin/` — build dirs are per-toolchain and often symlinks to
   node-local disk, so a build dir may exist on one node only (`build_rtx6000` resolves on wahoo04
   and nowhere else). No suitable build → vasp-build skill first.
3. **How many ranks?**
   - **GPU: exactly one rank per GPU.** Never oversubscribe a card, never leave one idle.
   - **CPU: 4 / 8 / 16.** The testsuite references were made at 4. **Avoid non-power-of-two rank
     counts and odd mappings** — they change reduction order and can push results past reference
     tolerances (false failures).
4. **Threads: do not set them in a slurm job.** A site TaskProlog hook fills
   `OMP_NUM_THREADS` and `MKL_NUM_THREADS` from `--cpus-per-task` — *but only if they are unset*,
   because a value the submitter set always wins, and sbatch propagates whatever the submitting
   shell has. Keep **`unset OMP_NUM_THREADS MKL_NUM_THREADS`** in the batch step and let the hook
   decide. Measured on wahoo06 with `--cpus-per-task=8`: with `MKL_NUM_THREADS=1` inherited from
   the submitting shell the task gets `OMP=8 MKL=1` — MKL single-threaded while OpenMP is not,
   which is easy to miss — and unset, `OMP=8 MKL=8`. Off slurm there is no hook, so set both by
   hand. With no `--cpus-per-task` the hook falls back to **1**, which is right for a pure-MPI run.
   **The hook is a deep-blue thing.** On AAC7 there is none, so unset means 1 there and you must
   set `OMP_NUM_THREADS` yourself (§5.6). Either way, VASP's `running N mpi-ranks, with M
   threads/rank` banner is the only ground truth.

---

## Step 2 — Pick the machine

| you want | node | partition | GPUs | ranks x threads to ask for |
|---|---|---|---|---|
| **CPU run** (default) | **wahoo06** | `-p wahoo06` | (has 1 RTX 4060 Ti, ignore it) | 32 cores: `--ntasks=4 --cpus-per-task=8` |
| bigger CPU run | porgy01/02/03 (128c), guppy05 (24c) | `-p porgy02` etc. | none | up to `--ntasks=16 --cpus-per-task=8` |
| **NVIDIA datacenter** — the reference machine | **guppy06** | `-p guppy06` | 2x A100-SXM4-80GB (cc80) | `--ntasks=2 --cpus-per-task=8 --gres=gpu:2` |
| **Intel GPU** | **guppy07** | `-p guppy07` | 2x Max 1100 (PVC) | `--ntasks=2 --cpus-per-task=32 --gres=gpu:2` |
| **AMD GPU** | **porgy05** | `-p porgy05` | 4x MI210 (`gfx90a`) | `--ntasks=4 --cpus-per-task=6 --gres=gpu:4` |
| **AMD APU, remote** | **AAC7** (`ssh aac` → `uan1`) | `-p 192C4G1H_MI300A_RHEL9_A1` | 4x MI300A (`gfx942`) per node, ~13 nodes | `--ntasks-per-node=4 --cpus-per-task=24 --gres=gpu:4` |
| NVIDIA consumer / Blackwell | wahoo04 (RTX PRO 6000, cc120, **no slurm**), wahoo07 (RTX 5060 Ti), wahoo03 (4090), wahoo05/06 (4060 Ti), wahoo01/02 (GP100, cc60) | ssh or `-p wahooNN` | 1 each | 1 rank, 8 threads |
| 2x A30 | porgy04 | `-p porgy04` | 2x A30 | `--ntasks=2 --cpus-per-task=8 --gres=gpu:2` |

Rules of thumb:

- **CPU work → wahoo06** unless the user says otherwise (it is Alex's machine and usually free).
- **GPU numbers that go in the notes → guppy06.** It is the reference; A100 is native FP64.
- A **consumer** card (4060 Ti, 4090, 5060 Ti) has FP64 at ~1/64, so absolute GPU numbers from it
  are not comparable with A100/H100 — say which card any timing came from.
- `sinfo` state `idle~` means the node is **suspended**: the first job wakes it, which costs
  ~2 min before anything starts (guppy07 does this routinely). `allocated`/`mixed` means someone
  else is on it — for a *timing* run either wait or use `--exclusive`; for a correctness run share it.
- **`--cpus-per-task` counts LOGICAL cpus on the hyper-threaded nodes** — wahoo\*, tuna\*, epyc and
  guppy06 have `ThreadsPerCore=2`, so `-c 8` binds a task to 4 physical cores plus their siblings
  (measured on wahoo06: `-c 4` → cpus `0-1,32-33`). Add **`--threads-per-core=1`** (or
  `--hint=nomultithread`) when the run is a timing and you want whole cores. porgy01-05, manta21/22
  and guppy07 are `ThreadsPerCore=1`, where the count is already physical. Threads stay inside the
  allocation either way, so this is a performance question, not a correctness one.

---

## Step 3 — Write the job script

Start from `examples/` in this skill directory and change the paths:

| file | for |
|---|---|
| `examples/cpu_wahoo06.slurm` | CPU run, any toolchain, 4x8 on wahoo06 |
| `examples/gpu_a100_guppy06.slurm` | A100, 1 or 2 GPUs, existing build |
| `examples/gpu_a100_guppy06_injob_build.slurm` | A100 **build + run in one job** — required for a tree not yet built there (glibc) |
| `examples/gpu_a100_guppy06_sweep.slurm` | A100, several settings interleaved, for benchmarking |
| `examples/gpu_intel_guppy07.slurm` | Intel Max 1100, 1 or 2 cards, via `srun_ze.sh` |
| `examples/gpu_intel_guppy07_testsuite.slurm` | Intel Max 1100, regression testsuite |
| `examples/gpu_amd_porgy05.slurm` | AMD MI210 inside the Cray ccpe container |
| `examples/gpu_amd_mi300a_aac7.slurm` | AMD MI300A on the remote AAC7 site (§5.6) |
| `examples/workstation_local.sh` | no slurm (wahoo04 and friends): ssh + taskset |

**What has been exercised, so you know how much to trust each one:** `cpu_wahoo06.slurm` was run
end to end on 2026-08-31 (4 ranks x 8 threads, `rc=0`, correct rank banner).
`gpu_amd_mi300a_aac7.slurm` is a cleaned-up copy of the driver that produced the 2026-08-31 PdO4
MI300A results (18 converged runs at 1/2/4 ranks, std and gam), so its environment block is
measured, not guessed, and the file itself was then run end to end on AAC7 the same day
(`rc=0`, `running 4 mpi-ranks, with 8 threads/rank`, `4 GPUs detected`). The A100, Intel and
MI210 scripts are transcribed from the drivers that produced the recorded results on those
machines
(`~/scratch/gpu_test/chefsi_validation/guppy06_a100_*.sbatch`, `~/git/vasp/intel_gpu.conf` +
`srun_ze.sh`, `~/git/vasp/porgy05_cray_conf/*.slurm`) rather than re-run here; all default paths in
them were checked to exist. Re-check `sinfo` and the build dir before trusting any of them blindly.

Every one of them follows the same five rules, and each rule exists because it broke something:

```bash
#SBATCH -p <node> --nodes=1 --ntasks=<ranks> --cpus-per-task=<threads> [--gres=gpu:<n>]
module purge                       # NOT --export=NONE (see traps)
module unload vasp-intel-dev 2>/dev/null   # it CONFLICTS with the nvhpc toolchain
module load <toolchain>
command -v mpirun >/dev/null || { echo "ABORT: toolchain did not load"; exit 1; }
unset OMP_NUM_THREADS MKL_NUM_THREADS   # let the TaskProlog hook fill both from --cpus-per-task
cd "$WORKDIR"
srun -n "$SLURM_NTASKS" --cpu-bind=cores "$BIN/vasp_std" > stdout.log 2>&1
```

Submit, then watch:

```bash
sbatch job.slurm            # note the job id
squeue -u $USER             # ... or: squeue -j <id> -o "%.10i %.9P %.8T %.10M %R"
tail -f slurm-<id>.out
scancel <id>                # stop it
```

---

## Step 4 — Did it actually run?

VASP has several ways to fail while looking like it worked. Check all four:

```bash
grep -m1 "running .* mpi-ranks" OUTCAR    # ASSERT the rank count you asked for
grep -m1 "Offloading initialized" OUTCAR  # GPU build: "... N GPUs detected" = N ranks saw N cards
grep "LOOP+" OUTCAR | tail -2             # the run reached the end of an ionic step
tail -3 OUTCAR                            # "General timing and accounting" = clean finish
```

- **No OUTCAR at all, no error** → the binary died before its banner. On guppy06 that is almost
  always the **glibc** rule (§5.2): a binary linked on a login node cannot start there.
- **`running 1 mpi-ranks` when you asked for 4** → the launcher ran N independent 1-rank jobs into
  the same directory (the old `--mpi=pmi2` failure mode). Every result is garbage; fix the launch.
- **`1 GPUs detected` on a 2-GPU job** → one rank is doing all the work, or both ranks share a card.
- Timings only: **`LOOP+` real time** is the wall clock. The flat profile at the end of the OUTCAR
  (`-DVASP_PROFILING` builds) gives per-routine exclusive time, but its **CPU times are unreliable
  under async GPU offload** — use `LOOP+`, and set `CUDA_LAUNCH_BLOCKING=1
  NVCOMPILER_ACC_SYNCHRONOUS=1` only when you need attribution (it makes the run slower).

---

## Step 5 — Per-machine notes

### 5.1 CPU on wahoo06 (the default)

32 cores. `--ntasks=4 --cpus-per-task=8` fills it. Any CPU toolchain
(`vasp-intel-dev`, `vasp-gnu_mkl-dev`) — load the one the build was made with. Nothing special
otherwise; this is the boring, reliable path. Example: `examples/cpu_wahoo06.slurm`.

### 5.2 A100 on guppy06

- **Build in the job, or run a binary built there.** guppy06's glibc is **2.28**, older than the
  login nodes: a binary linked on wahoo starts and dies before printing its banner — no OUTCAR, no
  error, just OMPI warnings. Use `examples/gpu_a100_guppy06_injob_build.slurm` for a fresh tree, and
  reuse that build dir afterwards via a `.ref_<sha>` marker.
- One rank per card, `--gres=gpu:2 --ntasks=2`. `srun -n 2 --cpu-bind=cores` gives 8 cores per rank,
  one per socket.
- `nproc` reports **1** inside the batch step even with `--exclusive`; size any `-j` from
  `taskset -pc $$`, not from `nproc`.
- KPAR=2 for a case with ≥2 k-points, otherwise band parallelism (NPAR) — set it in the INCAR, not
  on the command line.

### 5.3 Intel Max 1100 on guppy07

- The node **auto-suspends** (`idle~`); the first job wakes it, ~2 min before anything runs.
- **No `--exclusive`**, and `--cpus-per-task=32` is the convention there (112 cores, 2 cards).
- Launch is `srun` **plus a one-line wrapper**, `~/git/vasp/srun_ze.sh`:

  ```bash
  srun -n 2 ~/git/vasp/srun_ze.sh $BIN/vasp_std
  ```

  Reason: Intel MPI ≤ 2021.17 runs its topology detection in the launcher; under `srun` that fails
  and, with `I_MPI_OFFLOAD=1`, the library then walks the uninitialised topology and **SIGSEGVs
  before any user code**. Merely *defining* `I_MPI_PIN_MAPPING` (what the wrapper does) skips that
  path; slurm still does the binding. oneAPI 2026 / Intel MPI 2021.18 guards against it.
- Per-rank GPU binding is **not** needed: `INIT_OFFLOAD` in `src/openmp.F` does its own round-robin
  (`MOD(rank, OMP_GET_NUM_DEVICES())`).
- Set the persistent JIT caches or every run re-JITs the device code:
  `NEO_CACHE_DIR`/`SYCL_CACHE_DIR` + `NEO_CACHE_PERSISTENT=1`/`SYCL_CACHE_PERSISTENT=1`,
  plus `I_MPI_OFFLOAD=1 OMP_TARGET_OFFLOAD=DEFAULT OMP_STACKSIZE=2048m`.
  `~/git/vasp/intel_gpu.conf` is the maintained copy of that environment.

### 5.4 AMD MI210 on porgy05 — the one place `srun` is NOT used

Compiler, MPI and launcher all live in the **ccpe container**, so the run happens inside it. The
job's batch step calls the CI helper directly (no `srun`), and the launcher inside is cray-pals
`mpiexec`:

```bash
CEXEC=/opt/share/singularity/ccpe/bin/container-exec.sh
"$CEXEC" --gpu --pals <script-or-command>          # inside: mpiexec -np 4 -ppn 4 --hosts localhost \
                                                  #         /opt/scripts/vasp-rank-wrapper.sh $BIN/vasp_std
```

- `--pals` starts a **job-local** palsd, so the ranks stay in the slurm cgroup and
  `/opt/scripts/vasp-rank-wrapper.sh` pins them across `CCPE_CPU_LIST`/`CCPE_GPU_LIST` — what slurm
  actually allocated. **No `--exclusive` needed, safe to share the node.**
- **Unset the toolchain's `VASP_*` build variables before submitting.** `container-exec.sh` forwards
  every `^VASP_*`, and apptainer's `--env` rejects a value with a comma after a second `=` — exactly
  the shape of `VASP_FC_GPU_TARGETS` / `VASP_LLIBS_EXTRAS`. Submitting from a shell with a
  `vasp-*-dev` module loaded dies in ~3 s on an apptainer usage dump. Keep `VASP_TESTSUITE_*`,
  `VASP_GPU_*` and `VASP_DIR`; unset the rest.
- Prefer the maintained scripts in `~/git/vasp/porgy05_cray_conf/` (`test_cray.slurm`,
  `val_cray.slurm` + `run_val_cray.sh`, `build_cray.slurm`) over hand-rolling; its `README.md`
  documents the set and which older scripts are broken.
- `CRAY_ACC_DEBUG_FILE` is opened in **append** mode — delete `acc.debug` before a run or you debug
  the previous one.

### 5.5 Workstations outside slurm (wahoo04 and friends)

`wahoo04` (RTX PRO 6000 Blackwell, 64 cores, 96 GB) is not in slurm: `ssh wahoo04`, load modules,
run. Two things to get right:

```bash
ssh wahoo04
module load vasp-nvhpc_mkl-dev/26.3_mkl-2026.0.0_ompi-5.0.9 cuda-overlay/13.1_nvhpc-26.3
export OMP_NUM_THREADS=8 MKL_NUM_THREADS=8
taskset -c 0-7 mpirun -np 1 --bind-to none $BIN/vasp_std > stdout.log 2>&1
```

- **Pin by hand.** `mpirun -np 1` with no mapping binds rank 0 to core 0 — *every* such job — so two
  concurrent single-rank runs timeshare one core at ~50 % each while 63 idle. Give each its own
  `taskset -c` range. Rescue a running one with `taskset -a -pc 0-7 <pid>` (the `-a` matters).
- The **cuda-overlay** module is needed for anything built for `cc120` on that box.
- Before a timing run, check the card is idle: `nvidia-smi --query-gpu=memory.used,utilization.gpu
  --format=csv,noheader`.

### 5.6 AMD MI300A on AAC7 — the remote site

**AAC7 = AMD Accelerator Cloud.** It is not part of deep blue: different slurm, different
modules, different home directory, **no shared filesystem**. Everything you want there you put
there, and everything you want back you fetch back.

```bash
ssh aac                     # ~/.ssh/config: Host aac -> aac7.amd.com, User ahampel
                            # lands on the login node uan1 (128 cores, RHEL 9)
```

Home is `/shared/midgard/home/ahampel` (NFS, 11 T). There is also `/shareddata`.

**Hardware.** ~13 compute nodes, each **4x MI300A** (`gfx942`, APU: CPU and GPU share HBM),
4 NUMA domains, 96 physical cores / 192 logical, ~500 GB. GPU *i* is NUMA-local to domain *i*.
Partitions: `192C4G1H_MI300A_RHEL9_A1` (**the default**), `..._RHEL9`, `..._RHEL9_A0` (mostly
drained). Time limit 5 days. Node names look like `x9000c1s2b0n0`. Check with plain
`sinfo` / `squeue -u $USER` — the slurm client is in `/usr/bin`, no module needed.

**Toolchain: Cray CCE, sourced from a script, not a module line you type.**

```bash
source ~/git/vasp/cce21_scripts/env_cce21.sh
```

It loads `PrgEnv-cray/8.7.0`, `craype-x86-genoa`, `craype-accel-amd-gfx942`, `cray-fftw`,
`cray-hdf5`, `rocm-new/7.2.1`, and adds `$ROCM_PATH/lib` to `LIBRARY_PATH` — that last part is
load-bearing: cray-mpich injects `-lamdhip64` into every `ftn` link line but ships no matching
`-L`, and compute nodes (unlike the login node) do not resolve it from the ld cache.

> **`module` does not exist in a non-login shell there.** `ssh aac 'module load ...'` fails with
> *"module: command not found"*. Use `ssh aac 'bash -lc "..."'` for one-offs, and start every
> sbatch script with **`#!/bin/bash -l`**. This is the first thing that bites.

**Build** — classic `makefile.include` build (not cmake), on the **login node**, ~15 min for
`std`+`gam` at `-j32`. CCE 21 additionally needs a source rewrite; see the vasp-build skill and
`~/git/vasp/cce21_scripts/{build.sh,fix_if_clause.py,scan_if_clause.py}`.

**Run.** Use `examples/gpu_amd_mi300a_aac7.slurm`. One rank per die, `--ntasks-per-node=4
--cpus-per-task=24 --gres=gpu:4`, and the launcher is plain `srun` plus a binding wrapper:

```bash
srun -N $NODES -n $RANKS --ntasks-per-node=4 --gpus-per-node=4 \
     ~/git/vasp/cce21_scripts/bind_gpu_mn.sh $BIN/vasp_std > stdout.txt 2>&1
```

Always the `_mn` wrapper: it keys off `SLURM_LOCALID`, so it is correct on one node *and* more.
The plain `bind_gpu.sh` keys off the global rank and is single-node only. Both print
`GRANK=.. RANK=.. GPU=.. NUMA=.. CPU=..` per rank — read it, it is your binding check.

Site-specific things the example script sets, each for a reason:

- **`OMP_NUM_THREADS=8` by hand.** There is no TaskProlog hook here, so the Step-1 "let the hook
  decide" rule does *not* apply — unset means 1.
- **`unset NCCL_LAUNCH_ORDER_IMPLICIT`.** `=1` makes multi-rank RCCL segfault on this machine.
- **`assign -y on g:all` with `FILENV`** — Cray Fortran buffers hard; without it OUTCAR and
  OSZICAR lag minutes behind the run and a progress check tells you nothing.
- **`ROCFFT_RTC_CACHE_PATH` per run, `ROCFFT_RTC_SYS_CACHE_PATH=/dev/null`.**
- `HSA_XNACK=0`, `GPU_MAX_HW_QUEUES=8`, `MPICH_GPU_SUPPORT_ENABLED=1`, `ulimit -s unlimited`.

**Multi-node is a correctness check, not a benchmark.** RCCL has no OFI/Slingshot plugin in
ROCm 7.2.1, so inter-node collectives fall back to sockets (~7x slower unless you set
`LUSENCCL=.FALSE.`), cray-mpich GPU IPC can fail with
`hsa_amd_ipc_memory_attach: HSA_STATUS_ERROR_INVALID_ARGUMENT` (raise `MPICH_GPU_IPC_THRESHOLD`),
and 8 ranks over 2 nodes has still died with a GPU memory access fault. Energies reproduce
across nodes; timings from >1 node do not belong in the notes.

**Moving work in and out.** Source trees go over as `rsync` of `src/` — exclude the gitignored
`CMakeLists.txt` symlinks, which are broken on the far side. `git fetch` does work there
(`origin` on that tree is github-edge, not gitlab), but a branch that has been force-pushed or
not pushed at all is faster and safer to rsync. Results come back the same way:

```bash
rsync -az --exclude 'CMakeLists.txt' --exclude '*.preif' \
      ~/git/vasp/<tree>/src/  aac:/shared/midgard/home/ahampel/git/vasp/<tree>/src/
rsync -az aac:/shared/midgard/home/ahampel/benchmark/<case>/  ~/scratch/.../
```

Keep a `PROVENANCE.txt` next to the far-side tree naming the local `git rev-parse HEAD` and
whether the working tree was dirty — an rsynced tree has no branch identity of its own, and
`git status` over there will be misleading.

---

## Traps

Each of these has cost someone hours.

1. **An inherited `OMP_NUM_THREADS`/`MKL_NUM_THREADS` silently beats the TaskProlog hook.** The
   hook supplies both from `--cpus-per-task` *only when they are unset*, and sbatch propagates the
   submitting shell's environment. The login profile stopped exporting them on 2026-08-31, but a
   shell, tmux window or agent started before that still carries the old values — so keep the
   `unset` in the batch step (measured on wahoo06: inherited `MKL_NUM_THREADS=1` gives the task
   `OMP=8 MKL=1`; unset gives `OMP=8 MKL=8`). Off slurm, set both by hand. Ground truth is always
   VASP's own `running N mpi-ranks, with M threads/rank` banner; `nproc` reporting 1 on a big node
   is the tell that something pinned `OMP_NUM_THREADS` (it honours the variable).
2. **`module purge` at the top of an sbatch, never `--export=NONE`.** sbatch inherits the submitting
   shell's modules, so a stale `vasp-intel-dev` blocks the nvhpc toolchain; but `--export=NONE`
   cascades to the `srun` step, whose task then has no module environment at all and OMPI aborts in
   `MPI_Init` before VASP's banner.
3. **A conflicting `vasp-*-dev` module makes `module load` a silent no-op** — it exits 0 and neither
   `nvfortran` nor `mpirun` reaches PATH. `module purge` does not clear it; `module unload
   vasp-intel-dev` does. **Assert on the tool** (`command -v mpirun`), never on `$?`.
4. **Do not rebuild while a run uses the binary** — `ETXTBSY`, or worse, a half-written binary.
   Copy the binary aside for long runs (`cp $BLD/bin/vasp_std /tmp/vasp_std.run`).
5. **VASP honours the FIRST occurrence of an INCAR key.** A script that appends overrides does
   nothing if the base file already sets that key; and a line-anchored `sed` delete misses
   `ISMEAR = 1 ; SIGMA = 0.1`. sed-REPLACE anywhere including after `;`, then **assert the resolved
   value in the OUTCAR** (`grep "ISTART =" OUTCAR`).
6. **A/B timings must be INTERLEAVED, not blocked.** Run `A B A B`, not `AAA BBB`, and average the
   paired differences; on a shared node the blocked form has *inverted* a result (2.2 % slower vs
   13.8 % faster, same binaries, same node). The tell is both arms coming out bimodal.
   `examples/gpu_a100_guppy06_sweep.slurm` does it correctly.
7. **`--ntasks=1 --cpus-per-task=16` gives PRRTE one slot**, so an inner `mpirun -np 2` dies with
   "not enough slots" — slots are per TASK, not per CPU. Ask for the tasks you intend to launch.
8. **Single-rank GPU runs are not bit-reproducible run to run** on every case (the SCF tail's last
   digits move, and `ALGO=Normal` does it too). Judge an A/B by "bit-identical where the case is
   deterministic, plus identical step count and final energy elsewhere", and establish a case's own
   run-to-run baseline before reading a last-digit difference as a code change.
9. **Check the queue with the right slurm client** before concluding a partition is busy (Step 0).
10. **On AAC7, `module` does not exist outside a login shell.** `ssh aac 'module load ...'` fails
    with *"command not found"*; sbatch scripts need `#!/bin/bash -l`. Use
    `ssh aac 'bash -lc "..."'` for one-offs. Related: `srun` from the AAC7 **login node** (outside
    an allocation) fails in `MPIR_pmi_init` and looks like a hang — always submit.
11. **One anomalous timing is a measurement, not a result — check the GPU before the solver.** A
    4-GPU MI300A run once came out 3x slow with no error; its flat profile was 2-7x slower per call
    in *every* GPU region, `init_offload` (which does no science) included — contention or a sick
    card, not code. A repeat on the same node was normal. Compare the per-call cost of a
    science-free region first, and never publish a single unrepeated timing.
10. **Licensed inputs**: `POTCAR` files are license-restricted. Do not copy them out of the cluster
    or into a world-readable location without asking.
