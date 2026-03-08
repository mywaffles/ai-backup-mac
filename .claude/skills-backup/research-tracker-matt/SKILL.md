---
name: research-tracker-matt
description: >
  Automatically track research in Matt's Obsidian 2brain vault. Use this skill
  EVERY TIME research is conducted — whether via deep-research, web search,
  comparison shopping, or any multi-source investigation. Triggers proactively:
  if Claude is doing research that produces findings, sources, or recommendations,
  it MUST create or update a research project in Obsidian. Also triggers on
  "track this research", "save this to Obsidian", "create a research project",
  or "where did I research X?". This skill owns the research project lifecycle
  (create → track → complete → archive). For PARA classification, inbox processing,
  and weekly reviews, defer to para-second-brain. For simple tasks, defer to
  personal-todos. All commands run on Matt's Mac Mini via shell:run_command.
---

# Research Tracker

Automatically creates and maintains research projects in Matt's **2brain** Obsidian vault.

**Core rule:** If Claude is doing research (multiple sources, comparison, analysis),
it tracks the work in Obsidian. No research should happen without a project.

## Vault Location

```
VAULT="/Users/mattabar/Library/CloudStorage/GoogleDrive-mattaabar@gmail.com/My Drive/Obsidian/2brain"
```

> **Critical:** Always use the full `/Users/mattabar/...` path. Never `~` or `$HOME`.

## When to Trigger

This skill activates **automatically** whenever:

- `deep-research` skill is invoked
- Claude does comparison shopping or product research
- Claude investigates multiple sources on any topic
- User asks "research X", "compare X vs Y", "find the best X"
- User asks to save or track research findings

This skill does NOT handle:
- Simple single-search lookups (no project needed)
- PARA classification (use `para-second-brain`)
- Task management (use `personal-todos`)

## Project Structure

All research projects live in `10_PROJECTS/Active/` and follow this template:

```
10_PROJECTS/Active/[Project Name]/
├── AGENTS.md          ← Objective, timeline, research questions
├── Tasks.md           ← Checklist (setup → research → analysis → complete)
├── Research.md        ← Synthesis document (findings + comparison)
├── Decision.md        ← Final decision + lessons learned
├── _Sources/          ← Raw materials (PDFs, links, snapshots)
│   └── README.md
└── _Notes/            ← Literature notes (one per source)
    └── README.md
```

## Create a Research Project

### 1. Check for existing research first

```bash
VAULT="/Users/mattabar/Library/CloudStorage/GoogleDrive-mattaabar@gmail.com/My Drive/Obsidian/2brain"
ls "$VAULT/10_PROJECTS/Active/" 2>/dev/null
ls "$VAULT/40_ARCHIVE/Projects/" 2>/dev/null
grep -rl "TOPIC_KEYWORDS" "$VAULT/10_PROJECTS/" "$VAULT/30_RESOURCES/" 2>/dev/null
```

If prior research exists, update it rather than creating a duplicate.

### 2. Copy from template

```bash
VAULT="/Users/mattabar/Library/CloudStorage/GoogleDrive-mattaabar@gmail.com/My Drive/Obsidian/2brain"
TEMPLATE="$VAULT/10_PROJECTS/_Templates/Research Project Template"
PROJECT="$VAULT/10_PROJECTS/Active/PROJECT_NAME"

cp -R "$TEMPLATE" "$PROJECT"
```

### 3. Initialize AGENTS.md

Replace placeholders with:
- Project name
- Today's date as start date
- Research questions (what are we trying to answer?)
- Success criteria (how do we know we're done?)

### 4. Add project link to To Do (PARA).md

Call `personal-todos` to add:
```
- [ ] [[10_PROJECTS/Active/PROJECT_NAME/Tasks|PROJECT_NAME]] 📅 YYYY-MM-DD
```

## During Research

### Update Research.md in real time

Every finding goes into Research.md immediately — don't batch updates.

```python
vault = "/Users/mattabar/Library/CloudStorage/GoogleDrive-mattaabar@gmail.com/My Drive/Obsidian/2brain"
filepath = f"{vault}/10_PROJECTS/Active/PROJECT_NAME/Research.md"

with open(filepath, 'r') as f:
    content = f.read()

# Append new findings with timestamp
import datetime
now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
new_section = f"\n\n## {now} — FINDING_TITLE\n\nFINDINGS_HERE\n"
content += new_section

with open(filepath, 'w') as f:
    f.write(content)
```

### Update Tasks.md as steps complete

Mark checklist items done the moment they're done. Don't wait.

### Add sources to _Sources/

For each source used, create a file in `_Sources/`:

```markdown
# Source: [Title]

**Source:** https://full-url-here
**Accessed:** YYYY-MM-DD
**Credibility:** High/Medium/Low
**Key takeaway:** One-line summary
```

### Create literature notes in _Notes/

For important sources, create a note in `_Notes/`:

```markdown
# [Source Title]

**Source:** [Full URL](https://full-url-here)
**Date:** YYYY-MM-DD

## Key Points
- Point 1
- Point 2

## Relevance to Research Questions
- How this connects to what we're investigating

## Quotes / Data
- Specific facts or figures worth preserving
```

## Hyperlink Everything

All research output MUST include clickable hyperlinks to sources:

- `_Sources` files: `**Source:** https://full-url` (not bare domain names)
- `Research.md`: inline links like `[Source Name](https://url)`
- `Decision.md`: cite sources for the final recommendation
- `_Notes`: always link back to original source

## Complete a Research Project

1. Fill "Lessons Learned" in Decision.md
2. Extract reusable knowledge to `30_RESOURCES/[category]/[topic].md`
3. Mark extraction checkbox in Decision.md
4. Mark project link complete in `To Do (PARA).md` via `personal-todos`
5. Move project: `mv "$VAULT/10_PROJECTS/Active/PROJECT" "$VAULT/40_ARCHIVE/Projects/"`

## Reading & Writing

### Read
```bash
VAULT="/Users/mattabar/Library/CloudStorage/GoogleDrive-mattaabar@gmail.com/My Drive/Obsidian/2brain"
cat "$VAULT/10_PROJECTS/Active/PROJECT_NAME/Research.md"
```

### Write (Python preferred for Google Drive)
```python
vault = "/Users/mattabar/Library/CloudStorage/GoogleDrive-mattaabar@gmail.com/My Drive/Obsidian/2brain"
filepath = f"{vault}/10_PROJECTS/Active/PROJECT_NAME/FILE.md"
with open(filepath, 'r') as f:
    content = f.read()
# ... modify ...
with open(filepath, 'w') as f:
    f.write(content)
```

## Handoff Rules

| Situation | This skill? | Or defer to... |
|---|---|---|
| Create research project | ✅ Yes | — |
| Update findings during research | ✅ Yes | — |
| Add source / literature note | ✅ Yes | — |
| Complete & archive research | ✅ Yes | — |
| Add project link to todos | ❌ | `personal-todos` |
| PARA classification questions | ❌ | `para-second-brain` |
| Weekly/monthly reviews | ❌ | `para-second-brain` |
| Simple task add/complete | ❌ | `personal-todos` |
