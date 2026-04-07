---
name: journal
description: Add a work journal entry to Notion summarizing what was discussed or accomplished in this conversation.
argument-hint: "[optional title override]"
disable-model-invocation: true
---

Create a new entry in the user's Notion work journal database summarizing the current conversation.

## Instructions

1. Review the conversation so far and identify the key topics, decisions, accomplishments, and next steps.

2. Create a page in the Notion work journal database using:
   - **Parent**: `{"type": "data_source_id", "data_source_id": "43e0edb0-4593-4acb-9953-e24d0ca58410"}`
   - **Properties**:
     - `Name`: A concise, descriptive title for the entry (or use `$ARGUMENTS` if provided)
     - `Tags`: Pick the most relevant from: `["Daily", "Work", "Research", "Personal", "Planning", "Career"]`

3. **Page content structure** (use Notion-flavored Markdown):
   - `## Summary` — 2-4 bullet points of what was discussed/accomplished
   - `## Details` — Key technical details, decisions made, or problems solved (keep it concise but useful for future reference)
   - `## Next Steps` — Actionable to-do items as a checklist (`- [ ] item`)

4. Keep the entry concise and scannable. Focus on what would be useful to recall weeks later, not a transcript of the conversation.

5. After creating the page, share the Notion URL with the user.
