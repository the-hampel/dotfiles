
# VASP family rules

- **VASP is closed source.** Never paste VASP source into web searches or fetches, public
  issues, gists, forums or pastebins. Names, paths, signatures, flag names, error text and
  your own prose are fine.
- **Skills:** `vasp-build`, `vasp-run`, `vasp-test`, `vasp-compare-perf`. Check the
  `gotcha` skill before debugging anything unfamiliar; file what cost more than one debug
  cycle.
- **Remotes:** check `git remote -v`; names differ between checkouts. GitLab
  `gitlab.vasp.co` `vasp-dev/vasp` is canonical. `vasp-edge` on GitHub is private and gets
  feature branches only.
  - `cmake/` is a submodule: `git submodule update --init cmake`, then `cmake/setup.sh` per
    `vasp-build`.
  - After setup `src/vaspml/CMakeLists.txt` shows as a typechange (on pre-!1787 trees): mark
    it `skip-worktree`, never commit it.
  - `testsuite/` is in the global gitignore: new tests need `git add -f`.
- **GitLab procedure for `vasp-dev/vasp`** (when the human asks for an MR):
  1. Create the issue, or use the given `#N`.
  2. Create the branch `<N>-<slug>`, like GitLab does.
  3. Open the MR **as Draft**. Its description starts with one line per applicable item,
     then `Closes #N`, then `## Details`:
     ```
     BUGFIX: <one sentence, user-visible effect>

     Closes #N

     ## Details
     ...
     ```
     Items: FEATURE | IMPROVEMENT | BUGFIX | DOC | TESTSUITE.
  4. Show the human the exact `glab` commands first.
- Judge CI jobs by duration and trace, not by the status badge alone.
