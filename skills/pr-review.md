---
name: review-pr
description: >
  ALWAYS invoke when the user asks to review code, review a PR,
  check a diff, or asks "what do you think of this code".
  Do not provide code review feedback without this skill.
---
# PR Review

## Steps

1. Read CONVENTIONS.md for project-specific patterns
2. Check the diff against these categories:
   - Naming: components PascalCase, hooks use*, utilities camelCase
   - Structure: no prop drilling past 2 levels, no barrel export cycles
   - Error handling: async operations wrapped, error boundaries present
   - Types: no `any`, no type assertions without comment explaining why
   - Performance: no unnecessary re-renders, memo only when measured
3. For each finding:
   - File and line
   - What is wrong (one sentence)
   - Suggested fix (code, not prose)
4. Severity: must fix | should fix | nit
5. If nothing found in a category, skip it. Do not pad the review.