# SSRF Slice C — Profile Events with Source Tagging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist SSRF `SP change` events into the existing `DiveProfileEvents` table with a new `source` tagging column, and expose per-sample setpoint via a `SetpointSegment` derivation helper (parallel to PR #137's `ProfileGasSegment`). This closes the SSRF setpoint gap that Slice A deliberately left open after the backout.

**Architecture:** "Persist events, derive at read." Add one schema column (`source`), one SSRF parser method (`_parseProfileEvents`), three new repo methods, a small segments-based derivation helper. `mergeEvents` rules remain unchanged; source tagging is infrastructure for future merge-rule refinement.

**Tech Stack:** Dart 3 + Flutter 3 + Drift ORM + `package:xml` + `flutter_test`.

**Spec reference:** `docs/superpowers/specs/2026-04-17-ssrf-slice-c-profile-events-design.md`

**Branch:** `feat/ssrf-slice-c` (already created from `feat/ssrf-slice-a` HEAD; Slice A is in PR #236 and its backout is on the parent chain).

---

## Pre-implementation Findings (from lightweight discovery)

- **Current Drift schema version**: `67` (see `database.dart:1325`). Slice C adds migration version **68**.
- **Existing `DiveProfileEvents` write sites**:
  - `lib/features/dive_computer/data/services/reparse_service.dart:424-438` — canonical `batch.insert(db.diveProfileEvents, DiveProfileEventsCompanion(...))` pattern. Writes events parsed from native dive-computer downloads.
  - `lib/core/services/sync/sync_data_serializer.dart:780-787` — sync-import path writes events from remote devices.
  - No writes found in `dive_repository_impl.dart` today (the Slice C repo methods are net-new).
- **SSRF parser instantiation point**: `lib/features/universal_import/presentation/providers/universal_import_providers.dart:428` (`ImportFormat.subsurfaceXml => SubsurfaceXmlParser()`).
- **Bridge from parser output to persistence**: lives in `universal_import_providers.dart` (730 lines). Task 1's formal Discovery must pin the exact method that consumes `dive['profile']`, `dive['tanks']`, and `dive['gasSwitches']` — the same spot must also consume the new `dive['events']` key.

These findings inform task paths below. **Task 1 formally verifies them** and surfaces anything that diverges.

**Commit preference:** The user authorized per-task commits for autonomous plan execution (Slice A precedent). Each task below includes a concrete `git commit` command.

**Pre-push hook note:** `dart format --set-exit-if-changed`, `flutter analyze`, and `flutter test` run on push. If `dart format` changes a file on commit, run `dart format ...` (without the flag) to apply, then re-commit.

---

## Task 1: Discovery — lock down file paths, version, write-site inventory

Pure investigation. No code changes. Produces a discovery note file that subsequent tasks reference.

**Files:**
- Create: `docs/superpowers/plans/2026-04-17-ssrf-slice-c-discovery.md` (discovery findings log)
- Read-only inspection: `lib/core/database/database.dart`, `lib/features/universal_import/presentation/providers/universal_import_providers.dart`, `lib/features/dive_computer/data/services/reparse_service.dart`, `lib/core/services/sync/sync_data_serializer.dart`

- [ ] **Step 1.1: Confirm current schema version**

Run: `grep -n "currentSchemaVersion\s*=" lib/core/database/database.dart`

Expected: a single line like `static const int currentSchemaVersion = 67;`. Record the number (N). Slice C's new migration targets version N+1.

- [ ] **Step 1.2: Locate the SSRF parser → persistence bridge**

Read `lib/features/universal_import/presentation/providers/universal_import_providers.dart` top to bottom. Identify:
- The method that invokes `parser.parse(...)` and obtains an `ImportPayload`.
- The code that iterates `payload.entitiesOf(ImportEntityType.dives)` and maps each dive map to a domain entity + persists it.
- The specific line(s) that consume `diveData['profile']`, `diveData['tanks']`, and `diveData['gasSwitches']`. Record these line numbers.

Record the method signature (name + parameters + return type) and the file path + line range where `diveData['events']` would be consumed. Task 11 uses this.

- [ ] **Step 1.3: Inventory existing DiveProfileEvents writers**

Run: `grep -rn "diveProfileEvents\|DiveProfileEvents" lib/ --include="*.dart" | grep -E "into|insert|Companion"`

For each match, record:
- File + line
- What triggers the write (native DC reparse, sync import, etc.)
- Whether the write currently has a way to know the event's source (if the caller is a native-DC reparse flow, source is `imported`; if it's a sync flow carrying events from another device, source may be anything — the remote device's source should be preserved)

- [ ] **Step 1.4: Inventory DiveProfileEvents readers**

Run: `grep -rn "diveProfileEvents\|DiveProfileEvents\|ProfileEvent" lib/ --include="*.dart" | grep -v "data/" | grep -v "domain/entities"`

Record each reader. If any pattern-matches on `ProfileEvent` exhaustively (e.g., a switch with no default), that caller will need updating once the `source` field is added.

- [ ] **Step 1.5: Write the discovery note**

Create `docs/superpowers/plans/2026-04-17-ssrf-slice-c-discovery.md` with sections:
- **Schema version**: current N, Slice C migration target N+1
- **SSRF persistence bridge**: file path, method signature, exact line numbers for parser-output consumption
- **Existing DiveProfileEvents writers**: file:line for each, with a source-field recommendation per writer
- **Existing DiveProfileEvents readers**: file:line for each, with a note whether any exhaustive match needs updating

Keep it to one page. This is a working note, not a polished doc.

- [ ] **Step 1.6: Commit the discovery note**

```bash
git add docs/superpowers/plans/2026-04-17-ssrf-slice-c-discovery.md
git commit -m "docs(slice-c): discovery findings for SSRF profile-events integration"
```

**If any finding diverges significantly from the Pre-implementation Findings in this plan (e.g., schema version is different, or the bridge is in an unexpected file), STOP and report NEEDS_CONTEXT. Subsequent tasks assume the pre-findings are correct.**

---

## Task 2: Add `EventSource` enum, `source` column, and schema migration

Three small related changes in one commit: the enum the column stores, the column itself, and the migration.

**Files:**
- Modify: `lib/core/constants/enums.dart` (add `EventSource` enum)
- Modify: `lib/core/database/database.dart` (add `source` column to `DiveProfileEvents`, bump `currentSchemaVersion`, add migration block)

- [ ] **Step 2.1: Add the `EventSource` enum**

Append at the end of `lib/core/constants/enums.dart` (after the last existing enum):

```dart
/// Provenance of a [ProfileEvent]. Used for source-aware merge rules and
/// diagnostic display.
enum EventSource {
  /// Came from outside the app: file import (SSRF, UDDF) or native DC download.
  imported,

  /// Auto-detected by in-app analysis (ascent rate, CNS, ppO2 thresholds, etc.).
  computed,

  /// User-authored in the app (bookmarks, notes).
  user,
}
```

- [ ] **Step 2.2: Add the `source` column on `DiveProfileEvents`**

Find the `DiveProfileEvents` class in `database.dart` (around line 995). Add a `source` column immediately before `createdAt`:

```dart
  TextColumn get source =>
      text().withDefault(const Constant('imported'))(); // EventSource.name
  IntColumn get createdAt => integer()();
```

- [ ] **Step 2.3: Bump schema version and add migration**

Find `static const int currentSchemaVersion = 67;` in `database.dart` (line ~1325). Change to `68`.

Find the `onUpgrade` block (near line 1439) and add a new migration branch for version 68. It must run `ALTER TABLE dive_profile_events ADD COLUMN source TEXT NOT NULL DEFAULT 'imported'`. Pattern from existing migrations:

```dart
        if (from < 68) {
          await customStatement(
            "ALTER TABLE dive_profile_events ADD COLUMN source TEXT NOT NULL DEFAULT 'imported'",
          );
        }
```

Add it at the correct ordinal position in the `from < N` chain (after the existing `from < 67` block). Exact placement must follow the pattern already in the file — read the surrounding migrations for the style.

- [ ] **Step 2.4: Run codegen**

Drift generates `DiveProfileEventsCompanion` from the table definition. Regenerate:

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
dart run build_runner build --delete-conflicting-outputs
```

Expected: completes successfully. `database.g.dart` (or equivalent generated file) updates to include `source` in `DiveProfileEventsCompanion`.

- [ ] **Step 2.5: Run analyzer to confirm compilation**

```bash
dart analyze lib/core/database/database.dart lib/core/constants/enums.dart
```

Expected: zero issues. If existing `DiveProfileEvents` writers (in `reparse_service.dart` and `sync_data_serializer.dart`) fail because they don't supply `source`, that is fine — the column's `withDefault` provides the default. But a compilation error is a sign something is wrong. Inspect before proceeding.

- [ ] **Step 2.6: Run existing tests to confirm no regression**

```bash
flutter test test/core/database/ 2>&1 | tail -30
```

Expected: all tests pass. Drift migration tests (if any) verify the new migration round-trips cleanly.

- [ ] **Step 2.7: Commit**

```bash
git add lib/core/constants/enums.dart lib/core/database/database.dart
# Also add regenerated Drift files (whatever was updated by codegen)
git add -u  # adds modified tracked files only
git status --short  # verify what you are about to commit
git commit -m "feat(db): add EventSource enum and source column on dive_profile_events"
```

**Important**: after `git status --short`, ensure you're committing only the database files + enums + generated Drift output. Do NOT commit the Slice A spec/plan/Slice C spec/Slice C discovery note if they're in the staging area.

---

## Task 3: Extend `ProfileEvent` entity with `source` field + factory defaults

Add the source field to the domain entity and set sensible defaults on the existing factory constructors.

**Files:**
- Modify: `lib/features/dive_log/domain/entities/profile_event.dart`
- Modify: `test/features/dive_log/domain/entities/profile_event_test.dart` (may or may not exist — create if missing)

- [ ] **Step 3.1: Write failing tests for factory source defaults**

Create or extend `test/features/dive_log/domain/entities/profile_event_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1);

  group('ProfileEvent source field', () {
    test('setpointChange defaults to EventSource.imported', () {
      final e = ProfileEvent.setpointChange(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        setpoint: 1.2,
        createdAt: now,
      );
      expect(e.source, EventSource.imported);
    });

    test('gasSwitch defaults to EventSource.imported', () {
      final e = ProfileEvent.gasSwitch(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        depth: 10.0,
        tankId: 't1',
        createdAt: now,
      );
      expect(e.source, EventSource.imported);
    });

    test('bookmark defaults to EventSource.user', () {
      final e = ProfileEvent.bookmark(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        createdAt: now,
      );
      expect(e.source, EventSource.user);
    });

    test('ascentRateWarning defaults to EventSource.computed', () {
      final e = ProfileEvent.ascentRateWarning(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        depth: 10.0,
        rate: 18.0,
        createdAt: now,
      );
      expect(e.source, EventSource.computed);
    });

    test('maxDepth defaults to EventSource.computed', () {
      final e = ProfileEvent.maxDepth(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        depth: 30.0,
        createdAt: now,
      );
      expect(e.source, EventSource.computed);
    });

    test('safetyStop defaults to EventSource.computed', () {
      final e = ProfileEvent.safetyStop(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        depth: 5.0,
        createdAt: now,
      );
      expect(e.source, EventSource.computed);
    });

    test('ascentStart defaults to EventSource.computed', () {
      final e = ProfileEvent.ascentStart(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        createdAt: now,
      );
      expect(e.source, EventSource.computed);
    });

    test('explicit source overrides factory default', () {
      final e = ProfileEvent.ascentRateWarning(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        depth: 10.0,
        rate: 18.0,
        createdAt: now,
        source: EventSource.imported,  // DC reported this warning
      );
      expect(e.source, EventSource.imported);
    });

    test('source is part of equality', () {
      final imported = ProfileEvent.bookmark(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        createdAt: now,
        source: EventSource.imported,
      );
      final user = ProfileEvent.bookmark(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        createdAt: now,
        // defaults to user
      );
      expect(imported == user, isFalse);
    });
  });
}
```

- [ ] **Step 3.2: Run tests to verify they fail**

```bash
flutter test test/features/dive_log/domain/entities/profile_event_test.dart --plain-name "source field"
```

Expected: FAIL. The `source` getter does not exist on `ProfileEvent` yet, and factory constructors don't accept a `source` parameter.

- [ ] **Step 3.3: Add `source` field to `ProfileEvent` constructor**

In `lib/features/dive_log/domain/entities/profile_event.dart`, add the import at the top (after existing imports):

```dart
import 'package:submersion/core/constants/enums.dart';
```

(The file already imports from this path for `ProfileEventType` and `EventSeverity`.)

Add the field declaration after the existing `tankId` field (around line 35):

```dart
  /// Provenance of this event (imported, computed, or user-authored)
  final EventSource source;
