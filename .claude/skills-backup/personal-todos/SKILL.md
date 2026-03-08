---
name: personal-todos
description: >
  Manage Matt's personal todo list in the 2brain Obsidian vault. Use this skill
  whenever the user mentions todos, tasks, to-do lists, adding a task, checking
  something off, what's due, what's overdue, or viewing active tasks. Triggers on
  "add this to my todos", "mark that done", "what do I need to do", "what's overdue",
  "show my tasks", or any request to view, add, edit, or complete items in the task
  list. This skill ONLY manages the flat task file — for projects, inbox processing,
  PARA classification, weekly reviews, or "where does this go?" questions, defer to
  the para-second-brain skill. Works from Claude Desktop/Chat and OpenClaw.
---

# Personal Todos

Manages the task checklist in Matt's **2brain** Obsidian vault.
This skill owns one file: `To Do (PARA).md`. Nothing else.

For anything beyond simple tasks — creating projects, filing into PARA folders,
inbox processing, weekly/monthly reviews, archiving — **use the `para-second-brain` skill**.

## Vault & File Location

```
VAULT="/Users/mattabar/Library/CloudStorage/GoogleDrive-mattaabar@gmail.com/My Drive/Obsidian/2brain"
FILE="$VAULT/To Do (PARA).md"
```

> **Critical:** Always use the full `/Users/mattabar/...` path. Never use `~` or `$HOME` —
> shell expansion fails silently in Google Drive paths.

---

## Task Format

```markdown
- [ ] Task description                          # Basic task
- [ ] Task description 📅 2026-03-15            # With due date
- [ ] Task description 🔴 📅 2026-03-15         # High priority + due date
- [ ] Task description 🔁 weekly                # Recurring
- [x] Task description ✅ 2026-03-04            # Completed
```

| Emoji | Meaning |
|-------|---------|
| 🔴 | High priority / Urgent |
| 📅 YYYY-MM-DD | Due date |
| 🔁 | Recurring |
| ✅ YYYY-MM-DD | Completion date (auto by Tasks plugin) |

## Category Headers (in order)

```markdown
## 🔴 Urgent (Due Soon)
## 🏥 Health
## 🏠 Home & Property
## ✈️ Travel
## 🤖 Tech & Setup
## 📞 Communication
## ⚖️ Legal & Professional
## 💰 Administrative
```

New categories: `## emoji Category`. Keep the emoji.

## Footer

The file ends with:
```markdown
---
*Last updated: YYYY-MM-DD HH:MM*
```

Always update the timestamp when writing.

---

## Operations

### Add a task

1. Is it a simple, single-step action doable within ~30 days? → Continue here.
   - Multi-step project, or "where does this go?" → **defer to `para-second-brain`**.
2. Read `To Do (PARA).md`.
3. Insert under the correct `##` category header.
4. If due within 3 days, also add to `## 🔴 Urgent (Due Soon)`.
5. Write the full file back. Update the timestamp.
6. Read back to verify.

### Complete a task

1. Read `To Do (PARA).md`.
2. Change `- [ ]` to `- [x]` and append ` ✅ YYYY-MM-DD` (today).
3. If the task was also in Urgent, mark it there too (or remove the line).
4. Write back. Update timestamp.
5. Do NOT move completed tasks out — the Obsidian Tasks plugin handles views.

### View tasks

- All active: read `To Do (PARA).md` and summarize.
- Overdue: filter for `📅` dates before today.
- By category: show tasks under the requested `##` header.

### Remove a task (without completing)

1. Read the file, delete the line, write back.
2. If the user wants to defer it → **use `para-second-brain`** to move it to `10_PROJECTS/Someday/`.

---

## Reading & Writing

### Read (always works)

```bash
VAULT="/Users/mattabar/Library/CloudStorage/GoogleDrive-mattaabar@gmail.com/My Drive/Obsidian/2brain"
cat "$VAULT/To Do (PARA).md"
```

### Write (Python preferred for Google Drive)

```python
vault = "/Users/mattabar/Library/CloudStorage/GoogleDrive-mattaabar@gmail.com/My Drive/Obsidian/2brain"
filepath = f"{vault}/To Do (PARA).md"

with open(filepath, 'r') as f:
    content = f.read()

# ... modify content ...

with open(filepath, 'w') as f:
    f.write(content)
```

### Shell fallback

```bash
VAULT="/Users/mattabar/Library/CloudStorage/GoogleDrive-mattaabar@gmail.com/My Drive/Obsidian/2brain"
cat > "$VAULT/To Do (PARA).md" << 'EOF'
[full file content]
EOF
```

> **Never** use `obsidian append` for mid-file insertions. Always read → edit → write full file.

---

## Handoff Rules

| User wants... | This skill? | Or defer to... |
|---|---|---|
| Add/complete/view a task | ✅ Yes | — |
| Flag overdue items | ✅ Yes | — |
| Create a project | ❌ | `para-second-brain` |
| "Where does this go?" | ❌ | `para-second-brain` |
| Process inbox | ❌ | `para-second-brain` |
| Weekly/monthly review | ❌ | `para-second-brain` |
| Archive a project | ❌ | `para-second-brain` |
| Move task to someday | ❌ | `para-second-brain` |
| File into Areas/Resources | ❌ | `para-second-brain` |
