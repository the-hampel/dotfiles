---
name: obsidian
description: Read from and write to the user's Obsidian vault (~/obsidian/hampel) with plain file tools. Covers vault layout (work notes, journal, claude-memory per project), search with rg, and note conventions. Use when the user mentions Obsidian, the vault, notes, journal, "claude-memory", asks to save/store/remember something long-form, or to look up something they wrote down earlier.
---

# Obsidian vault

The vault is a folder of plain markdown. No server or MCP is needed: use `read`, `write`,
`edit`, and `rg`/`find` via bash.

**Root:** `~/obsidian/hampel/` (the `.obsidian/` dir is app config, never touch it).

## Layout

| Folder | Content |
|--------|---------|
| `work/` | Topic notes (physics, tools, clusters, benchmarks), one file per topic, e.g. `Green function.md`, `nvidia offloading.md` |
| `journal/` | Dated entries, `YYYY-MM-DD.md` (a descriptive suffix is fine: `2026-07-07 Arc Pro B70 vs Intel Max GPU benchmark.md`) |
| `claude-memory/<project>/` | Long-form agent notes per project: plans, backlogs, install logs, review plans. A project may have a `CLAUDE.md` index; read it once before other files in that folder |
| `IT_wiki/` | IT how-tos |
| `private/` | Personal. **Do not read or search unless explicitly asked** |
| `assets/` | Attachments |

Do not touch `private/` or any file that looks like a credential or backup export.

## Finding things

```bash
rg -il 'term' ~/obsidian/hampel --glob '!private/**' --glob '!.obsidian/**'
rg -n  'term' ~/obsidian/hampel/work
find ~/obsidian/hampel/journal -name '2026-08*'
```

Search by filename first (`find`/`ls`), then content. Read only the files that matter.

## Writing notes

- Markdown, one topic per file, filename = readable title (spaces allowed).
- Link with wiki links: `[[Green function]]`. Math with `$...$` / `$$...$$`.
- Prefer **appending or editing** an existing note over creating a near-duplicate:
  search first.
- New agent memory goes in `claude-memory/<project>/<kebab-case-topic>.md`. Start with a one-line
  summary, put dates as `YYYY-MM-DD`.
- Journal: new file `journal/YYYY-MM-DD.md` (append if today's exists) with short
  bullets: what was done/decided, and next steps as `- [ ]` items. Concise, for recall
  weeks later, not a transcript.
- Short, dated facts that cost a debug cycle belong in `~/paperclip/agents/memory/`, not
  in the vault.

## Rules

- Show the user the path of every note you create or modify.
- Never delete or rename notes (Obsidian links would break) without explicit OK.
- Don't reformat existing notes; make minimal edits.