```

Update the main constructor to accept and assign `source` with a default of `EventSource.imported`:

```dart
  const ProfileEvent({
    required this.id,
    required this.diveId,
    required this.timestamp,
    required this.eventType,
    this.severity = EventSeverity.info,
    this.description,
    this.depth,
    this.value,
    this.tankId,
    this.source = EventSource.imported,
    required this.createdAt,
  });
```

- [ ] **Step 3.4: Update factory constructors with correct defaults**

For each existing factory constructor, add a `source` parameter with the correct default:

`ascentStart` factory — `source: EventSource.computed` default:
```dart
  factory ProfileEvent.ascentStart({
    required String id,
    required String diveId,
    required int timestamp,
    double? depth,
    required DateTime createdAt,
    EventSource source = EventSource.computed,
  }) {
    return ProfileEvent(
      id: id,
      diveId: diveId,
      timestamp: timestamp,
      eventType: ProfileEventType.ascentStart,
      depth: depth,
      createdAt: createdAt,
      source: source,
    );
  }
```

`safetyStop` factory — `source: EventSource.computed` default (with parameter pass-through).

`maxDepth` factory — `source: EventSource.computed` default.

`ascentRateWarning` factory — `source: EventSource.computed` default.

`gasSwitch` factory — `source: EventSource.imported` default.

`bookmark` factory — `source: EventSource.user` default.

`setpointChange` factory — `source: EventSource.imported` default.

Add `source` as a non-required parameter (with the appropriate default per factory) and pass it through to the `ProfileEvent(...)` call.

- [ ] **Step 3.5: Update `props` for equality**

Find the `props` getter (around line 266) and add `source` to the list:

```dart
  @override
  List<Object?> get props => [
    id,
    diveId,
    timestamp,
    eventType,
    severity,
    description,
    depth,
    value,
    tankId,
    source,
    createdAt,
  ];
