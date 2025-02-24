# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# prevents match not found errors when globbing via rsync or scp
unsetopt nomatch

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

source $ZSH/oh-my-zsh.sh

HOSTNAME=$(hostname)

eval "$(/opt/homebrew/bin/brew shellenv)"

PROMPT=$'%F{214}%m %F{166}[%F{142}%~%F{166}]%f $(git branch 2>/dev/null | grep "*" | sed "s/* //g" | sed "s/.*/ (%F{108}&%f)/") %F{246}$(date +%H:%M:%S)%f\n%F{166}╰─%F{214}❯%f '

# Add virtual environment check:
if [[ -n "$VIRTUAL_ENV" ]]; then
  # Display the virtual environment name in brackets, with a color
  PROMPT="%F{220}($(basename $VIRTUAL_ENV))%f $PROMPT"
fi

##### load all bash related stuff #######################
[[ -e ~/.profile ]] && emulate sh -c 'source ~/.profile'
#########################################################

export PATH=$(brew --prefix)/opt/llvm/bin:/Users/ahampel/.local/bin:$PATH
export LIBRARY_PATH=$(brew --prefix)/opt/llvm/lib:$LIBRARY_PATH
export CC=$(brew --prefix)/opt/llvm/bin/clang
export CXX=$(brew --prefix)/opt/llvm/bin/clang++

