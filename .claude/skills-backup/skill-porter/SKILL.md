---
name: skill-porter
description: >
  Ports skills to Claude Chat and Claude CoWork. Use this skill EVERY TIME
  a new skill is installed or discovered via Claude Code (npx skills add,
  npx skills find, or manual creation in ~/.agents/skills/). Also use when
  the user asks to "port skills", "sync skills", "update Chat skills", or
  mentions skills being out of sync between Code and Chat. This skill should
  trigger proactively — whenever a skill is installed in Claude Code,
  immediately offer to port it to Chat and CoWork without being asked.
  All commands run on the user's Mac Mini via shell:run_command.
---

# Skill Porter

Ports skills from Claude Code to Claude Chat and Claude CoWork.

## When to Use

- After installing a skill via `npx skills add`
- After creating or updating a skill in `~/.agents/skills/`
- When the user asks to sync, port, or compare skills across targets
- When listing skills and a mismatch is detected

## Installation Targets

Skills must be installed to ALL THREE targets:

| Target | Location | Method |
|---|---|---|
| Claude Code | `~/.agents/skills/<name>/` and `~/.claude/skills/<name>/` | Direct filesystem copy |
| Claude CoWork | See CoWork path below | Direct filesystem copy |
| Claude Chat | User drags `.skill` file from Desktop | Build zip → Desktop → user drags into Chat |

### CoWork Skills Path

```
/Users/mattabar/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/62dbcff6-ee02-4aba-9e73-aae776994212/bb4ddc1c-9049-44af-a88b-7ddda27785ba/skills/
```

## Porting Workflow

### Step 1: Ensure skill is in Claude Code

```bash
ls ~/.agents/skills/<skill-name>/SKILL.md
```

Also copy to the alternate Code path:
```bash
cp -R ~/.agents/skills/<skill-name> ~/.claude/skills/<skill-name>
```

### Step 2: Adapt for Chat (if needed)

1. Remove `allowed-tools:` from YAML frontmatter (Code-specific)
2. Ensure description includes "All commands run on the user's Mac Mini via shell:run_command." if the skill uses shell commands
3. Do NOT change core content, references, or scripts

### Step 3: Install to CoWork

```bash
COWORK="/Users/mattabar/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/62dbcff6-ee02-4aba-9e73-aae776994212/bb4ddc1c-9049-44af-a88b-7ddda27785ba/skills"
cp -R ~/.agents/skills/<skill-name> "$COWORK/<skill-name>"
```

### Step 4: Build .skill zip and place on Desktop

```bash
cd /tmp && rm -rf skill-port && mkdir -p skill-port/<skill-name>
cp -R ~/.agents/skills/<skill-name>/* skill-port/<skill-name>/
cd skill-port && zip -r ~/Desktop/<skill-name>.skill <skill-name>/
```

Then tell the user:
> `.skill` file is on your Desktop at `~/Desktop/<skill-name>.skill`.
> Drag it into your Claude Chat project's Skills panel to install.
> Start a new conversation for the skill to take effect.

### Step 5: Clean up after user confirms install

```bash
mv ~/Desktop/<skill-name>.skill ~/.Trash/
```

## Batch Porting

Compare installed skills across targets:

```bash
echo "=== Code ===" && ls ~/.agents/skills/
echo "=== CoWork ===" && ls "/Users/mattabar/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/62dbcff6-ee02-4aba-9e73-aae776994212/bb4ddc1c-9049-44af-a88b-7ddda27785ba/skills/"
echo "=== Chat ===" && echo "(check available_skills in session or Chat UI)"
```

Port any skills present in Code but missing from Chat or CoWork.

## Skills That Should NOT Be Ported

- **bash-loop** — Code-specific behavioral mode
- **bash-defensive-patterns** — Code-specific reference
- Skills that depend on Claude Code-only tools with no Chat/CoWork equivalent

Explain why these are skipped rather than silently ignoring them.