```

- [ ] **Step 3.6: Update `copyWith` to include `source`**

In the `copyWith` method (around line 239), add `source` to the parameter list and the new instance construction:

```dart
  ProfileEvent copyWith({
    String? id,
    String? diveId,
    int? timestamp,
    ProfileEventType? eventType,
    EventSeverity? severity,
    String? description,
    double? depth,
    double? value,
    String? tankId,
    EventSource? source,
    DateTime? createdAt,
  }) {
    return ProfileEvent(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      timestamp: timestamp ?? this.timestamp,
      eventType: eventType ?? this.eventType,
      severity: severity ?? this.severity,
      description: description ?? this.description,
      depth: depth ?? this.depth,
      value: value ?? this.value,
      tankId: tankId ?? this.tankId,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }
```

- [ ] **Step 3.7: Run tests to verify they pass**

```bash
flutter test test/features/dive_log/domain/entities/profile_event_test.dart --plain-name "source field"
```

Expected: all 8 tests pass.

- [ ] **Step 3.8: Run full entity tests to verify no regression**

```bash
flutter test test/features/dive_log/domain/entities/profile_event_test.dart
```

Expected: all tests pass.

- [ ] **Step 3.9: Analyze and format**

```bash
dart analyze lib/features/dive_log/domain/entities/profile_event.dart test/features/dive_log/domain/entities/profile_event_test.dart
dart format --set-exit-if-changed lib/features/dive_log/domain/entities/profile_event.dart test/features/dive_log/domain/entities/profile_event_test.dart
```

Expected: zero issues; format exit 0.

- [ ] **Step 3.10: Commit**

```bash
git add lib/features/dive_log/domain/entities/profile_event.dart \
        test/features/dive_log/domain/entities/profile_event_test.dart
git commit -m "feat(profile-event): add source field with per-factory defaults"
```

---

## Task 4: Update `profile_event_mapper.dart` to read/write `source`

Extend the existing DB↔domain mapper to round-trip the new `source` field. `mergeEvents` stays unchanged.

**Files:**
- Modify: `lib/features/dive_log/domain/services/profile_event_mapper.dart`
- Modify: `test/features/dive_log/domain/services/profile_event_mapper_test.dart` (create if missing)

- [ ] **Step 4.1: Write the failing mapper test**

Create or extend `test/features/dive_log/domain/services/profile_event_mapper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show DiveProfileEvent;
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/services/profile_event_mapper.dart';

void main() {
  group('mapDiveProfileEventToProfileEvent source field', () {
    test('reads source=imported from DB row', () {
      final dbEvent = DiveProfileEvent(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        eventType: 'setpointChange',
        severity: 'info',
        description: null,
        depth: null,
        value: 1.2,
        tankId: null,
        source: 'imported',
        createdAt: 1700000000000,
      );
      final domain = mapDiveProfileEventToProfileEvent(dbEvent);
      expect(domain.source, EventSource.imported);
    });

    test('reads source=computed from DB row', () {
      final dbEvent = DiveProfileEvent(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        eventType: 'ascentRateWarning',
        severity: 'warning',
        description: null,
        depth: null,
        value: 18.0,
        tankId: null,
        source: 'computed',
        createdAt: 1700000000000,
      );
      final domain = mapDiveProfileEventToProfileEvent(dbEvent);
      expect(domain.source, EventSource.computed);
    });

    test('reads source=user from DB row', () {
      final dbEvent = DiveProfileEvent(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        eventType: 'bookmark',
        severity: 'info',
        description: 'interesting moment',
        depth: 20.0,
        value: null,
        tankId: null,
        source: 'user',
        createdAt: 1700000000000,
      );
      final domain = mapDiveProfileEventToProfileEvent(dbEvent);
      expect(domain.source, EventSource.user);
    });

    test('unknown source string falls back to imported', () {
      final dbEvent = DiveProfileEvent(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        eventType: 'bookmark',
        severity: 'info',
        description: null,
        depth: null,
        value: null,
        tankId: null,
        source: 'gibberish',
        createdAt: 1700000000000,
      );
      final domain = mapDiveProfileEventToProfileEvent(dbEvent);
      expect(domain.source, EventSource.imported);
    });
  });
}
```

- [ ] **Step 4.2: Run the failing test**

```bash
flutter test test/features/dive_log/domain/services/profile_event_mapper_test.dart
```

Expected: FAIL. The mapper does not yet read `source` from DB rows.

- [ ] **Step 4.3: Update the mapper**

In `lib/features/dive_log/domain/services/profile_event_mapper.dart`, update `mapDiveProfileEventToProfileEvent` to read `source`:

```dart
ProfileEvent mapDiveProfileEventToProfileEvent(DiveProfileEvent dbEvent) {
  return ProfileEvent(
    id: dbEvent.id,
    diveId: dbEvent.diveId,
    timestamp: dbEvent.timestamp,
    eventType: _parseEventType(dbEvent.eventType),
    severity: _parseSeverity(dbEvent.severity),
    description: dbEvent.description,
    depth: dbEvent.depth,
    value: dbEvent.value,
    tankId: dbEvent.tankId,
    source: _parseSource(dbEvent.source),
    createdAt: DateTime.fromMillisecondsSinceEpoch(dbEvent.createdAt),
  );
}
```

Add the new helper next to `_parseEventType` and `_parseSeverity`:

```dart
/// Parse a string source to [EventSource] enum.
///
/// Falls back to [EventSource.imported] for unknown values — this matches
/// the DB column's default and keeps pre-Slice-C rows interpretable.
EventSource _parseSource(String source) {
  for (final value in EventSource.values) {
    if (value.name == source) {
      return value;
    }
  }
  return EventSource.imported;
}
```

- [ ] **Step 4.4: Run tests to verify they pass**

```bash
flutter test test/features/dive_log/domain/services/profile_event_mapper_test.dart
```

Expected: all 4 tests pass.

- [ ] **Step 4.5: Analyze and format**

```bash
dart analyze lib/features/dive_log/domain/services/profile_event_mapper.dart test/features/dive_log/domain/services/profile_event_mapper_test.dart
dart format --set-exit-if-changed lib/features/dive_log/domain/services/profile_event_mapper.dart test/features/dive_log/domain/services/profile_event_mapper_test.dart
```

Expected: zero issues; format exit 0.

- [ ] **Step 4.6: Commit**

```bash
git add lib/features/dive_log/domain/services/profile_event_mapper.dart \
        test/features/dive_log/domain/services/profile_event_mapper_test.dart
git commit -m "feat(profile-event-mapper): round-trip source field through DB mapping"
```

---

## Task 5: Existing `DiveProfileEvents` writers — verify source handling

The new `source` column has a DB-level default of `'imported'`. Any existing writer that doesn't explicitly set `source` will land on `'imported'`, which is correct for the two known writers (`reparse_service.dart` writes native-DC events, `sync_data_serializer.dart` writes sync'd remote events that were imported somewhere).

This task makes the behavior **explicit** rather than implicit. The rationale: defaults are forgiving but hide intent; spelling the value out at the call site documents the author's model.

**Files:**
- Modify: `lib/features/dive_computer/data/services/reparse_service.dart` (around line 424-438)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (around line 780-787 — verify actual content via Discovery findings from Task 1)

- [ ] **Step 5.1: Update `reparse_service.dart` write site**

Find the `DiveProfileEventsCompanion(...)` construction inside the `batch.insert` call (around line 426). Add a `source:` line between `severity:` and `depth:` (or at whatever position reads most naturally):

```dart
          DiveProfileEventsCompanion(
            id: Value(_uuid.v4()),
            diveId: Value(diveId),
            timestamp: Value(e.timeSeconds),
            eventType: Value(eventType),
            severity: Value(_eventSeverity(eventType)),
            source: const Value('imported'),  // native DC events are imports
            depth: const Value(null),
            value: Value(
              e.data != null ? double.tryParse(e.data!['value'] ?? '') : null,
            ),
            createdAt: Value(nowMs),
          ),
```

- [ ] **Step 5.2: Update `sync_data_serializer.dart` write site**

Find the line in `sync_data_serializer.dart` where `.into(_db.diveProfileEvents).insert(...)` is called (approximately line 782 per Discovery). The existing code writes DB rows from a JSON-like map. The sync stream may already carry `source` if the sending device was on Slice C; if not, the default applies.

Check whether the existing insert passes a `Map<String, dynamic>` or a companion. Open the file and read the context around line 780-790. If it passes a map, the existing insert is:
```dart
await _db.into(_db.diveProfileEvents).insert(rowMap);
```
Drift will apply the default for missing keys automatically. No code change needed at the insert site.

However, the `_exportDiveProfileEvents` method at line 1296 must now emit the `source` field in the exported JSON so peer devices on Slice C receive it. Find the export method and update the projection to include `source`:

```dart
// Within _exportDiveProfileEvents, when building each row's JSON projection,
// add:
'source': row.source,
```

(The exact line depends on how rows are projected. Read the method and match the existing pattern.)

- [ ] **Step 5.3: Run tests for the affected services**

```bash
flutter test test/features/dive_computer/data/services/reparse_service_test.dart
flutter test test/core/services/sync/
```

Expected: all pass. If no tests exist for the specific write path, that's fine — the analyzer check in the next step catches compilation errors.

- [ ] **Step 5.4: Analyze**

```bash
dart analyze lib/features/dive_computer/data/services/reparse_service.dart lib/core/services/sync/sync_data_serializer.dart
```

Expected: zero issues.

- [ ] **Step 5.5: Format**

```bash
dart format --set-exit-if-changed lib/features/dive_computer/data/services/reparse_service.dart lib/core/services/sync/sync_data_serializer.dart
```

Expected: exit 0.

- [ ] **Step 5.6: Commit**

```bash
git add lib/features/dive_computer/data/services/reparse_service.dart \
        lib/core/services/sync/sync_data_serializer.dart
git commit -m "feat(events): explicit source='imported' on existing DiveProfileEvents writers"
```

---

## Task 6: SSRF parser — add `_parseProfileEvents` emitting `setpointChange`

TDD cycle. Add a new method to the SSRF parser that scans `<event name='SP change'>` elements and emits typed event maps. Wire it into `_parseDive` so `result['events']` is populated.

**Files:**
- Modify: `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart`
- Modify: `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`

- [ ] **Step 6.1: Write failing tests**

Add a new top-level group at the end of `main()` in the test file (after existing groups):

```dart
group('profile events - setpointChange', () {
  test('emits setpointChange from SP change event with mbar value', () async {
    final result = await parser.parse(
      xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='5:00 min'>
  <divecomputer model='Test' dctype='CCR'>
  <depth max='20.0 m' mean='10.0 m' />
  <event time='5:00 min' name='SP change' value='1200' />
  <sample time='0:30 min' depth='5.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
    );
    final dive = result.entitiesOf(ImportEntityType.dives).first;
    final events = dive['events'] as List<Map<String, dynamic>>;
    expect(events.length, 1);
    expect(events[0]['eventType'], 'setpointChange');
    expect(events[0]['timestamp'], 300); // 5:00 min = 300 seconds
    expect(events[0]['value'], 1.2);
  });

  test('emits setpointChange from SP change event with bar value', () async {
    final result = await parser.parse(
      xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='5:00 min'>
  <divecomputer model='Test' dctype='CCR'>
  <depth max='10.0 m' mean='5.0 m' />
  <event time='1:00 min' name='SP change' value='1.2' />
  <sample time='1:30 min' depth='5.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
    );
    final dive = result.entitiesOf(ImportEntityType.dives).first;
    final events = dive['events'] as List<Map<String, dynamic>>;
    expect(events.length, 1);
    expect(events[0]['value'], 1.2);
  });

  test('drops SP change events with non-positive value', () async {
    final result = await parser.parse(
      xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='5:00 min'>
  <divecomputer model='Test' dctype='CCR'>
  <depth max='10.0 m' mean='5.0 m' />
  <event time='0:00 min' name='SP change' value='0' />
  <event time='1:00 min' name='SP change' value='-100' />
  <sample time='2:00 min' depth='5.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
    );
    final dive = result.entitiesOf(ImportEntityType.dives).first;
    expect(dive.containsKey('events'), isFalse,
        reason: 'both events dropped; result has no events key');
  });

  test('emits multiple SP change events in document order', () async {
    final result = await parser.parse(
      xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test' dctype='CCR'>
  <depth max='30.0 m' mean='15.0 m' />
  <event time='0:00 min' name='SP change' value='700' />
  <event time='25:00 min' name='SP change' value='1300' />
  <sample time='0:30 min' depth='5.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
    );
    final dive = result.entitiesOf(ImportEntityType.dives).first;
    final events = dive['events'] as List<Map<String, dynamic>>;
    expect(events.length, 2);
    expect(events[0]['timestamp'], 0);
    expect(events[0]['value'], 0.7);
    expect(events[1]['timestamp'], 1500);
    expect(events[1]['value'], 1.3);
  });

  test('no events key on dive without SP change events', () async {
    final result = await parser.parse(
      xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='5:00 min'>
  <divecomputer model='Test'>
  <depth max='10.0 m' mean='5.0 m' />
  <sample time='1:00 min' depth='5.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
    );
    final dive = result.entitiesOf(ImportEntityType.dives).first;
    expect(dive.containsKey('events'), isFalse);
  });
});
```

- [ ] **Step 6.2: Run tests to verify they fail**

```bash
flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart --plain-name "profile events - setpointChange"
```

Expected: FAIL. All 5 tests fail because `dive['events']` key doesn't exist yet.

- [ ] **Step 6.3: Add `_parseProfileEvents` method**

In `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart`, add a new static method. Place it after `_parseGasSwitches` (or near the other event-oriented helpers):

```dart
  /// Parses `<event>` children of a `<divecomputer>` into typed profile-event
  /// maps.
  ///
  /// Currently emits only `SP change` events as `setpointChange`. Gas-change
  /// events remain handled by `_parseGasSwitches` (persisted via the distinct
  /// `GasSwitches` table). Future slices may extend this method to cover
  /// bookmarks, alarms, ceiling violations, ascent-rate warnings, etc.
  ///
  /// Setpoint value normalization: Subsurface typically emits `value` in mbar
  /// (e.g., 1200 for 1.2 bar) but some third-party exporters use bar (1.2).
  /// The `> 10` threshold is exclusive: realistic setpoints are 0.2-1.6 bar
  /// (200-1600 mbar), so 10 is unreachable in either unit.
  ///
  /// Implausible values (non-positive) and unparseable timestamps are dropped.
  static List<Map<String, dynamic>> _parseProfileEvents(
    XmlElement divecomputer,
  ) {
    final events = <Map<String, dynamic>>[];
    for (final event in divecomputer.findElements('event')) {
      final name = event.getAttribute('name')?.trim().toLowerCase();
      if (name == 'sp change') {
        final timestamp = _parseDurationSeconds(event.getAttribute('time'));
        if (timestamp == null) continue;
        final raw = _parseDouble(event.getAttribute('value'));
        if (raw == null || raw <= 0) continue;
        final bar = raw > 10 ? raw / 1000 : raw;
        events.add({
          'eventType': 'setpointChange',
          'timestamp': timestamp,
          'value': bar,
        });
      }
      // Future: add branches for bookmarks, alarms, etc. (Level 2+)
    }
    return events;
  }
```

- [ ] **Step 6.4: Wire `_parseProfileEvents` into `_parseDive`**

Find the section in `_parseDive` where `gasSwitches` is computed (around line 305-310 of the parser — use grep to locate: `grep -n "gasSwitches" lib/features/universal_import/data/parsers/subsurface_xml_parser.dart`). Just after the gas-switch assignment:

```dart
    final gasSwitches = divecomputer != null
        ? _parseGasSwitches(divecomputer)
        : const <Map<String, dynamic>>[];
    if (gasSwitches.isNotEmpty) result['gasSwitches'] = gasSwitches;
```

Add immediately after:

```dart
    final events = divecomputer != null
        ? _parseProfileEvents(divecomputer)
        : const <Map<String, dynamic>>[];
    if (events.isNotEmpty) result['events'] = events;
```

(The exact surrounding context should match the existing `gasSwitches` handling. If the style differs, match the existing style.)

- [ ] **Step 6.5: Run tests to verify they pass**

```bash
flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart --plain-name "profile events - setpointChange"
```

Expected: all 5 tests pass.

- [ ] **Step 6.6: Run full parser test file**

```bash
flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
```

Expected: all tests pass. Count should be 39 + 5 = 44 tests.

- [ ] **Step 6.7: Analyze and format**

```bash
dart analyze lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
dart format --set-exit-if-changed lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
```

Expected: zero issues; format exit 0.

- [ ] **Step 6.8: Commit**

```bash
git add lib/features/universal_import/data/parsers/subsurface_xml_parser.dart \
        test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
git commit -m "feat(ssrf-import): parse SP change events into profile-event list"
```

---

## Task 7: Repository methods for `DiveProfileEvents`

Add `insertProfileEvents`, `getProfileEventsForDive`, `deleteProfileEventsForDive` to `dive_repository_impl.dart`. Follow the pattern used by the existing `GasSwitches` methods at line ~2821-3007.

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_repository.dart` (the abstract interface, if that's where method signatures are declared — Discovery confirms)
- Modify: `test/features/dive_log/data/repositories/dive_repository_impl_test.dart` (or the relevant existing test file)

- [ ] **Step 7.1: Write failing tests for round-trip behavior**

Add a new test group to the dive repository test file. The exact file location and setup pattern must match existing tests in the repo (inspect `test/features/dive_log/data/repositories/dive_repository_impl_test.dart` for the pattern — in-memory Drift DB setup, test dive creation, etc.):

```dart
group('ProfileEvent CRUD', () {
  test('insertProfileEvents persists and getProfileEventsForDive reads', () async {
    // Setup: create a test dive first (follow existing test setup pattern).
    final dive = await _createTestDive(repo);

    final now = DateTime.utc(2026, 1, 1);
    final events = [
      ProfileEvent.setpointChange(
        id: 'e1',
        diveId: dive.id,
        timestamp: 0,
        setpoint: 0.7,
        createdAt: now,
      ),
      ProfileEvent.setpointChange(
        id: 'e2',
        diveId: dive.id,
        timestamp: 1500,
        setpoint: 1.3,
        createdAt: now,
      ),
    ];

    await repo.insertProfileEvents(events);
    final loaded = await repo.getProfileEventsForDive(dive.id);

    expect(loaded.length, 2);
    expect(loaded[0].eventType, ProfileEventType.setpointChange);
    expect(loaded[0].timestamp, 0);
    expect(loaded[0].value, 0.7);
    expect(loaded[0].source, EventSource.imported);
    expect(loaded[1].timestamp, 1500);
    expect(loaded[1].value, 1.3);
  });

  test('getProfileEventsForDive returns events ordered by timestamp', () async {
    final dive = await _createTestDive(repo);
    final now = DateTime.utc(2026, 1, 1);

    // Insert in reverse chronological order
    await repo.insertProfileEvents([
      ProfileEvent.setpointChange(
        id: 'e2', diveId: dive.id, timestamp: 1500, setpoint: 1.3, createdAt: now),
      ProfileEvent.setpointChange(
        id: 'e1', diveId: dive.id, timestamp: 0, setpoint: 0.7, createdAt: now),
    ]);

    final loaded = await repo.getProfileEventsForDive(dive.id);
    expect(loaded.map((e) => e.timestamp).toList(), [0, 1500]);
  });

  test('deleteProfileEventsForDive removes only that dive events', () async {
    final diveA = await _createTestDive(repo);
    final diveB = await _createTestDive(repo);
    final now = DateTime.utc(2026, 1, 1);

    await repo.insertProfileEvents([
      ProfileEvent.setpointChange(
        id: 'a1', diveId: diveA.id, timestamp: 0, setpoint: 1.0, createdAt: now),
      ProfileEvent.setpointChange(
        id: 'b1', diveId: diveB.id, timestamp: 0, setpoint: 1.2, createdAt: now),
    ]);

    await repo.deleteProfileEventsForDive(diveA.id);

    expect(await repo.getProfileEventsForDive(diveA.id), isEmpty);
    expect((await repo.getProfileEventsForDive(diveB.id)).length, 1);
  });

  test('inserted events default to source=imported', () async {
    final dive = await _createTestDive(repo);
    final now = DateTime.utc(2026, 1, 1);

    await repo.insertProfileEvents([
      ProfileEvent.setpointChange(
        id: 'e1', diveId: dive.id, timestamp: 0, setpoint: 1.0, createdAt: now),
    ]);

    final loaded = (await repo.getProfileEventsForDive(dive.id)).single;
    expect(loaded.source, EventSource.imported);
  });

  test('bookmark event persists with source=user', () async {
    final dive = await _createTestDive(repo);
    final now = DateTime.utc(2026, 1, 1);

    await repo.insertProfileEvents([
      ProfileEvent.bookmark(
        id: 'b1', diveId: dive.id, timestamp: 500,
        depth: 10.0, note: 'cool fish', createdAt: now),
    ]);

    final loaded = (await repo.getProfileEventsForDive(dive.id)).single;
    expect(loaded.source, EventSource.user);
    expect(loaded.description, 'cool fish');
  });
});
```

The `_createTestDive` helper must mirror whatever setup pattern already exists in the test file. If no such helper exists, look at how other tests create a dive for their test setup.

- [ ] **Step 7.2: Run tests to verify they fail**

```bash
flutter test test/features/dive_log/data/repositories/dive_repository_impl_test.dart --plain-name "ProfileEvent CRUD"
```

Expected: FAIL. `insertProfileEvents`, `getProfileEventsForDive`, `deleteProfileEventsForDive` do not exist yet on the repository.

- [ ] **Step 7.3: Add method signatures to the abstract interface**

If `dive_repository.dart` (the abstract class) exists and declares method signatures, add:

```dart
  Future<void> insertProfileEvents(List<ProfileEvent> events);
  Future<List<ProfileEvent>> getProfileEventsForDive(String diveId);
  Future<void> deleteProfileEventsForDive(String diveId);
```

The Discovery notes should confirm whether this interface file exists and where. If it does not, skip this step.

- [ ] **Step 7.4: Implement methods in `dive_repository_impl.dart`**

Follow the `GasSwitches` pattern at line ~2821-3007. Add the three methods (place them near the existing `GasSwitches` methods to keep related code together):

```dart
  @override
  Future<void> insertProfileEvents(List<ProfileEvent> events) async {
    if (events.isEmpty) return;
    await _db.transaction(() async {
      for (final event in events) {
        final id = event.id.isEmpty ? _uuid.v4() : event.id;
        await _db.into(_db.diveProfileEvents).insert(
              DiveProfileEventsCompanion(
                id: Value(id),
                diveId: Value(event.diveId),
                timestamp: Value(event.timestamp),
                eventType: Value(event.eventType.name),
                severity: Value(event.severity.name),
                description: Value(event.description),
                depth: Value(event.depth),
                value: Value(event.value),
                tankId: Value(event.tankId),
                source: Value(event.source.name),
                createdAt: Value(event.createdAt.millisecondsSinceEpoch),
              ),
            );
      }
    });
    // If the existing GasSwitches methods use an audit log / sync tracker,
    // add the equivalent calls here. Read the surrounding GasSwitches code
    // for the pattern.
  }

  @override
  Future<List<ProfileEvent>> getProfileEventsForDive(String diveId) async {
    final rows = await (_db.select(_db.diveProfileEvents)
          ..where((t) => t.diveId.equals(diveId))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
    return rows.map(mapDiveProfileEventToProfileEvent).toList();
  }

  @override
  Future<void> deleteProfileEventsForDive(String diveId) async {
    await (_db.delete(_db.diveProfileEvents)
          ..where((t) => t.diveId.equals(diveId)))
        .go();
  }
```

Required imports at the top of the file (if not already present):
- `import 'package:submersion/features/dive_log/domain/services/profile_event_mapper.dart';`
- `import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';`
- (Drift imports like `DiveProfileEventsCompanion`, `Value`, `OrderingTerm` — these are likely already imported.)

- [ ] **Step 7.5: Run tests to verify they pass**

```bash
flutter test test/features/dive_log/data/repositories/dive_repository_impl_test.dart --plain-name "ProfileEvent CRUD"
```

Expected: all 5 tests pass.

- [ ] **Step 7.6: Run full repository test file for regressions**

```bash
flutter test test/features/dive_log/data/repositories/dive_repository_impl_test.dart
```

Expected: all tests pass.

- [ ] **Step 7.7: Analyze and format**

```bash
dart analyze lib/features/dive_log/data/repositories/dive_repository_impl.dart
dart format --set-exit-if-changed lib/features/dive_log/data/repositories/dive_repository_impl.dart
```

Expected: zero issues; format exit 0.

- [ ] **Step 7.8: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart \
        test/features/dive_log/data/repositories/dive_repository_impl_test.dart
# If dive_repository.dart interface was modified:
git add lib/features/dive_log/data/repositories/dive_repository.dart 2>/dev/null || true
git commit -m "feat(dive-repo): add profile-event insert/get/delete methods"
```

---

## Task 8: Wire SSRF import pipeline to persist events

Use the Discovery findings (Task 1) to locate the exact method in `universal_import_providers.dart` that maps parsed dives to entities and persists them. Add a step that maps `diveData['events']` to `ProfileEvent` domain entities and calls `insertProfileEvents`.

**Files:**
- Modify: `lib/features/universal_import/presentation/providers/universal_import_providers.dart` (exact location per Discovery)

- [ ] **Step 8.1: Locate the persistence step**

Per Task 1 Discovery findings, open the identified method. Find where the code consumes `diveData['gasSwitches']` and maps them to domain entities / calls `insertGasSwitches` or similar. The events wiring goes alongside.

- [ ] **Step 8.2: Write failing integration test**

Create or extend `test/features/universal_import/integration/ssrf_events_persistence_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
// Additional imports follow the pattern in existing integration tests.

void main() {
  group('SSRF setpointChange event end-to-end', () {
    test('imported dive has persisted setpointChange events with source=imported',
        () async {
      // Setup: in-memory DB, pipeline wired to repo.
      // Import a minimal SSRF XML with one SP change event.
      // Load events back via getProfileEventsForDive.
      // Assert: 1 event exists, type=setpointChange, value=0.7, source=imported.
      //
      // Follow whatever existing integration-test harness is present in this repo.
      // If there's no such harness, this test may be better written as a targeted
      // provider-level test.
    });
  });
}
```

If no integration-test harness exists yet, SKIP writing an integration test and instead rely on:
1. Task 6's unit tests proving the parser emits events.
2. Task 7's repo tests proving `insertProfileEvents` works.
3. A manual smoke test in Step 8.5.

If an integration harness exists, write the test against it.

- [ ] **Step 8.3: Implement the pipeline wiring**

In the identified method, after the existing `gasSwitches` persistence, add:

```dart
    // Persist profile events (currently only setpointChange from SSRF)
    final eventMaps = (diveData['events'] as List?)?.cast<Map<String, dynamic>>();
    if (eventMaps != null && eventMaps.isNotEmpty) {
      final now = DateTime.now();
      final events = eventMaps.map((m) {
        final eventTypeStr = m['eventType'] as String;
        // Map parser-output event types to factory calls
        switch (eventTypeStr) {
          case 'setpointChange':
            return ProfileEvent.setpointChange(
              id: _uuid.v4(),
              diveId: diveId,
              timestamp: m['timestamp'] as int,
              setpoint: m['value'] as double,
              createdAt: now,
            );
          default:
            // Unknown event types are logged but not persisted
            _log.warning('Skipping unknown event type: $eventTypeStr');
            return null;
        }
      }).whereType<ProfileEvent>().toList();
      if (events.isNotEmpty) {
        await diveRepository.insertProfileEvents(events);
      }
    }
```

**Exact variable names (`_uuid`, `_log`, `diveRepository`, `diveId`) must match the surrounding code's existing conventions — Discovery provides them.** If the surrounding method uses a different dependency injection pattern, match that.

Required imports (add at top if not present):
- `import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';`

- [ ] **Step 8.4: Run integration or provider tests**

```bash
flutter test test/features/universal_import/ 2>&1 | tail -30
```

Expected: all tests pass.

- [ ] **Step 8.5: Manual smoke test (if available)**

If you have a real CCR `.ssrf` file with `SP change` events handy, import it via the app and inspect the resulting dive's events. Otherwise, skip this step.

- [ ] **Step 8.6: Analyze and format**

```bash
dart analyze lib/features/universal_import/presentation/providers/universal_import_providers.dart
dart format --set-exit-if-changed lib/features/universal_import/presentation/providers/universal_import_providers.dart
```

Expected: zero issues; format exit 0.

- [ ] **Step 8.7: Commit**

```bash
git add lib/features/universal_import/presentation/providers/universal_import_providers.dart
# If an integration test was added:
git add test/features/universal_import/integration/ 2>/dev/null || true
git commit -m "feat(ssrf-import): persist SP change events during dive import"
```

---

## Task 9: `SetpointSegment` + `buildSetpointSegments` + `setpointAt`

The derivation helper. Parallel to PR #137's `ProfileGasSegment` pattern. Pure function — no DB dependency. Consumers load events via `getProfileEventsForDive` then pass them through `buildSetpointSegments`.

**Files:**
- Create: `lib/features/dive_log/domain/services/setpoint_segments.dart`
- Create: `test/features/dive_log/domain/services/setpoint_segments_test.dart`

- [ ] **Step 9.1: Write failing tests**

Create `test/features/dive_log/domain/services/setpoint_segments_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/services/setpoint_segments.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1);

  ProfileEvent sp(String id, int ts, double value) =>
      ProfileEvent.setpointChange(
        id: id,
        diveId: 'd1',
        timestamp: ts,
        setpoint: value,
        createdAt: now,
      );

  group('buildSetpointSegments', () {
    test('empty events yields empty segments', () {
      expect(buildSetpointSegments([]), isEmpty);
    });

    test('single event yields one open-ended segment', () {
      final segments = buildSetpointSegments([sp('e1', 0, 0.7)]);
      expect(segments.length, 1);
      expect(segments[0].startTimestamp, 0);
      expect(segments[0].endTimestamp, isNull);
      expect(segments[0].setpoint, 0.7);
    });

    test('two events yield two segments with the first closed at the second', () {
      final segments = buildSetpointSegments([
        sp('e1', 0, 0.7),
        sp('e2', 1500, 1.3),
      ]);
      expect(segments.length, 2);
      expect(segments[0].startTimestamp, 0);
      expect(segments[0].endTimestamp, 1500);
      expect(segments[0].setpoint, 0.7);
      expect(segments[1].startTimestamp, 1500);
      expect(segments[1].endTimestamp, isNull);
      expect(segments[1].setpoint, 1.3);
    });

    test('events out of order are sorted defensively', () {
      final segments = buildSetpointSegments([
        sp('e2', 1500, 1.3),
        sp('e1', 0, 0.7),
      ]);
      expect(segments[0].startTimestamp, 0);
      expect(segments[1].startTimestamp, 1500);
    });

    test('consecutive events with same setpoint are coalesced', () {
      final segments = buildSetpointSegments([
        sp('e1', 0, 0.7),
        sp('e2', 500, 0.7),  // same value, redundant
        sp('e3', 1500, 1.3),
      ]);
      expect(segments.length, 2);
      expect(segments[0].startTimestamp, 0);
      expect(segments[0].endTimestamp, 1500);
      expect(segments[0].setpoint, 0.7);
      expect(segments[1].setpoint, 1.3);
    });

    test('non-setpointChange events are filtered out', () {
      final bookmark = ProfileEvent.bookmark(
        id: 'b1', diveId: 'd1', timestamp: 100, createdAt: now);
      final segments = buildSetpointSegments([
        sp('e1', 0, 0.7),
        bookmark,
        sp('e2', 1500, 1.3),
      ]);
      expect(segments.length, 2);
    });
  });

  group('setpointAt', () {
    test('returns null for timestamp before first segment', () {
      final segments = buildSetpointSegments([sp('e1', 500, 0.7)]);
      expect(setpointAt(segments, 100), isNull);
    });

    test('returns segment setpoint at exact segment start', () {
      final segments = buildSetpointSegments([sp('e1', 500, 0.7)]);
      expect(setpointAt(segments, 500), 0.7);
    });

    test('returns segment setpoint within segment range', () {
      final segments = buildSetpointSegments([
        sp('e1', 0, 0.7),
        sp('e2', 1500, 1.3),
      ]);
      expect(setpointAt(segments, 750), 0.7);
      expect(setpointAt(segments, 1499), 0.7);
      expect(setpointAt(segments, 1500), 1.3);
      expect(setpointAt(segments, 2000), 1.3);
    });

    test('returns last segment setpoint for timestamps past all segments (open-ended last)', () {
      final segments = buildSetpointSegments([sp('e1', 500, 1.2)]);
      expect(setpointAt(segments, 10000), 1.2);
    });

    test('empty segments returns null', () {
      expect(setpointAt(const [], 500), isNull);
    });
  });
}
```

- [ ] **Step 9.2: Run tests to verify they fail**

```bash
flutter test test/features/dive_log/domain/services/setpoint_segments_test.dart
```

Expected: FAIL. The file `setpoint_segments.dart` does not exist yet.

- [ ] **Step 9.3: Create the implementation file**

Create `lib/features/dive_log/domain/services/setpoint_segments.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';

/// A contiguous time range during which a single CCR setpoint was active.
///
/// Built from a stream of `setpointChange` events via [buildSetpointSegments].
/// [endTimestamp] is exclusive — equal to the next segment's [startTimestamp],
/// or null for the final (open-ended) segment.
class SetpointSegment extends Equatable {
  final int startTimestamp;
  final int? endTimestamp;
  final double setpoint;

  const SetpointSegment({
    required this.startTimestamp,
    required this.endTimestamp,
    required this.setpoint,
  });

  bool containsTimestamp(int t) =>
      t >= startTimestamp && (endTimestamp == null || t < endTimestamp!);

  @override
  List<Object?> get props => [startTimestamp, endTimestamp, setpoint];
}

/// Builds a list of setpoint segments from a list of profile events.
///
/// Filters to `setpointChange` events, sorts defensively by timestamp,
/// and coalesces consecutive events that repeat the same setpoint value.
///
/// Returns an empty list when the input contains no setpointChange events.
/// The final segment is open-ended ([endTimestamp] is null).
List<SetpointSegment> buildSetpointSegments(List<ProfileEvent> events) {
  final setpointEvents = events
      .where((e) =>
          e.eventType == ProfileEventType.setpointChange && e.value != null)
      .toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  if (setpointEvents.isEmpty) return const [];

  // First pass: one segment per event, bounded by the next event's timestamp.
  final raw = <SetpointSegment>[];
  for (var i = 0; i < setpointEvents.length; i++) {
    final current = setpointEvents[i];
    final nextTs =
        i + 1 < setpointEvents.length ? setpointEvents[i + 1].timestamp : null;
    raw.add(SetpointSegment(
      startTimestamp: current.timestamp,
      endTimestamp: nextTs,
      setpoint: current.value!,
    ));
  }

  // Second pass: coalesce adjacent segments with the same setpoint value.
  final coalesced = <SetpointSegment>[];
  for (final segment in raw) {
    if (coalesced.isNotEmpty && coalesced.last.setpoint == segment.setpoint) {
      final prev = coalesced.removeLast();
      coalesced.add(SetpointSegment(
        startTimestamp: prev.startTimestamp,
        endTimestamp: segment.endTimestamp,
        setpoint: prev.setpoint,
      ));
    } else {
      coalesced.add(segment);
    }
  }

  return coalesced;
}

/// Returns the active setpoint at [timestamp], or null if no segment
/// covers that time.
///
/// For timestamps earlier than the first segment's start, returns null
/// (no event has fired yet, so setpoint is undefined).
double? setpointAt(List<SetpointSegment> segments, int timestamp) {
  for (final segment in segments) {
    if (segment.containsTimestamp(timestamp)) return segment.setpoint;
  }
  return null;
}
```

- [ ] **Step 9.4: Run tests to verify they pass**

```bash
flutter test test/features/dive_log/domain/services/setpoint_segments_test.dart
```

Expected: all 11 tests pass.

- [ ] **Step 9.5: Analyze and format**

```bash
dart analyze lib/features/dive_log/domain/services/setpoint_segments.dart test/features/dive_log/domain/services/setpoint_segments_test.dart
dart format --set-exit-if-changed lib/features/dive_log/domain/services/setpoint_segments.dart test/features/dive_log/domain/services/setpoint_segments_test.dart
```

Expected: zero issues; format exit 0.

- [ ] **Step 9.6: Commit**

```bash
git add lib/features/dive_log/domain/services/setpoint_segments.dart \
        test/features/dive_log/domain/services/setpoint_segments_test.dart
git commit -m "feat(dive-log): add SetpointSegment derivation helper"
```

---

## Task 10: Update import-gap tracker for Slice C

Restore `Sample setpoint` to `[x]` and note the derivation-based architecture.

**Files:**
- Modify: `docs/superpowers/specs/2026-04-05-imported-profile-gap-priority-tracker.md`

- [ ] **Step 10.1: Update combined table row for `Sample setpoint`**

Find:

```markdown
| Sample `setpoint` | [ ] | Medium | Yes | Yes | Partial |
```

Replace with:

```markdown
| Sample `setpoint` | [x] | Medium | Yes | Yes | Yes |
```

- [ ] **Step 10.2: Update SSRF sub-table row for `Sample setpoint`**

Find the row that was updated by the Slice A backout (the one mentioning "intentionally deferred to Slice C"). Replace with:

```markdown
| Sample `setpoint` | [x] | Medium | Direct `<sample setpoint=...>` attribute is parsed into `DiveProfiles.setpoint`. `SP change` events are persisted in `DiveProfileEvents` with `source='imported'`, and `SetpointSegment` + `setpointAt(...)` derives per-sample setpoint on read, matching PR #137's `ProfileGasSegment` pattern |
```

- [ ] **Step 10.3: Update combined table row for `Profile events / markers`**

Find:

```markdown
| Profile events / markers | [ ] | Medium | Yes | No | No |
```

Replace with:

```markdown
| Profile events / markers | [ ] | Medium | Yes | Partial | Partial |
```

(Partial reflects that one event type — setpointChange — is covered end-to-end; the row stays `[ ]` because bookmarks, alarms, ceiling violations, etc., remain open.)

- [ ] **Step 10.4: Update SSRF sub-table row for `Profile events / markers`**

Find:

```markdown
| Profile events / markers | [ ] | Medium | Gas changes are imported, but bookmarks and other events are dropped |
```

Replace with:

```markdown
| Profile events / markers | [ ] | Medium | `setpointChange` events are persisted via `DiveProfileEvents` (Slice C). Bookmarks, alarms, ceiling violations, and other SSRF event types remain unmapped. A future slice should extend `_parseProfileEvents` to cover these |
```

- [ ] **Step 10.5: Add a Slice C bullet to the Notes section**

In the `## Notes` section, append this bullet at the end of the bullet list (before the existing `[^1]` footnote):

```markdown
- Slice C (2026-04-17) adds source tagging to `DiveProfileEvents` (new `source` column) and closes SSRF `SP change` event persistence via a `setpointChange` event type, consumed by a `SetpointSegment` derivation helper parallel to PR #137's `ProfileGasSegment`. Further SSRF event types (bookmarks, alarms) remain open. See `docs/superpowers/specs/2026-04-17-ssrf-slice-c-profile-events-design.md`.
```

- [ ] **Step 10.6: Visual sanity check**

Open the file and scan the tables. Column counts must still match (6 in combined, 4 in sub-tables). No dangling pipes. `[^1]` still appears exactly twice.

- [ ] **Step 10.7: Commit**

```bash
git add docs/superpowers/specs/2026-04-05-imported-profile-gap-priority-tracker.md
git commit -m "docs(tracker): restore Sample setpoint to fixed via Slice C derivation"
```

---

## Task 11: Final verification

Run all the checks the pre-push hook would run plus a broader scan.

- [ ] **Step 11.1: Run the full relevant test tree**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
flutter test test/features/dive_log/domain/entities/profile_event_test.dart
flutter test test/features/dive_log/domain/services/profile_event_mapper_test.dart
flutter test test/features/dive_log/domain/services/setpoint_segments_test.dart
flutter test test/features/dive_log/data/repositories/dive_repository_impl_test.dart
```

Expected: all pass in each file. Report counts.

- [ ] **Step 11.2: Run analyzer on touched directories**

```bash
flutter analyze lib/core/database/ lib/core/constants/ lib/features/dive_log/domain/ lib/features/dive_log/data/repositories/ lib/features/universal_import/data/parsers/ lib/features/universal_import/presentation/providers/
```

Expected: zero issues.

- [ ] **Step 11.3: Format check on all touched files**

```bash
dart format --set-exit-if-changed \
  lib/core/database/database.dart \
  lib/core/constants/enums.dart \
  lib/features/dive_log/domain/entities/profile_event.dart \
  lib/features/dive_log/domain/services/profile_event_mapper.dart \
  lib/features/dive_log/domain/services/setpoint_segments.dart \
  lib/features/dive_log/data/repositories/dive_repository_impl.dart \
  lib/features/dive_computer/data/services/reparse_service.dart \
  lib/core/services/sync/sync_data_serializer.dart \
  lib/features/universal_import/data/parsers/subsurface_xml_parser.dart \
  lib/features/universal_import/presentation/providers/universal_import_providers.dart
```

Expected: exit 0.

- [ ] **Step 11.4: Confirm clean working tree**

```bash
git status --short
```

Expected: only the untracked Slice A spec, Slice A plan, Slice C spec, and Slice C discovery note remain. No modified tracked files.

- [ ] **Step 11.5: Show commit history**

```bash
git log --oneline $(git merge-base HEAD main)..HEAD
```

Expected: all Slice C commits appear. Compare the count to the plan (roughly 10 commits).

- [ ] **Step 11.6 (optional): Manual smoke test**

If a real CCR `.ssrf` file with `SP change` events is available, import it and confirm:
- `DiveProfileEvents` table has entries with `source='imported'` and `eventType='setpointChange'`.
- `getProfileEventsForDive` returns them.
- `buildSetpointSegments` + `setpointAt` produces the expected bar values at various timestamps.

---

## Summary of Commits

After all tasks complete, the branch should have approximately these commits in order:

1. `docs(slice-c): discovery findings for SSRF profile-events integration`
2. `feat(db): add EventSource enum and source column on dive_profile_events`
3. `feat(profile-event): add source field with per-factory defaults`
4. `feat(profile-event-mapper): round-trip source field through DB mapping`
5. `feat(events): explicit source='imported' on existing DiveProfileEvents writers`
6. `feat(ssrf-import): parse SP change events into profile-event list`
7. `feat(dive-repo): add profile-event insert/get/delete methods`
8. `feat(ssrf-import): persist SP change events during dive import`
9. `feat(dive-log): add SetpointSegment derivation helper`
10. `docs(tracker): restore Sample setpoint to fixed via Slice C derivation`

Code-review fix-ups (if any from per-task review loops) add additional commits.

## Out of Scope Reminders

- UDDF parity for event types — separate slice.
- Level 2+ event types (bookmarks, alarms, ceiling violations, etc.) — separate slice.
- `mergeEvents` source-aware merge rules — separate slice, triggered once Level 2 imports create real collisions with computed events.
- Migration of downstream consumers of `DiveProfiles.setpoint` column — separate cleanup slice.
- UI display pass for imported-vs-computed event differentiation.
- Round-trip through `uddf_export_builders.dart`.
