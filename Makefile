# Install ./dotfile in ~/.dotfile by symlink, unless it's already done.
# Try -r first since it's nicer, but only works on GNU ln.
$(HOME)/.%: %
	ln -snf $(PWD)/$< $@

# Install all files added to git:
# files:=$(filter-out Makefile bashrc,$(shell git ls-files))
# You could also set this to all files in the directory:
#files:=$(filter-out Makefile,$(wildcard *))
# Or to an explicit list of files:
files=
files+=bashrc
files+=gitconfig
files+=glob_git_ignore
files+=tmux.conf
files+=vimrc
# files+=vim
files+=jupyter/jupyter_server_config.py
files+=config/pycodestyle
files+=config/ruff/ruff.toml
files+=config/libinput-gestures.conf
files+=config/kitty/kitty.conf
files+=config/kitty/gruvbox_dark.conf
files+=config/nvim/lua/custom/chadrc.lua
files+=config/nvim/lua/custom/init.lua
files+=config/nvim/lua/custom/mappings.lua
files+=config/nvim/lua/custom/plugins.lua
files+=config/nvim/lua/custom/configs/lspconfig.lua
files+=config/nvim/lua/custom/configs/null-ls.lua

.PHONY: install
install: $(addprefix $(HOME)/.,$(files))
