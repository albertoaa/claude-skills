---
description: Review code changes for bugs, style issues, and improvements
argument-hint: <low|medium|high>
allowed-tools:
  - Bash(git diff:*)
  - Bash(git log:*)
  - Bash(git show:*)
  - Read
---

## Your task

Review the current code changes (staged and unstaged) for correctness, style, and potential improvements.

The user may specify a review depth as an argument:
- **low**: Only flag clear bugs and security issues
- **medium** (default): Bugs, security, plus style and readability concerns
- **high**: Comprehensive review including architecture, naming, test coverage gaps, and simplification opportunities

### Steps

1. Run `git diff` to see unstaged changes and `git diff --cached` to see staged changes. If both are empty, run `git diff HEAD~1` to review the last commit.
2. For each file changed, read enough surrounding context to understand the change.
3. Organize findings by severity:
   - **Bug**: Incorrect logic, missing error handling, security vulnerabilities
   - **Style**: Naming, formatting, idiomatic usage
   - **Suggestion**: Simplification, performance, readability improvements
4. For each finding, reference the file and line, explain the issue, and suggest a fix.
5. End with a short summary: number of findings by severity and overall assessment.

### Guidelines

- Be specific — quote the problematic code.
- Don't flag things that are purely a matter of taste unless at high depth.
- If the code looks good, say so briefly rather than inventing issues.
- Consider the broader codebase context when evaluating naming and patterns.
