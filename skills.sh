#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"

PROJECT_ROOT="$(pwd)"
COMMANDS_DIR="$PROJECT_ROOT/.claude/commands"
SKILLS_JSON="$PROJECT_ROOT/.claude/skills.json"

usage() {
  echo "Usage: $0 {enable|disable|list|status|restore|catalog} [skill ...]"
  exit 1
}

read_enabled() {
  if [[ ! -f "$SKILLS_JSON" ]]; then
    return
  fi
  if command -v jq &>/dev/null; then
    jq -r '.enabled[]' "$SKILLS_JSON" 2>/dev/null || true
  else
    grep -o '"[^"]*"' "$SKILLS_JSON" | tr -d '"' | while read -r val; do
      [[ "$val" == "source" || "$val" == "enabled" ]] && continue
      # skip the source path value (contains / or .)
      [[ "$val" == */* || "$val" == *.* ]] && continue
      echo "$val"
    done
  fi
}

write_json() {
  local source="$1"
  shift
  local skills=("$@")
  mkdir -p "$(dirname "$SKILLS_JSON")"
  if command -v jq &>/dev/null; then
    if [[ ${#skills[@]} -eq 0 ]]; then
      jq -n --arg src "$source" '{source: $src, enabled: []}' > "$SKILLS_JSON"
    else
      local arr
      arr=$(printf '%s\n' "${skills[@]}" | jq -R . | jq -s .)
      jq -n --arg src "$source" --argjson enabled "$arr" \
        '{source: $src, enabled: $enabled}' > "$SKILLS_JSON"
    fi
  else
    local items=""
    for s in "${skills[@]}"; do
      [[ -n "$items" ]] && items="$items, "
      items="$items\"$s\""
    done
    printf '{\n  "source": "%s",\n  "enabled": [%s]\n}\n' "$source" "$items" > "$SKILLS_JSON"
  fi
}

extract_description() {
  local file="$1"
  local line
  line=$(grep -m1 '^description:' "$file" 2>/dev/null || echo "")
  if [[ -z "$line" ]]; then
    echo ""
    return
  fi
  local value
  value=$(echo "$line" | sed 's/^description: *//')
  # Handle YAML multiline scalars (> or |): grab the next indented line as the description
  if [[ "$value" == ">" || "$value" == "|" || "$value" == ">-" || "$value" == "|-" ]]; then
    value=$(awk '/^description:/{found=1; next} found && /^  /{gsub(/^  /,""); print; exit}' "$file")
  fi
  echo "$value"
}

relative_source() {
  python3 -c "import os.path; print(os.path.relpath('$SCRIPT_DIR', '$PROJECT_ROOT'))" 2>/dev/null \
    || echo "$SCRIPT_DIR"
}

cmd_enable() {
  [[ $# -eq 0 ]] && { echo "Usage: $0 enable <skill> [skill ...]"; exit 1; }
  mkdir -p "$COMMANDS_DIR"
  local source
  source="$(relative_source)"
  local enabled=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && enabled+=("$line")
  done < <(read_enabled)

  for skill in "$@"; do
    local src="$SKILLS_DIR/$skill.md"
    local dst="$COMMANDS_DIR/$skill.md"
    if [[ ! -f "$src" ]]; then
      echo "error: skill '$skill' not found in $SKILLS_DIR" >&2
      continue
    fi
    ln -sf "$src" "$dst"
    echo "enabled: $skill -> $dst"
    local found=0
    for e in "${enabled[@]+"${enabled[@]}"}"; do
      [[ "$e" == "$skill" ]] && found=1
    done
    [[ $found -eq 0 ]] && enabled+=("$skill")
  done

  write_json "$source" "${enabled[@]+"${enabled[@]}"}"
}

cmd_disable() {
  [[ $# -eq 0 ]] && { echo "Usage: $0 disable <skill> [skill ...]"; exit 1; }
  local source
  source="$(relative_source)"
  local enabled=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && enabled+=("$line")
  done < <(read_enabled)

  for skill in "$@"; do
    local dst="$COMMANDS_DIR/$skill.md"
    if [[ -L "$dst" ]]; then
      rm "$dst"
      echo "disabled: $skill"
    elif [[ -e "$dst" ]]; then
      echo "warning: $dst exists but is not a symlink, skipping" >&2
      continue
    else
      echo "warning: $skill was not enabled" >&2
    fi
    local new_enabled=()
    for e in "${enabled[@]+"${enabled[@]}"}"; do
      [[ "$e" != "$skill" ]] && new_enabled+=("$e")
    done
    enabled=("${new_enabled[@]+"${new_enabled[@]}"}")
  done

  write_json "$source" "${enabled[@]+"${enabled[@]}"}"
}

cmd_list() {
  echo "Available skills:"
  for f in "$SKILLS_DIR"/*.md; do
    [[ -f "$f" ]] || continue
    local name
    name="$(basename "$f" .md)"
    local desc
    desc=$(extract_description "$f")
    printf "  %-20s %s\n" "$name" "$desc"
  done
  if [[ -d "$SCRIPT_DIR/behaviors" ]]; then
    local has_behaviors=0
    for f in "$SCRIPT_DIR/behaviors"/*.md; do
      [[ -f "$f" ]] || continue
      has_behaviors=1
      break
    done
    if [[ $has_behaviors -eq 1 ]]; then
      echo ""
      echo "Available behaviors (add via @path in CLAUDE.md):"
      for f in "$SCRIPT_DIR/behaviors"/*.md; do
        [[ -f "$f" ]] || continue
        printf "  %s\n" "$(basename "$f" .md)"
      done
    fi
  fi
}

cmd_status() {
  echo "Enabled skills:"
  local enabled=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && enabled+=("$line")
  done < <(read_enabled)
  if [[ ${#enabled[@]} -eq 0 ]]; then
    echo "  (none)"
    return
  fi
  for skill in "${enabled[@]}"; do
    local dst="$COMMANDS_DIR/$skill.md"
    if [[ -L "$dst" ]]; then
      printf "  %-20s ✓ symlink ok\n" "$skill"
    else
      printf "  %-20s ✗ symlink missing\n" "$skill"
    fi
  done
}

cmd_restore() {
  if [[ ! -f "$SKILLS_JSON" ]]; then
    echo "No $SKILLS_JSON found, nothing to restore."
    exit 1
  fi
  local enabled=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && enabled+=("$line")
  done < <(read_enabled)
  if [[ ${#enabled[@]} -eq 0 ]]; then
    echo "No skills listed in $SKILLS_JSON."
    return
  fi
  mkdir -p "$COMMANDS_DIR"
  for skill in "${enabled[@]}"; do
    local src="$SKILLS_DIR/$skill.md"
    local dst="$COMMANDS_DIR/$skill.md"
    if [[ ! -f "$src" ]]; then
      echo "warning: skill '$skill' not found in library, skipping" >&2
      continue
    fi
    ln -sf "$src" "$dst"
    echo "restored: $skill -> $dst"
  done
}

cmd_catalog() {
  local catalog="$SCRIPT_DIR/CATALOG.md"
  {
    echo "<!-- Generated by: ./skills.sh catalog — do not edit manually -->"
    echo ""
    echo "# Catalog"
    echo ""
    echo "## Skills"
    echo ""
    echo "Skills are slash commands. Enable them with \`skills.sh enable <name>\`."
    echo ""
    echo "| Skill | Command | Description |"
    echo "|-------|---------|-------------|"
    for f in "$SKILLS_DIR"/*.md; do
      [[ -f "$f" ]] || continue
      local name
      name="$(basename "$f" .md)"
      local desc
      desc=$(extract_description "$f")
      echo "| $name | \`/$name\` | $desc |"
    done
    echo ""
    echo "## Behaviors"
    echo ""
    echo "Behaviors are auto-invoked via \`@path\` references in your project's \`CLAUDE.md\`."
    echo ""
    local has_behaviors=0
    if [[ -d "$SCRIPT_DIR/behaviors" ]]; then
      for f in "$SCRIPT_DIR/behaviors"/*.md; do
        [[ -f "$f" ]] || continue
        has_behaviors=1
        break
      done
    fi
    if [[ $has_behaviors -eq 1 ]]; then
      echo "| Behavior | Path | Description |"
      echo "|----------|------|-------------|"
      for f in "$SCRIPT_DIR/behaviors"/*.md; do
        [[ -f "$f" ]] || continue
        local bname
        bname="$(basename "$f" .md)"
        local bdesc
        bdesc=$(extract_description "$f")
        echo "| $bname | \`behaviors/$bname.md\` | $bdesc |"
      done
    else
      echo "| Behavior | Path | Description |"
      echo "|----------|------|-------------|"
      echo "| *(none yet)* | | |"
    fi
  } > "$catalog"
  echo "Generated $catalog"
}

[[ $# -eq 0 ]] && usage

case "$1" in
  enable)  shift; cmd_enable "$@" ;;
  disable) shift; cmd_disable "$@" ;;
  list)    cmd_list ;;
  status)  cmd_status ;;
  restore) cmd_restore ;;
  catalog) cmd_catalog ;;
  *)       usage ;;
esac
