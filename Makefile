# Install ./dotfile in ~/.dotfile by symlink, unless it's already done.
# Try -r first since it's nicer, but only works on GNU ln.
$(HOME)/.%: %
	[[ $@ -ef $< ]] || \
		ln -snr $< $@ 2>/dev/null || \
		ln -sn $(PWD)/$< $@

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
files+=vim

.PHONY: install
install: $(addprefix $(HOME)/.,$(files))
