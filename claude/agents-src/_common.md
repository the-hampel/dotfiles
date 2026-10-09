# Working rules (all agents, interactive Claude Code)

You work **interactively with the human** (Alexander Hampel, VASP and TRIQS developer) in
their own checkout and terminal. The global `~/.claude/CLAUDE.md` and the skills apply. The
repo's own `CLAUDE.md`/`AGENTS.md` is binding where it is more specific. The same agent also
runs in the human's Paperclip setup; this is its interactive twin.

## Memory

At the start, read `~/paperclip/agents/memory/_shared.md` and
`~/paperclip/agents/memory/<your-name>.md`. They are short, dated facts, shared with your
Paperclip twin. Append a line (`- YYYY-MM-DD <fact>`) when something cost a debug cycle;
keep each file under ~50 lines. Long-form notes go in the Obsidian vault
(`hampel/claude-memory/<project>/`).

## What needs the human's explicit OK in this chat

Ask first, showing the exact command, for:
- anything that leaves the machine: `git push`, creating or merging MRs/PRs, comments or
  state changes on GitLab/GitHub issues, tags, releases;
- history rewrites of shared branches (force push, rebase of a published branch);
- **privileged steps.** Never run `sudo`/`su`, never act as `itsme` or `root`. Instead hand
  over a block in this order, then continue once the human has run it:
  1. Preconditions;
  2. `Deploy (as itsme|root)`: absolute paths, `\cp -f`, idempotent, one account per block;
  3. Verify, with the expected output;
  4. Rollback;
  5. "then, as hampel".
- live cluster changes (slurm daemons or config, systemd, ansible, `/opt/share`): same
  pattern.

Read-only inspection, local builds in scratch and slurm test jobs need no OK. Leave no jobs
running (`squeue --me`).

## Changes and commits

- One logical change per commit. The message explains **why**, not only what.
- **Code comments are minimal.** A comment states behaviour (units, invariants, non-obvious
  inputs and outputs), never history or reasoning; those belong in the commit message.
- **No internal ticket ids** (`ROOA-…`, Paperclip) in anything public: branch names, commit
  messages, MR/PR text, comments.
- Build dirs live outside the source tree (scratch: `/wahoo06.local/hampel_temp/...`,
  `~/scratch`).
- **Before calling a change done, offer a fresh review** with the `peer-review` skill: a
  separate reviewer with a clean context, blocking findings only.

## Reporting

- Be concise; sacrifice grammar for concision.
- Say what you verified and how, and plainly what you did not.
- Report results where the human asked, with the final table or verdict, not "see elsewhere".
- If a later fix changes earlier test results, re-run the original tests before calling it
  done; a spot check is not enough.
