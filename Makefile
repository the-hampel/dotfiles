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

files+=config/htop/htoprc

files+=config/jesseduffield/lazygit/config.yml

files+=config/kitty/kitty.conf
files+=config/kitty/gruvbox_dark.conf

files+=config/nvim/init.lua
files+=config/nvim/lua/mappings.lua
files+=config/nvim/lua/options.lua
files+=config/nvim/lua/autocmds.lua
files+=config/nvim/lua/chadrc.lua
files+=config/nvim/lua/configs/lazy.lua
files+=config/nvim/lua/configs/conform.lua
files+=config/nvim/lua/plugins/init.lua
files+=config/nvim/lua/configs/lspconfig.lua
files+=config/nvim/after/syntax/fortran.vim
files+=config/nvim/spell/en.utf-8.add

files+=config/opencode/opencode.jsonc
files+=config/opencode/AGENTS.md

files+=config/gh-dash/config.yml

files+=claude/settings.json
files+=claude/statusline-command.sh
files+=claude/skills/journal/SKILL.md

# global skills
files+=agents/skills/code-review-skill
files+=claude/skills/code-review-skill
files+=agents/commands/code-review.md
files+=agents/skills/handoff/SKILL.md
files+=agents/skills/vasp-compare-perf/SKILL.md
files+=agents/skills/vasp-compare-perf/vasp-compare-perf.py

# commit skill: single source under agents/, mirrored to BOTH ~/.agents/skills
# (OpenCode et al.) and ~/.claude/skills (Claude Code only scans the latter).
# claude/skills/commit is an in-repo symlink -> ../../agents/skills/commit.
files+=agents/skills/commit
files+=claude/skills/commit

# vasp-build skill: same dual-mirror pattern as commit.
# claude/skills/vasp-build is an in-repo symlink -> ../../agents/skills/vasp-build.
files+=agents/skills/vasp-build
files+=claude/skills/vasp-build

# vasp-test skill: same dual-mirror pattern.
files+=agents/skills/vasp-test
files+=claude/skills/vasp-test

files+=config/ruff/ruff.toml

files+=local/share/fzf/completion.bash
files+=local/share/fzf/key-bindings.bash
files+=local/share/okular/okularpartrc
files+=local/share/okular/part.rc
files+=local/share/okular/shell.rc

files+=vim/colors/gruvbox.vim

all: install

.PHONY: install
install: $(addprefix $(HOME)/.,$(files))

