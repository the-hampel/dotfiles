#
# ~/.bashrc
#

export PS1="\h>"

export LC_ALL=en_US.utf8
export LANG=en_US.utf8
export CC=clang
export CXX=clang++

# output full docker build output
export BUILDKIT_PROGRESS=plain

export EDITOR="nvim"

alias df='df -h'                          # human-readable sizes
alias la='ls --color=auto -lh'
alias free='free -m'                      # show sizes in MB
alias np='nano -w PKGBUILD'
alias more=less
alias vi=nvim
alias nv=nvim
alias tmux='tmux -u'
alias gits='git status'
alias gitb='git branch -vv'

#alias jupyter='docker run -it --rm  --shm-size=4g -e USER_ID=`id -u` -e GROUP_ID=`id -g` -p 8378:8378 -v $PWD:/work -v /home/alex:/home/alex triqs3-dev jupyter.sh'
alias triqs='docker run -it --shm-size=4g -e USER_ID=`id -u` -e GROUP_ID=`id -g` -p 8378:8378 -v $PWD:/work -v /home/ahampel:/home/ahampel solid_dmft_ompi bash'

# python venv
alias triqs-dev='source $HOME/triqs-dev/bin/activate'
alias triqs-rel='source $HOME/triqs-rel/bin/activate'


alias qs='squeue -u $USER -o "%.8i_ %40j %.12M %.2t %.8D %18S %30R %Q"'

alias mount-home-ccq='sshfs flatiron:/mnt/home/ahampel /home/ahampel/ccq-home-fs'
alias mount-ceph-ccq='sshfs flatiron:/mnt/ceph/users/ahampel /home/ahampel/ccq-ceph-fs'
alias umount-ccq='fusermount -u /home/ahampel/ccq-home-fs &> /dev/null && fusermount -u /home/ahampel/ccq-ceph-fs &> /dev/null'


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


source "$HOME/.vim/plugged/gruvbox/gruvbox_256palette.sh"
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


alias ls='ls --color=auto -lh'
alias grep='grep --colour=auto'
alias egrep='egrep --colour=auto'
alias fgrep='fgrep --colour=auto'

alias flatiron='ssh flatiron -t ssh ccqlin027'

alias gitl="git log --graph --abbrev-commit --decorate --format=format:'%C(blue)%h%C(reset) - %C(cyan)%aD%C(reset) %C(green)(%ar)%C(reset)%C(yellow)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)' --first-parent"

export PATH="~/codes/scripts/linux:~/git/bin:$PATH"

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

