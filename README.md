# claude-skills

A curated, portable library of Claude Code slash commands. Consumable as a git submodule in any project.

## Setup

Add as a submodule in your project:

```bash
git submodule add https://github.com/albertoaa/claude-skills vendor/claude-skills
git submodule update --init
```

Enable the skills you want:

```bash
./vendor/claude-skills/skills.sh enable code-review
```

This creates symlinks in `.claude/commands/` and tracks enabled skills in `.claude/skills.json`.

## Commands

```bash
./vendor/claude-skills/skills.sh enable <skill> [skill ...]   # Enable skills
./vendor/claude-skills/skills.sh disable <skill> [skill ...]  # Disable skills
./vendor/claude-skills/skills.sh list                         # List all available skills
./vendor/claude-skills/skills.sh status                       # Show which skills are enabled
./vendor/claude-skills/skills.sh restore                      # Recreate symlinks from skills.json
```

## Fresh Clone

After cloning a project that uses claude-skills:

```bash
git submodule update --init
./vendor/claude-skills/skills.sh restore
```

## Using Behaviors

Behaviors are not slash commands — they're instructions that Claude follows automatically. Reference them in your project's `CLAUDE.md`:

```
@vendor/claude-skills/behaviors/code-style.md
```

## Updating

```bash
cd vendor/claude-skills && git pull && cd -
git add vendor/claude-skills && git commit -m "update claude-skills"
```

## Available Skills

See [CATALOG.md](CATALOG.md) for the full list.
