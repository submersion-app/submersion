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
```

## Architecture

### Directory Structure
```
lib/
├── main.dart                 # Entry point
├── app.dart                  # Root app widget with ProviderScope
├── core/
│   ├── constants/
│   │   ├── enums.dart        # DiveType, GearType, Visibility, etc.
│   │   └── units.dart        # Measurement unit helpers
│   ├── database/
│   │   ├── database.dart     # Drift table definitions
│   │   └── database.g.dart   # Generated Drift code
│   ├── router/
│   │   └── app_router.dart   # go_router configuration
│   ├── services/
│   │   └── database_service.dart  # Singleton database accessor
│   └── theme/
│       ├── app_theme.dart    # Light/dark theme definitions
│       └── app_colors.dart   # Color palette
├── features/
│   ├── dive_log/             # Dive logging feature
│   │   ├── data/repositories/dive_repository_impl.dart
│   │   ├── domain/entities/dive.dart
│   │   └── presentation/
│   │       ├── pages/        # DiveListPage, DiveDetailPage, DiveEditPage
│   │       └── providers/dive_providers.dart
│   ├── dive_sites/           # Dive site management
│   ├── gear/                 # Gear tracking
│   ├── marine_life/          # Species and sightings
│   ├── settings/             # App settings
│   └── statistics/           # Dive statistics
└── shared/
    └── widgets/main_scaffold.dart  # Shell navigation scaffold
```

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

## Current Status

**MVP Complete** - Core dive logging, sites, equipment, marine life, statistics, import/export

**v1.0 In Progress** - Buddy system, certifications, service records, dive centers

See [FEATURE_ROADMAP.md](FEATURE_ROADMAP.md) for complete feature status.

## Known Issues / Technical Debt

1. **Import Conflicts:** Domain entities use `as domain` alias to avoid conflicts with Drift-generated classes. This is intentional.

2. **Flutter Visibility Conflict:** In `dive_edit_page.dart`, Flutter's `Visibility` widget conflicts with the app's `Visibility` enum. Fixed with `hide Visibility` on the material import.

3. **Deprecation Warning:** `withOpacity()` is deprecated. Consider migrating to `Color.withValues()` in theme files.

4. **Missing Error Handling:** Repository methods don't have comprehensive error handling/logging.

5. **N+1 Query Issue:** `_mapRowToDive` makes individual queries for tanks, profile, and site per dive. Consider optimizing with joins for list views.

## Code Conventions

- **Imports:** Group by: dart, flutter, packages, local (relative)
- **File naming:** snake_case for files, PascalCase for classes
- **Provider naming:** `<noun>Provider` for data, `<noun>NotifierProvider` for mutable state
- **Entity copyWith:** All domain entities should have `copyWith` method
- **Null safety:** Project uses sound null safety

## Useful Commands

```bash
# Watch mode for code generation
dart run build_runner watch

# Clean rebuild
flutter clean && flutter pub get && dart run build_runner build --delete-conflicting-outputs

# Run specific platform
flutter run -d macos
flutter run -d chrome  # Web
flutter run -d ios

# Analyze code
flutter analyze

# Format code
dart format lib/
```
