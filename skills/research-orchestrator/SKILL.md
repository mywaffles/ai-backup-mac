---
name: research-orchestrator
description: >
  Master controller for all research tasks. Use this skill EVERY TIME research
  is conducted — whether deep investigation, comparison shopping, multi-source
  analysis, or any web research. Decides which research skill(s) to invoke,
  creates and maintains research projects in Matt's Obsidian 2brain vault, and
  coordinates the full lifecycle (plan → research → track → complete → archive).
  Triggers on: "research X", "compare X vs Y", "find the best X", "deep research",
  "investigate", "track this research", "save to Obsidian", "create a research
  project", or "where did I research X?". For PARA classification and weekly
  reviews, defer to para-second-brain. For simple task management, defer to
  personal-todos. All commands run on Matt's Mac Mini via shell:run_command.
---

# Research Orchestrator

Master controller for all research. Picks the right skill(s), creates an
Obsidian project, and tracks everything from start to archive.

---

## Step 1: Pick the Right Research Skill

Before doing any research, choose the appropriate tool:

| Situation | Skill to use |
|---|---|
| Complex, multi-source investigation (10+ sources, decisions, reports) | `deep-research` |
| Standard web research with citations | `research` |
| Extracting clean content from a specific URL | `defuddle` |
| Paywalled or login-gated content | `playwright-cli` |
| Simple single-source lookup | WebSearch (no skill needed) |

**Decision tree:**

```
Is this a one-search answer? → Just use WebSearch, no project needed
Is this multi-source / comparative / decision-making? → CONTINUE

Need McKinsey HTML + PDF output? → deep-research (ultradeep mode)
Need citations but lighter weight? → research
Specific URL to read? → defuddle first, then research/deep-research
Login-gated site? → playwright-cli to extract, then synthesize
```

**Combining skills:** It's common to chain them. Example:
1. `playwright-cli` to extract paywalled content → save to temp file
2. `deep-research` to synthesize across sources including that file
3. This skill to track everything in Obsidian

---

## Step 2: Create an Obsidian Research Project

**Core rule:** If Claude is doing multi-source research, it tracks the work
in Obsidian. No substantive research should happen without a project.

### Vault Location

```
VAULT="/Users/mattabar/Library/CloudStorage/GoogleDrive-mattaabar@gmail.com/My Drive/Obsidian/2brain"
```

> **Critical:** Always use the full `/Users/mattabar/...` path. Never `~` or `$HOME`.

### Check for existing research first

```bash
VAULT="/Users/mattabar/Library/CloudStorage/GoogleDrive-mattaabar@gmail.com/My Drive/Obsidian/2brain"
ls "$VAULT/10_PROJECTS/Active/" 2>/dev/null
ls "$VAULT/40_ARCHIVE/Projects/" 2>/dev/null
grep -rl "TOPIC_KEYWORDS" "$VAULT/10_PROJECTS/" "$VAULT/30_RESOURCES/" 2>/dev/null
```

If prior research exists, update it rather than creating a duplicate.

### Project structure

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

### Create from template

```bash
VAULT="/Users/mattabar/Library/CloudStorage/GoogleDrive-mattaabar@gmail.com/My Drive/Obsidian/2brain"
TEMPLATE="$VAULT/10_PROJECTS/_Templates/Research Project Template"
PROJECT="$VAULT/10_PROJECTS/Active/PROJECT_NAME"

cp -R "$TEMPLATE" "$PROJECT"
```

### Initialize AGENTS.md

Replace placeholders with:
- Project name
- Today's date as start date
- Research questions (what are we trying to answer?)
- Success criteria (how do we know we're done?)

### Add project link to todos

Call `personal-todos` to add:
```
- [ ] [[10_PROJECTS/Active/PROJECT_NAME/Tasks|PROJECT_NAME]] 📅 YYYY-MM-DD
```

---

## Step 3: Track During Research

### Update Research.md in real time

Every finding goes into Research.md immediately — don't batch updates.

```python
vault = "/Users/mattabar/Library/CloudStorage/GoogleDrive-mattaabar@gmail.com/My Drive/Obsidian/2brain"
filepath = f"{vault}/10_PROJECTS/Active/PROJECT_NAME/Research.md"

with open(filepath, 'r') as f:
    content = f.read()

import datetime
now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
new_section = f"\n\n## {now} — FINDING_TITLE\n\nFINDINGS_HERE\n"
content += new_section

with open(filepath, 'w') as f:
    f.write(content)
```

### Update Tasks.md as steps complete

Mark checklist items done the moment they're done.

### Add sources to _Sources/

```markdown
# Source: [Title]

**Source:** https://full-url-here
**Accessed:** YYYY-MM-DD
**Credibility:** High/Medium/Low
**Key takeaway:** One-line summary
```

### Create literature notes in _Notes/

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

### Hyperlink everything

All research output MUST include clickable hyperlinks to sources:
- `_Sources` files: `**Source:** https://full-url` (not bare domain names)
- `Research.md`: inline links like `[Source Name](https://url)`
- `Decision.md`: cite sources for the final recommendation
- `_Notes`: always link back to original source

---

## Step 4: Complete & Archive

1. Fill "Lessons Learned" in Decision.md
2. Extract reusable knowledge to `30_RESOURCES/[category]/[topic].md`
3. Mark extraction checkbox in Decision.md
4. Mark project link complete in `To Do (PARA).md` via `personal-todos`
5. Move project:
   ```bash
   VAULT="/Users/mattabar/Library/CloudStorage/GoogleDrive-mattaabar@gmail.com/My Drive/Obsidian/2brain"
   mv "$VAULT/10_PROJECTS/Active/PROJECT" "$VAULT/40_ARCHIVE/Projects/"
   ```

---

## Reading & Writing Vault Files

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

---

## Handoff Rules

| Situation | This skill? | Or defer to... |
|---|---|---|
| Decide which research skill to invoke | ✅ Yes | — |
| Create / update research project in Obsidian | ✅ Yes | — |
| Add source / literature note | ✅ Yes | — |
| Complete & archive research | ✅ Yes | — |
| Conduct the actual research | ❌ | `deep-research` or `research` |
| Extract URL content | ❌ | `defuddle` |
| Access paywalled / login-gated content | ❌ | `playwright-cli` |
| Add project link to todos | ❌ | `personal-todos` |
| PARA classification questions | ❌ | `para-second-brain` |
| Weekly/monthly reviews | ❌ | `para-second-brain` |
