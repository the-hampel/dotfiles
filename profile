# output full docker build output
export BUILDKIT_PROGRESS=plain

if [ "$HOSTNAME" = thinkxtreme ]; then
    printf '%s\n' "thinkXtreme@Ubuntu detected"
    export NCORE=16
    export CC=clang
    export CXX=clang++
    # python venv
    alias triqs-dev='source $HOME/triqs-dev/bin/activate'
    alias triqs-rel='source $HOME/triqs-rel/bin/activate'
    # default venv
    source $HOME/triqs-dev/bin/activate
    # default editor
    export EDITOR="nvim"
    alias vi=nvim
    alias vim=nvim
    alias sys-update='sudo pacman -Syu --verbose'

    # git autocompletion
    source /usr/share/bash-completion/completions/git

    # compiler library config
    export BLA_VENDOR=OpenBLAS
    export OMP_NUM_THREADS=1
    export MKL_INTERFACE_LAYER=GNU,LP64
    export MKL_THREADING_LAYER=SEQUENTIAL
    export MKL_NUM_THREADS=1
    export CXXFLAGS="-stdlib=libc++ -Wno-register -march=native"
    export CFLAGS='-march=native -Wno-error=incompatible-function-pointer-type'

    # old docker command
    alias triqs='docker run -it --shm-size=4g -e USER_ID=`id -u` -e GROUP_ID=`id -g` -p 8378:8378 -v $PWD:/work -v /home/ahampel:/home/ahampel solid_dmft_ompi bash'

    source "$HOME/.config/gruvbox_256palette.sh"
    set use_color true

    # zoxide smarter cd command. Install via: curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
    eval "$(zoxide init --cmd cd bash)"
    # fzf fuzzy command line search
    source /usr/share/bash-completion/completions/fzf && source /usr/share/doc/fzf/examples/key-bindings.bash

elif [ "$HOST" = fractal ]; then
    printf '%s\n' "fractal detected"
    export NCORE=24
    export CC=gcc
    export CXX=g++
    source "$HOME/.config/gruvbox_256palette.sh"

    alias sys-update='pamac upgrade --aur'

    # default editor
    export EDITOR="nvim"
    alias vimdiff='nvim -d'
    alias vi=nvim

    # compiler library config
    export MKLROOT=/opt/intel/oneapi/mkl/latest
    export BLA_VENDOR=Intel10_64lp_seq
    export OMP_NUM_THREADS=1
    export MKL_INTERFACE_LAYER=GNU,LP64
    export MKL_THREADING_LAYER=SEQUENTIAL
    export MKL_NUM_THREADS=1
    export FFLAGS="-march=native"
    export CXXFLAGS="-march=native"
    export CFLAGS='-march=native'
    export ROCR_VISIBLE_DEVICES=

    # sshfs
    alias mount-vasp-home='sshfs hampel@fsc.vasp.co:/fsc/home/hampel /home/hampel/vasp_home'
    alias mount-vasp-scratch='sshfs hampel@fsc.vasp.co:/scratch/hampel /home/hampel/vasp_scratch'
    alias umount-vasp='fusermount -u /home/hampel/vasp_home &> /dev/null && fusermount -u /home/hampel/vasp_scratch &> /dev/null'

    alias devpy='source $HOME/pyvenv/devpy/bin/activate'


