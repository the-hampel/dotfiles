---
name: peer-review
description: Fresh-context review of the current change before it is called done or published — spawns the `reviewer` agent (clean context, never saw the code being written) on the branch/commit range vs its base and reports blocking findings only. Use when the user says "review this", "peer review", "/peer-review", before pushing/opening an MR/PR, or when an agent offers a review at the end of a change.
---

# peer-review

A second pair of eyes that did not write the code, like Paperclip's reviewer stage.

1. **Find the change.**
   - Repo root: `git rev-parse --show-toplevel`.
   - Base, in order of preference:
     1. what the user named;
     2. the upstream of the current branch (`git rev-parse --abbrev-ref @{u}`);
     3. `git merge-base HEAD <remote>/<mainline>`. The mainline is `master`, `main`,
        `unstable` for TRIQS, or `dev` for ase-driver. Check `git remote -v` for the
        GitLab/GitHub remote name.
   - Show the user the range: `git log --oneline <base>..HEAD`, plus `git status --short`.
     Uncommitted changes are included only if the user says so; otherwise mention them.
   - If the range is empty or huge (>50 commits), ask first.
2. **Collect the author's claims** from this conversation: what was built or tested, on
   which machine, which tests. Pass them on verbatim. "No claims" is fine.
3. **Spawn the reviewer** (Agent tool, `subagent_type: "reviewer"`) with a self-contained
   prompt:
   - repo path and range;
   - "include uncommitted changes" if asked;
   - the author's claims;
   - the domain, if known (e.g. VASP closed source, TRIQS public);
   - "Report the VERDICT line and numbered blocking findings only."

   Do not pre-judge or summarise the code for it; the fresh context is the point.
4. **Report** the reviewer's verdict and findings to the user verbatim, then add one line:
   what you would do about each blocking finding.
   - Do not fix anything until the user says so.
   - After fixes, offer one re-review of the new commits only.

Never push, open MRs/PRs or comment on GitLab/GitHub as part of a review.
