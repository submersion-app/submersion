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
|------|---------|
| [FEATURE_ROADMAP.md](FEATURE_ROADMAP.md) | Comprehensive roadmap with all features by phase (v1.0, v1.5, v2.0, v3.0), database schemas, and dependencies |
| [.claude/CURRENT_SPRINT.md](.claude/CURRENT_SPRINT.md) | Active sprint tasks with detailed subtasks, estimates, and workflow instructions |

## Quick Start

```bash
# Install dependencies
flutter pub get

# Generate database code (required after schema changes)
dart run build_runner build --delete-conflicting-outputs

# Run on macOS
flutter run -d macos

# Run tests
flutter test

# Analyze code
flutter analyze

# Format code
dart format lib/

# Watch mode for code generation
dart run build_runner watch

# Clean rebuild
flutter clean && flutter pub get && dart run build_runner build --delete-conflicting-outputs
```

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
|-------|-------------|
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

