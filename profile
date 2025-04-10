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

elif [ "$HOSTNAME" = thinkpad ]; then
    printf '%s\n' "thinkpad detected"
    export NCORE=4
    export CC=clang
    export CXX=clang++
    export EDITOR="nvim"
    alias vi=nvim
    source "$HOME/.vim/plugged/gruvbox/gruvbox_256palette.sh"

    alias sys-update='sudo pacman -Syu --verbose'
    # zoxide smarter cd command. Install via: curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
    eval "$(zoxide init --cmd cd bash)"
    # fzf fuzzy command line search
    source /usr/share/fzf/completion.bash && source /usr/share/fzf/key-bindings.bash

elif [[ "$HOSTNAME" == *.vasp.co && "$HOSTNAME" != *porgy02 ]]; then
    printf '%s\n' "vasp detected"

    export PATH="/fsc/home/hampel/.local/bin:/fsc/home/hampel/.local/go/bin:/fsc/home/hampel/go/bin:/wahoo06.local/hampel_temp/ollama/bin:$PATH"

    # ollama models
    export OLLAMA_MODELS=/wahoo06.local/hampel_temp/ollama/models
    alias ollama="/wahoo06.local/hampel_temp/ollama/bin/ollama"
    alias askqwen='ollama run qwen2.5-coder:14b'
    alias llm="micromamba activate llm"
    alias lamaserve="ollama serve &"
    alias lamaweb="open-webui serve &"
    
    export JUPYTERLAB_DIR=/mnt/home/ahampel/.jupyter/lab

    # slurm
    alias qs='squeue --sort "P,U" -o "%.10i %.10u %40j %.12M %.2t %.6D %.6C %30R"'
    alias si='Sinfo'
    alias getnode='srun --nodes=1 --time 360 --partition=guppy01,guppy02,guppy05,guppy06,guppy07 --ntasks-per-node=1 --cpus-per-task=16 --cpu-bind=cores --pty bash -i'
    alias allocnode='salloc --nodes=1 --time 24:00:00 --partition=guppy07 --ntasks-per-node=2 --cpus-per-task=8'
  
    # apptainer
    export APPTAINER_CACHEDIR=/wahoo06.local/hampel_temp/apptainer/cache
    export PATH=/wahoo06.local/hampel_temp/apptainer/bin:$PATH
    
    # perf stuff
    ulimit -s unlimited
    export OMP_NUM_THREADS=1
    export OMP_STACKSIZE=2048m
    export NCORE=32
    export HDF5_USE_FILE_LOCKING=FALSE

    # default editor
    export EDITOR="nvim"
    alias vi='nvim --listen /tmp/nvim-server-hampel.pipe'
    alias vimdiff='nvim -d'
  
    # conda
    alias dev-triqs='micromamba activate triqs-dev'
    alias dev-vasp='micromamba activate vasp-dev'

    # intel stuff
    export MKL_NUM_THREADS=1
    alias ifxgpu='ifx -fiopenmp -fopenmp-targets=spir64 -g'

elif [[ "$HOSTNAME" == ProBook* || "$HOSTNAME" == Mac.telekom.ip ]]; then
    printf '%s\n' "ProBook detected"
    ulimit -s unlimited

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

alias mount-home-ccq='sshfs flatiron:/mnt/home/ahampel /home/ahampel/ccq-home-fs'
alias mount-ceph-ccq='sshfs flatiron:/mnt/ceph/users/ahampel /home/ahampel/ccq-ceph-fs'
alias umount-ccq='fusermount -u /home/ahampel/ccq-home-fs &> /dev/null && fusermount -u /home/ahampel/ccq-ceph-fs &> /dev/null'

alias mount-vasp-scratch='sshfs hampel@10.23.0.2:/scratch/hampel /home/ahampel/vasp-scratch'
alias mount-vasp-home='sshfs hampel@10.23.0.2:/fsc/home/hampel /home/ahampel/vasp-home'

alias ls='ls --color=auto -lh'
alias grep='grep --colour=auto'
alias egrep='egrep --colour=auto'
alias fgrep='fgrep --colour=auto'

alias gitw='git worktree'
alias gits='git status'
alias gitp='git pull --autostash'
alias gitb='git branch -a -vv'
alias gitl="git log --graph --abbrev-commit --decorate --format=format:'%C(blue)%h%C(reset) - %C(cyan)%aD%C(reset) %C(green)(%ar)%C(reset)%C(yellow)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)' --first-parent"

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
