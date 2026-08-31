# ~/.zshenv is read by EVERY zsh invocation (interactive, non-interactive,
# login, non-login) - unlike ~/.zshrc or /etc/profile, which only run in
# interactive or login shells.
#
# On the VASP cluster, Lmod's `module` function and the cluster MODULEPATH
# (spack, NEC, vaspdb, ...) are only set up in login shells via
# /etc/profile.d/modules.sh. Non-login shells - e.g. scripts, or the
# persistent shell used by opencode/Claude Code bash tools - therefore have
# no `module` command at all. Source the same file here so `module` works
# everywhere. It is idempotent: the script guards itself with
# MODULEPATH_ROOT, so login shells (where /etc/profile already ran it)
# skip it.
if [ -f /etc/profile.d/modules.sh ] && ! whence -w module >/dev/null 2>&1; then
  . /etc/profile.d/modules.sh
fi
