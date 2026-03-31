# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Installation

Clone with submodules (required for legacy Vim plugins):
```bash
git clone --recurse-submodules https://github.com/the-hampel/dotfiles.git
# or after checkout:
git submodule update --init --recursive
```

Deploy all dotfiles as symlinks into `$HOME`:
```bash
make install
```

The Makefile uses the pattern rule `$(HOME)/.% : %` to create symlinks via `ln -snf`. To add a new file, append it to the `files` list in `Makefile`.

Build Neovim from source (v0.9.1, installs to `~/.local`):
```bash
./build_nvim.sh
```

## Repository Structure

- **Shell**: `profile` (master config with hostname-based machine detection), `bashrc`, `zshrc`
- **Editor**: `vimrc` (legacy Vim), `config/nvim/` (Neovim with NvChad + Lazy.nvim)
- **Tools**: `gitconfig`, `tmux.conf`, `ripgreprc`, `config/kitty/`, `config/ruff/ruff.toml`
- **HPC/Scientific**: `tools/` — build and environment scripts for VASP, TRIQS, and HPC clusters
- **Claude Code**: `claude/settings.json`, `claude/statusline-command.sh`

## Architecture

### Machine-Specific Configuration

`profile` is the central config that detects the hostname and applies machine-specific settings (modules, compiler flags, paths, aliases). Machines include:
- CCQ workstation (Flatiron Institute)
- `thinkXtreme` — Arch Linux, TRIQS development
- `fractal` — Arch Linux, VASP development
- `*.vasp.co` — VASP cluster nodes

### Neovim Setup

`config/nvim/` uses NvChad v2.5 as the base framework. Key files:
- `init.lua` — entry point, loads NvChad + custom modules
- `lua/plugins/init.lua` — plugin declarations (Lazy.nvim)
- `lua/configs/lspconfig.lua` — LSP configuration
- `lua/configs/conform.lua` — formatter configuration
- `lua/mappings.lua`, `lua/options.lua`, `lua/autocmds.lua` — customizations
- `after/syntax/fortran.vim` — custom Fortran syntax detection

### HPC/VASP Build Scripts (`tools/`)

| Script | Purpose |
|--------|---------|
| `env_vasp.sh` | Set up compiler environment (gnu, nvidia, intel24, intel25, nec, aocc) |
| `make_vasp_cmake.sh` | CMake-based VASP build; reads compiler mode and supports CUDA/profiling |
| `make_vasp.sh` | Legacy Makefile-based VASP build (std, gam, ncl targets) |
| `make_dev.sh` | CMake build for TRIQS electronic structure suite |
| `ccpe_container_env.sh` | Singularity/Apptainer container environment for HPC |
| `run_vasp_gdb.sh` | VASP GDB debug launcher |

### Python/Scientific Environment

- `config/ruff/ruff.toml` — line length 140, single quotes, E501 ignored
- `jupyter/jupyter_server_config.py` — JupyterLab on port 8378
- `pyvenv_activate.sh` — activates the `devpy` Python venv
