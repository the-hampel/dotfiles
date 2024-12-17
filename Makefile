# Install ./dotfile in ~/.dotfile by symlink, unless it's already done.
# Try -r first since it's nicer, but only works on GNU ln.
$(HOME)/.%: %
	mkdir -p $(@D)
	ln -snf $(PWD)/$< $@

# Install all files added to git:
# files:=$(filter-out Makefile bashrc,$(shell git ls-files))
# You could also set this to all files in the directory:
#files:=$(filter-out Makefile,$(wildcard *))
# Or to an explicit list of files:
files=
files+=bashrc
files+=profile
files+=zshrc
files+=gitconfig
files+=glob_git_ignore
files+=tmux.conf
files+=vimrc
files+=ripgreprc

files+=jupyter/jupyter_server_config.py

files+=config/pycodestyle
files+=config/gruvbox_256palette.sh
files+=config/libinput-gestures.conf

files+=config/ruff/ruff.toml

files+=config/jesseduffield/lazygit/config.yml

files+=config/kitty/kitty.conf
files+=config/kitty/gruvbox_dark.conf

files+=config/nvim/lua/chadrc.lua
files+=config/nvim/lua/mappings.lua
files+=config/nvim/lua/options.lua
files+=config/nvim/lua/plugins/init.lua
files+=config/nvim/lua/configs/lspconfig.lua
files+=config/nvim/after/syntax/fortran.vim

files+=local/share/fzf/completion.bash
files+=local/share/fzf/key-bindings.bash
files+=local/share/okular/okularpartrc
files+=local/share/okular/part.rc
files+=local/share/okular/shell.rc

all: install

.PHONY: install
install: $(addprefix $(HOME)/.,$(files))

