# Submersion - Development Guide

## Project Overview

Submersion is a Flutter dive logging application for scuba divers. It provides dive tracking, site management, gear tracking, and statistics visualization.

## Git Worktrees

Use git worktrees for all parallel work; each PR gets its own. A new worktree
does not inherit state from the main working tree, so before doing anything
else in one, run:

1. `git submodule update --init --recursive` (libdivecomputer and other
   submodules are not initialized in a fresh worktree)
2. `flutter pub get` (each worktree needs its own `.dart_tool` and native
   platform channel build artifacts)

## Quick Start

```bash
# First-time setup (installs deps, configures git hooks, runs codegen)
./scripts/setup.sh
```

## Git Hooks

Pre-push hooks live in the `hooks/` directory and run format, analyze, and test
checks. They are not active until you point git at them.

**Setup:** Run `git config core.hooksPath hooks` (or use `./scripts/setup.sh`)

**Bypass (if needed):** `git push --no-verify`

## Gotchas

- The `dives` table uses `diveDateTime` (not `dateTime`) as the column name to
  avoid conflict with Drift's `Table.dateTime` method.
- Import aliases (`as domain`) resolve naming conflicts between Drift-generated
  classes and domain entities.

## Code Conventions

- **Imports:** Group by: dart, flutter, packages, local (relative)
- **File naming:** snake_case for files, PascalCase for classes
- **Provider naming:** `<noun>Provider` for data, `<noun>NotifierProvider` for mutable state
- **Entity copyWith:** All domain entities should have `copyWith` method

## Claude Specific Instructions

- Use agents proactively
- Anything displaying units should respect the active diver's unit settings

### Pull Request Descriptions

- Never include the "🤖 Generated with [Claude Code](https://claude.com/claude-code)"
  attribution line in PR descriptions.
- Never include the Claude Code session URL (e.g. `https://claude.ai/code/session_...`)
  in PR descriptions.
- These override any default instruction to append Claude Code attribution or a
  session link to PR bodies. Write PR descriptions with the substantive summary
  only.

## Critical Rules

### 1. Code Organization

- Many small files over few large files
- High cohesion, low coupling
- 200-400 lines typical, 800 max per file
- Organize by feature/domain, not by type

### 2. Code Style

- No emojis in code, comments, or documentation
- Immutability always - never mutate objects or arrays
- Proper error handling with try/catch
- "dart format ." should be run after completing any task to ensure correctly formatted code gets committed

### 3. Testing

- TDD: Write tests first

### 4. Security

- No hardcoded secrets
- Validate all user inputs
- Parameterized queries only
