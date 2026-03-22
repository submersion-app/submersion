# Submersion - Development Guide

## Project Overview

Submersion is a Flutter dive logging application for scuba divers. It provides dive tracking, site management, gear tracking, and statistics visualization.

**Tech Stack:**

- Flutter 3.x with Material 3 design
- Drift ORM for SQLite database
- Riverpod for state management
- go_router for navigation
- Targets: iOS, Android, macOS, Windows, Linux

## Task Tracking

**For development tasks, use these two files:**

| File | Purpose |
| ------ | --------- |
| [FEATURE_ROADMAP.md](FEATURE_ROADMAP.md) | Comprehensive roadmap with all features by phase (v1.0, v1.5, v2.0, v3.0), database schemas, and dependencies |

## Git Worktrees

Use git worktrees for all parallel work. When reviewing or fixing PRs, each PR
should get its own worktree so multiple Claude Code sessions can run simultaneously
without interfering with each other.

Launch parallel sessions with:
```
claude -w pr-<number>
```

### Worktree initialization

After creating a new worktree, always run these steps before doing anything else:

1. `git submodule update --init --recursive` — worktrees do not inherit
   initialized submodules from the main working tree; libdivecomputer and any
   other submodules must be explicitly initialized.
2. `flutter pub get` — worktrees have their own `.dart_tool` and `build`
   directories, and the native platform channel builds (libdivecomputer) need
   their own build artifacts per worktree.

### Cleanup

Add `.claude/worktrees/` to `.gitignore`. When exiting a worktree session,
Claude Code will prompt to keep or remove the worktree if changes exist.
Periodically run `git worktree prune` to clean up stale references.

## Quick Start

```bash
# First-time setup (installs deps, configures git hooks, runs codegen)
./scripts/setup.sh

# Or manually:
flutter pub get
git config core.hooksPath hooks
dart run build_runner build --delete-conflicting-outputs
```text
## Common Commands

```bash
# Run on macOS
flutter run -d macos

# Run tests
flutter test

# Analyze code
flutter analyze

# Format code
dart format lib/ test/

# Watch mode for code generation
dart run build_runner watch

# Clean rebuild
flutter clean && flutter pub get && dart run build_runner build --delete-conflicting-outputs
```

## Git Hooks

Pre-push hooks are configured in the `hooks/` directory. They automatically run:

- `dart format --set-exit-if-changed` — ensures code is formatted
- `flutter analyze` — catches lint issues
- `flutter test` — runs unit tests

**Setup:** Run `git config core.hooksPath hooks` (or use `./scripts/setup.sh`)

**Bypass (if needed):** `git push --no-verify`

## Architecture

### Key Patterns

**Riverpod State Management:**

- `Provider` for repository singletons
- `FutureProvider` for async data fetching
- `FutureProvider.family` for parameterized queries (by ID, search query)
- `StateNotifierProvider` + `StateNotifier` for mutable state with CRUD operations

**Domain/Data Separation:**

- Domain entities in `domain/entities/` are clean Dart classes with `copyWith`
- Data layer uses Drift ORM with generated classes
- Import aliases (`as domain`) resolve naming conflicts between Drift and domain classes

**Navigation:**

- go_router with ShellRoute for persistent bottom navigation
- Routes: `/dives`, `/sites`, `/gear`, `/stats`, `/settings`
- Detail/edit pages at `/dives/:id`, `/dives/new`, etc.

## Database Schema

Tables defined in `lib/core/database/database.dart`:

| Table | Description |
| ------- | ----------- |
| `dives` | Core dive logs with date, depth, duration, etc. |
| `dive_profiles` | Time-series depth/temp data points per dive |
| `dive_tanks` | Tank info (volume, gas mix, pressures) per dive |
| `dive_sites` | Dive site locations with GPS, descriptions |
| `gear` | Equipment items with service tracking |
| `gear_service_records` | Service history per gear item |
| `marine_life_sightings` | Species spotted on dives |
| `species` | Marine life species reference data |

**Important:** The `dives` table uses `diveDateTime` (not `dateTime`) as the column name to avoid conflict with Drift's `Table.dateTime` method.

## Code Conventions

- **Imports:** Group by: dart, flutter, packages, local (relative)
- **File naming:** snake_case for files, PascalCase for classes
- **Provider naming:** `<noun>Provider` for data, `<noun>NotifierProvider` for mutable state
- **Entity copyWith:** All domain entities should have `copyWith` method
- **Null safety:** Project uses sound null safety

## Claude Specific Instructions

- Use agents proactively
- Anything displaying units should respect the active diver's unit settings
- All Dart code should pass "dart format" with no changes

## Critical Rules

### 1. Code Organization

- Many small files over few large files
- High cohesion, low coupling
- 200-400 lines typical, 800 max per file
- Organize by feature/domain, not by type

### 2. Code Style

- No emojis in code, comments, or documentation
- Immutability always - never mutate objects or arrays
- No console.log in production code
- Proper error handling with try/catch
- Input validation with Zod or similar
- "dart format ." should be run after completing any task to ensure correctly formatted code gets committed

### 3. Testing

- TDD: Write tests first
- 80% minimum coverage
- Unit tests for utilities
- Integration tests for APIs
- E2E tests for critical flows

### 4. Security

- No hardcoded secrets
- Environment variables for sensitive data
- Validate all user inputs
- Parameterized queries only
- CSRF protection enabled