elif [[ "$HOSTNAME" == *.vasp.co && "$HOSTNAME" != *porgy02 ]]; then
    printf '%s\n' "vasp detected"

    export PATH="/opt/share/modulefiles/bin:/fsc/home/hampel/.local/bin:/fsc/home/hampel/.local/go/bin:/fsc/home/hampel/go/bin:/wahoo06.local/hampel_temp/ollama/bin:$PATH"

    module load htop

    # ollama models
    export OLLAMA_MODELS=/wahoo06.local/hampel_temp/ollama/models
    export OLLAMA_KEEP_ALIVE=360m
    alias ollama="/wahoo06.local/hampel_temp/ollama/bin/ollama"
    alias ollama-porgy="OLLAMA_MODELS=/home/hampel/ollama/models /home/hampel/ollama/bin/ollama"
    alias llm="micromamba activate llm"
    alias lamaserve="ollama serve &"
    alias lamaweb="open-webui serve &"
    
    export JUPYTERLAB_DIR=/mnt/home/ahampel/.jupyter/lab

    # slurm
    alias qs='squeue --sort "P,U" -o "%.10i %.10u %40j %.12M %.2t %.6D %.6C %30R"'
    alias si='Sinfo'
    alias getnode='srun --nodes=1 --time 360 --partition=guppy01,guppy02,guppy05,guppy06,guppy07 --ntasks-per-node=1 --cpus-per-task=16 --cpu-bind=cores --pty bash -i'
    alias getroc='srun --nodes=1 --time 24:00:00 --partition=porgy05 --ntasks-per-node=8 --cpus-per-task=4 --cpu-bind=cores --gres=gpu:2 --pty bash -i'
    alias getintel='srun --nodes=1 --time 12:00:00 --partition=guppy07 --ntasks-per-node=8 --cpus-per-task=4 --cpu-bind=cores --pty bash -i'
  
    # apptainer
    if [ "$HOSTNAME" = *porgy05 ]; then
        export APPTAINER_CACHEDIR=/home/hampel/apptainer_cache
    else
      export APPTAINER_CACHEDIR=/wahoo06.local/hampel_temp/apptainer/cache
    fi
    export PATH=/wahoo06.local/hampel_temp/apptainer/bin:$PATH
    source $HOME/git/dotfiles/tools/ccpe_container_env.sh
    
    # perf stuff
    ulimit -s unlimited
    export OMP_NUM_THREADS=1
    export OMP_STACKSIZE=2048m
    export NCORE=32
    export HDF5_USE_FILE_LOCKING=FALSE

    # default editor
    export EDITOR="nvim"

    function vi() {
        local SOCKET=$(mktemp -u /tmp/nvim-server-hampel.XXXXXX.pipe)
        # Define cleanup function
        cleanup() {
          [ -e "$SOCKET" ] && rm -f "$SOCKET"
        }
        trap cleanup EXIT
        nvim --listen "$SOCKET" "$@"
        }

    alias vimdiff='nvim -d'

    alias vtune='/fsc/home/hampel/intel/oneapi/vtune/latest/bin64/vtune-backend --allow-remote-access --web-port 7602 --data-directory'
  
    # conda
    alias dev-triqs='micromamba activate triqs-dev'
    alias dev-vasp='micromamba activate vasp-dev'

    # intel stuff
    export MKL_NUM_THREADS=1
    alias ifxgpu='ifx -fiopenmp -fopenmp-targets=spir64 -g'

    # cray stuff
    alias ftnroc='ftn -fopenmp -homp -hnoacc'

    # gfortran command to compile for gpu
    alias gfortran-gpu='gfortran-15 -fopenmp -foffload=amdgcn-amdhsa -foffload-options=amdgcn-amdhsa=-march=gfx90a'

    # Run zsh
    if [[ -z "$ZSH_VERSION" ]]; then
        PS1='\[\e[38;5;214m\]\u@\h \[\e[38;5;166m\][\[\e[38;5;142m\]\w\[\e[38;5;166m\]]\[\e[0m\] \[\e[38;5;246m\]$(date +%H:%M:%S)\[\e[0m\]\n\[\e[38;5;166m\]╰─\[\e[38;5;214m\]❯\[\e[0m\] '
        # >>> mamba initialize >>>
       # !! Contents within this block are managed by 'mamba init' !!
       export MAMBA_EXE='/fsc/home/hampel/.local/bin/micromamba';
       export MAMBA_ROOT_PREFIX='/fsc/home/hampel/micromamba';
       __mamba_setup="$("$MAMBA_EXE" shell hook --shell bash --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
       if [ $? -eq 0 ]; then
           eval "$__mamba_setup"
       else
           alias micromamba="$MAMBA_EXE"  # Fallback on help from mamba activate
       fi
       unset __mamba_setup
       # <<< mamba initialize <<<
        # export SHELL="/usr/bin/zsh"
        # exec /usr/bin/zsh
    fi

    if [[ "$HOSTNAME" == *guppy07* ]]; then
      export SHELL=/bin/bash
    fi

    if [[ "$HOSTNAME" == *spark-18fb* ]]; then
      printf '%s\n' "Spark detected"
      source /usr/share/modules/init/bash
      export MODULEPATH=/opt/nvidia/hpc_sdk/modulefiles:$MODULEPATH

      export OLLAMA_MODELS=/fsc/home/hampel/temp/ollama/models
      export OLLAMA_KEEP_ALIVE=360m
      alias ollama="/fsc/home/hampel/temp/ollama/bin/ollama"

      alias vi=vim
    fi

