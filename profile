# output full docker build output
export BUILDKIT_PROGRESS=plain

if [ "$HOSTNAME" = ccqlin027.flatironinstitute.org ]; then
    printf '%s\n' "CCQ workstation detected"
    export NCORE=20
    # default editor
    export EDITOR="nvim"
    alias vi=nvim
    alias vimdiff='nvim -d'

    alias quota='fi-quota'
    alias qs='squeue -u $USER -o "%.8i_ %40j %.12M %.2t %.8D %18S %30R %Q"'
    source "$HOME/.vim/plugged/gruvbox/gruvbox_256palette.sh"
    alias getrome='srun -N1 --ntasks-per-node=128 --constraint=rome --exclusive --mpi=none --pty bash -i'
    alias getice='srun -N1 --ntasks-per-node=64 --constraint=icelake --exclusive --mpi=none --pty bash -i'
    alias getgenoa='srun -N1 --ntasks-per-node=96 --constraint=ib-genoa --exclusive --mpi=none --pty bash -i'
    alias triqs-backup="tar --use-compress-program=pigz -cf /mnt/home/ahampel/Dropbox/work/git_backup/$(date '+%Y-%m-%d')-triqs-git-ccqlin.tar.gz --directory=/mnt/home/ahampel/git/triqs ."
    # load some default modules
    module load modules/2.3-20240529 slurm tmux git fi-utils python/3.11 nodejs
    # default venv
    # source $HOME/py_venv/310/bin/activate
    alias 310='source $HOME/py_venv/310/bin/activate'
    alias 311='source $HOME/py_venv/311/bin/activate'


    export MODULEPATH=/mnt/home/ahampel/git/ccq-software-build/modules:$MODULEPATH
    export MPLCONFIGDIR=/mnt/home/ahampel/.local/lib/matplotlib-cache
    export MPLBACKEND=qtagg
    export HDF5_USE_FILE_LOCKING=FALSE

    export PATH="/mnt/home/ahampel/.local/bin:$PATH"

    export JUPYTERLAB_DIR=/mnt/home/ahampel/.jupyter/lab
    [ -r /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion

    cleancrap (){
        if [[ $# -eq 0 ]] ; then
            echo 'No seedname supplied. Removing nothing.'
            return 1
        else
            seedname=$1;
        fi
        list=`echo ${seedname}.scf.in\|${seedname}.nscf.in\|${seedname}.mod_scf.in\|${seedname}.win\|${seedname}.bnd.in\|${seedname}.bands.in\|${seedname}.proj.in\|${seedname}.pw2wan.in\|${seedname}.inp\|sjob_dmft_slurm-srun.sh\|dmft_config.ini`
        ls -1 | egrep -v "^(${list})$" | xargs rm
    }

    # >>> juliaup initialize >>>

    # !! Contents within this block are managed by juliaup !!

    case ":$PATH:" in
        *:/mnt/home/ahampel/.juliaup/bin:*)
            ;;

        *)
            export PATH=/mnt/home/ahampel/.juliaup/bin${PATH:+:${PATH}}
            ;;
    esac

    # <<< juliaup initialize <<<
    # zoxide smarter cd command. Install via: curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
    eval "$(zoxide init --cmd cd bash)"

    # fzf fuzzy command line search
    [ -f ~/.fzf.bash ] && source ~/.fzf.bash

elif [ "$HOSTNAME" = thinkxtreme ]; then
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

elif [[ "$HOSTNAME" == *.vasp.co ]]; then
    printf '%s\n' "vasp detected"
    source "$HOME/.config/gruvbox_256palette.sh"
    set use_color true

    export PATH="/fsc/home/hampel/.local/bin:$PATH"

    eval "$(zoxide init --cmd cd bash)"

    # fzf fuzzy command line search
    [ -f ~/.fzf.bash ] && source ~/.fzf.bash

    export JUPYTERLAB_DIR=/mnt/home/ahampel/.jupyter/lab
    [ -r ~/.local/share/fzf/completion.bash ] && . ~/.local/share/fzf/key-bindings.bash

    alias qs='squeue --sort "P,U" -o "%.10i %.10u %40j %.12M %.2t %.6D %.6C %30R"'
    alias si='Sinfo'

    alias getnode='srun --nodes=1 --time 360 --partition=guppy01,guppy02,guppy05,guppy06,guppy07 --ntasks-per-node=1 --cpus-per-task=16 --cpu-bind=cores --pty bash -i'

    ### modules
    module load slurm
    alias vaspdev='module load vasp-gnu_mkl-dev/12.3_mkl-2023.2.0_ompi-4.1.6'

    export HDF5_USE_FILE_LOCKING=FALSE

    ulimit -s unlimited
    export NCORE=16
    # default editor
    export EDITOR="nvim"
    alias vi=nvim
    alias vimdiff='nvim -d'

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
    alias mamba='micromamba'
    alias triqs-dev='micromamba activate triqs-dev'

    export OMP_NUM_THREADS=1
    export MKL_NUM_THREADS=1
elif [[ "$HOSTNAME" == ProBook* ]]; then
    printf '%s\n' "ProBook detected"
    ulimit -s unlimited

    # default editor
    export EDITOR="nvim"
    alias vi=nvim
    alias vimdiff='nvim -d'

    export OMP_NUM_THREADS=1
    export MKL_NUM_THREADS=1
 

else
    printf '%s\n' "default config"
    export EDITOR="vim"
    alias vi=vim
fi

alias mdev='bash $HOME/git/dotfiles/tools/make_dev.sh'
alias mvasp='bash $HOME/git/dotfiles/tools/make_vasp.sh'
alias envasp='source $HOME/git/dotfiles/tools/env_vasp.sh'

alias df='df -h'                          # human-readable sizes
alias la='ls --color=auto -lh'
alias cp="cp -i"                          # confirm before overwriting something
alias free='free -m'                      # show sizes in MB
alias np='nano -w PKGBUILD'
alias more=less
alias tmux='tmux -u'

alias rvaspout='mkdir -p vasp_old_out && mv vasp.ctrl vasp.h5 vaspout.h5 vasp.pg1 vasprun.xml vasptriqs.h5 vasp.lock XDATCAR PROJCAR PCDAT OUTCAR OSZICAR LOCPROJ IBZKPT EIGENVAL DOSCAR CONTCAR STOPCAR REPORT PROCAR vaspwave.h5 WAVECAR CHG CHGCAR conv_imp* observables_imp* H_imp* vasp_old_out/'

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
alias gitp='git pull'
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
