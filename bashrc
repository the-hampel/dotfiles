#
# ~/.bashrc
#

if [ -z "$PS1" ]; then
        return
fi

export PS1="\h>"

export LC_ALL=en_US.utf8
export LANG=en_US.utf8


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
    alias triqs-backup="tar --use-compress-program=pigz -cf /mnt/home/ahampel/Dropbox/work/git_backup/$(date '+%Y-%m-%d')-triqs-git-ccqlin.tar.gz --directory=/mnt/home/ahampel/git/triqs ."
    # load some default modules
    module load modules/2.2-20230808 slurm tmux git fi-utils python/3.10 nodejs
    # default venv
    # source $HOME/py_venv/310/bin/activate
    alias 310='source $HOME/py_venv/310/bin/activate'


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
    printf '%s\n' "thinkXtreme detected"
    export NCORE=20
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
    export BLA_VENDOR=Intel10_64_dyn
    export MKL_INTERFACE_LAYER=GNU,LP64
    export MKL_THREADING_LAYER=SEQUENTIAL
    export MKL_NUM_THREADS=1
    export CXXFLAGS="-stdlib=libc++ -Wno-register -march=native"
    export CFLAGS='-march=native -Wno-error=incompatible-function-pointer-type'

    # old docker command
    alias triqs='docker run -it --shm-size=4g -e USER_ID=`id -u` -e GROUP_ID=`id -g` -p 8378:8378 -v $PWD:/work -v /home/ahampel:/home/ahampel solid_dmft_ompi bash'

    source "$HOME/.vim/plugged/gruvbox/gruvbox_256palette.sh"
    set use_color true

    # zoxide smarter cd command. Install via: curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
    eval "$(zoxide init --cmd cd bash)"
    # fzf fuzzy command line search
    source /usr/share/fzf/completion.bash && source /usr/share/fzf/key-bindings.bash

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

else
    printf '%s\n' "default config"
    export EDITOR="vim"
    alias vi=vim
fi

alias mdev='bash $HOME/git/dotfiles/tools/make_dev.sh'

alias df='df -h'                          # human-readable sizes
alias la='ls --color=auto -lh'
alias cp="cp -i"                          # confirm before overwriting something
alias free='free -m'                      # show sizes in MB
alias np='nano -w PKGBUILD'
alias more=less
alias tmux='tmux -u'


alias mount-home-ccq='sshfs flatiron:/mnt/home/ahampel /home/ahampel/ccq-home-fs'
alias mount-ceph-ccq='sshfs flatiron:/mnt/ceph/users/ahampel /home/ahampel/ccq-ceph-fs'
alias umount-ccq='fusermount -u /home/ahampel/ccq-home-fs &> /dev/null && fusermount -u /home/ahampel/ccq-ceph-fs &> /dev/null'

alias ls='ls --color=auto -lh'
alias grep='grep --colour=auto'
alias egrep='egrep --colour=auto'
alias fgrep='fgrep --colour=auto'

alias flatiron='ssh flatiron -t ssh ccqlin027'

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

[[ $- != *i* ]] && return

colors() {
	local fgc bgc vals seq0

	printf "Color escapes are %s\n" '\e[${value};...;${value}m'
	printf "Values 30..37 are \e[33mforeground colors\e[m\n"
	printf "Values 40..47 are \e[43mbackground colors\e[m\n"
	printf "Value  1 gives a  \e[1mbold-faced look\e[m\n\n"

	# foreground colors
	for fgc in {30..37}; do
		# background colors
		for bgc in {40..47}; do
			fgc=${fgc#37} # white
			bgc=${bgc#40} # black

			vals="${fgc:+$fgc;}${bgc}"
			vals=${vals%%;}

			seq0="${vals:+\e[${vals}m}"
			printf "  %-9s" "${seq0:-(default)}"
			printf " ${seq0}TEXT\e[m"
			printf " \e[${vals:+${vals+$vals;}}1mBOLD\e[m"
		done
		echo; echo
	done
}

set use_color true

# Set colorful PS1 only on colorful terminals.
# dircolors --print-database uses its own built-in database
# instead of using /etc/DIR_COLORS.  Try to use the external file
# first to take advantage of user additions.  Use internal bash
# globbing instead of external grep binary.
safe_term=${TERM//[^[:alnum:]]/?}   # sanitize TERM
match_lhs=""
[[ -f ~/.dir_colors   ]] && match_lhs="${match_lhs}$(<~/.dir_colors)"
[[ -f /etc/DIR_COLORS ]] && match_lhs="${match_lhs}$(</etc/DIR_COLORS)"
[[ -z ${match_lhs}    ]] \
	&& type -P dircolors >/dev/null \
	&& match_lhs=$(dircolors --print-database)
[[ $'\n'${match_lhs} == *$'\n'"TERM "${safe_term}* ]] && use_color=true

# Enable colors for ls, etc.  Prefer ~/.dir_colors #64489
if type -P dircolors >/dev/null ; then
    if [[ -f ~/.dir_colors ]] ; then
        eval $(dircolors -b ~/.dir_colors)
    elif [[ -f /etc/DIR_COLORS ]] ; then
        eval $(dircolors -b /etc/DIR_COLORS)
    fi
fi

unset use_color safe_term match_lhs sh


xhost +local:root > /dev/null 2>&1

complete -cf sudo

# Bash won't get SIGWINCH if another process is in the foreground.
# Enable checkwinsize so that bash will check the terminal size when
# it regains control.  #65623
# http://cnswww.cns.cwru.edu/~chet/bash/FAQ (E11)
shopt -s checkwinsize

shopt -s expand_aliases

# export QT_SELECT=4

# Enable history appending instead of overwriting.  #139609
shopt -s histappend

#
# # ex - archive extractor
# # usage: ex <file>
ex ()
{
  if [ -f $1 ] ; then
    case $1 in
      *.tar.bz2)   tar xjf $1   ;;
      *.tar.gz)    tar xzf $1   ;;
      *.bz2)       bunzip2 $1   ;;
      *.rar)       unrar x $1     ;;
      *.gz)        gunzip $1    ;;
      *.tar)       tar xf $1    ;;
      *.tbz2)      tar xjf $1   ;;
      *.tgz)       tar xzf $1   ;;
      *.zip)       unzip $1     ;;
      *.Z)         uncompress $1;;
      *.7z)        7z x $1      ;;
      *)           echo "'$1' cannot be extracted via ex()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi

if [ -n "$(which tmux 2>/dev/null)" ]; then
    function tmux() {
        local tmux=$(type -fp tmux)
        case "$1" in
            reorder-windows|reorder|defrag)
                local i=$(tmux show-option -g |awk '/^base-index/ {print $2}')
                local w
                for w in $(tmux lsw | awk -F: '{print $1}'); do
                    if [ $w -gt $i ]; then
                        echo "Moving $w -> $i"
                        $tmux movew -d -s $w -t $i
                    fi
                    (( i++ ))
                done
                ;;
            update-environment|update-env|env-update)
                local v
                while read v; do
                    if [[ $v == -* ]]; then
                        unset ${v/#-/}
                    else
                        # Add quotes around the argument
                        v=${v/=/=\"}
                        v=${v/%/\"}
                        eval export $v
                    fi
                done < <(tmux show-environment)
                ;;
            *)
                $tmux "$@"
                ;;
        esac
    }
fi
}