elif [[ "$HOST" == ProBook* || "$HOST" == Mac.telekom.ip ]]; then
    printf '%s\n' "ProBook detected"
    ulimit -s unlimited
    ulimit -c unlimited

    # default editor
    export EDITOR="nvim"
    export NCORE=16
    alias vi=nvim
    alias vimdiff='nvim -d'
    export CXXFLAGS="-stdlib=libc++ -Wno-register -march=native"
    export CFLAGS='-march=native'
    export OMP_NUM_THREADS=1
    export MKL_NUM_THREADS=1
 
    alias devpy='source $HOME/pyvenv/devpy/bin/activate'
    alias llm='source $HOME/pyvenv/llm/bin/activate'
    alias triqs33x='source $HOME/pyvenv/triqs33x/bin/activate'
    alias mariadb='/opt/homebrew/opt/mariadb/bin/mariadbd-safe --datadir\=/opt/homebrew/var/mysql & '

    # kitten ssh
    alias ssk='kitten ssh'

    # docker bin dir to path
    export PATH=/Users/ahampel/.docker/bin:$PATH

else
    printf '%s\n' "default config"
    export EDITOR="vim"
    alias vi=vim
fi

alias mdev='bash $HOME/git/dotfiles/tools/make_dev.sh'
alias mvasp='bash $HOME/git/dotfiles/tools/make_vasp.sh'
alias mvaspcmake='bash $HOME/git/dotfiles/tools/make_vasp_cmake.sh'
alias vaspgdb='bash $HOME/git/dotfiles/tools/run_vasp_gdb.sh'
alias envasp='source $HOME/git/dotfiles/tools/env_vasp.sh'

alias df='df -h'                          # human-readable sizes
alias la='ls --color=auto -lh'
alias cp="cp -i"                          # confirm before overwriting something
alias free='free -m'                      # show sizes in MB
alias np='nano -w PKGBUILD'
alias more=less
alias tmux='tmux -u'

alias rvaspout='mkdir -p vasp_old_out && mv ML_* WAVECAR CHGCAR vasp.ctrl vasp.h5 vaspout.h5 vasp.pg1 vasprun.xml vasptriqs.h5 vasp.lock XDATCAR PROJCAR PCDAT OUTCAR OSZICAR LOCPROJ IBZKPT EIGENVAL DOSCAR CONTCAR STOPCAR REPORT ICONST HILLSPOT PROCAR CHG conv_imp* observables_imp* H_imp* vasp_old_out/'

alias ls='ls --color=auto -lh'
alias grep='grep --colour=auto'
alias egrep='egrep --colour=auto'
alias fgrep='fgrep --colour=auto'

alias gitw='git worktree'
alias gits='git status'
alias gitp='git pull --autostash'
alias gitb='git branch -a -vv'
alias gitl="git log --graph --abbrev-commit --decorate --format=format:'%C(blue)%h%C(reset) - %C(cyan)%aD%C(reset) %C(green)(%ar)%C(reset)%C(yellow)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)'"

# simple terminal calculator via python
calc() {
        python3 -c 'from math import *; import sys; print(eval(" ".join(sys.argv[1:])))' "$@"
    }

bconv() {
    python3 -c 'import sys; print(11604.5181217/float(sys.argv[1]))' "$@"
    }

TmeV() {
    python3 -c 'import sys; print(8.61732814974056e-02*float(sys.argv[1]))' "$@"
    }

# extract function
extract () {
   if [ -f $1 ] ; then
       case $1 in
           *.tar.bz2)   tar xvjf $1    ;;
           *.tar.gz)    tar xvzf $1    ;;
           *.bz2)       bunzip2 $1     ;;
           *.rar)       unrar x $1       ;;
           *.gz)        gunzip $1      ;;
           *.tar)       tar xvf $1     ;;
           *.tbz2)      tar xvjf $1    ;;
           *.tgz)       tar xvzf $1    ;;
           *.zip)       unzip $1       ;;
           *.Z)         uncompress $1  ;;
           *.7z)        7z x $1        ;;
           *)           echo "don't know how to extract '$1'..." ;;
       esac
   else
       echo "'$1' is not a valid file!"
   fi
 }
