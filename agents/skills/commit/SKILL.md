---
name: commit
description: Commit the uncommitted changes that belong to what we worked on in this conversation, splitting distinct pieces of work into separate commits and leaving unrelated changes untouched.
argument-hint: "[optional scope/message hint, e.g. 'only the slidecraft fix' or 'wip']"
disable-model-invocation: true
---

Commit the working-tree changes that resulted from **this conversation**, and only those.

## Core rules

1. **Only commit what is in scope.** Use the conversation history to decide which changed files/hunks are the result of work we actually did together. Any change that is unrelated to our session (pre-existing edits, unrelated files someone else touched, stray local tweaks) must be **left unstaged** — never `git add -A` blindly.
2. **Separate concerns into separate commits.** If we worked on more than one distinct thing (e.g. a source-code fix *and* a content/document edit, or two unrelated features), make one commit per logical change rather than a single mixed commit.
3. **Never push** unless the user explicitly asks in `$ARGUMENTS`.
4. **Never create a branch or change branches.** Commit on the current branch.
5. Treat the `/commit` invocation itself as authorization to commit — do not ask "should I commit?". Do briefly show the grouping you chose (see step 5) so the user can see what landed.

## Steps

1. **Survey the state.** Run in parallel:
   - `git status --porcelain=v1` (untracked + modified, machine-readable)
   - `git diff` (unstaged tracked changes) and `git diff --staged` (anything already staged)
   - `git log --oneline -10` to learn the repo's commit-message convention (e.g. Conventional Commits like `feat:`, `fix:`, `docs:` — match what you see).
   - If the current directory is inside a different git repo than other changed files (nested repos / multiple repos touched this session), handle each repo separately and say so.

2. **Determine scope.** For each changed path, decide whether it came out of *this* conversation:
   - In scope → include it.
   - Not clearly ours / unrelated → exclude it and remember to report it.
   - If `$ARGUMENTS` narrows the scope (e.g. "only the slidecraft fix"), honor that and commit only the matching subset.
   - If you genuinely cannot tell whether a change is in scope, list it under "left for you to review" rather than committing it.

3. **Group into commits.** Cluster the in-scope changes by logical concern. A good heuristic: changes that would be described by one sentence belong together. Distinct subsystems, distinct features, or code-vs-docs generally split into separate commits. Preserve a sensible order (e.g. a library fix before the file that depends on it).

4. **Stage and commit each group.** For each group:
   - Stage exactly that group's paths with `git add -- <paths>` (use explicit pathspecs; do not stage anything else). For partial-file staging, use `git add -p` non-interactively only if you can do it safely; otherwise commit the whole file if the whole file is in scope.
   - Write a concise commit message in the repo's existing style. First line ≤ ~72 chars, imperative mood, scoped prefix if the repo uses one. Add a short body only when the change needs explanation.
   - Commit with `git commit -m "..."` (use multiple `-m` flags for body paragraphs). Do **not** add `Co-Authored-By` or tool advertising unless the repo's history shows that convention.
   - After committing a group, verify with `git status` that the next group's files are still unstaged as expected.

5. **Report.** When done, summarize:
   - Each commit created (short hash + subject).
   - Anything intentionally **left uncommitted** and why (out of scope / ambiguous), so the user knows it's still in the working tree.

## Notes

- If there is nothing uncommitted, say so and stop.
- If everything uncommitted is out of scope, make no commits and report what you found instead.
- Respect `.gitignore`; never force-add ignored files.
- Do not run `git commit --amend`, `git reset`, or rewrite history unless explicitly asked.
