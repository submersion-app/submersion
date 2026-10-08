# Slice C Discovery: SSRF Profile-Events Integration

**Date:** 2026-04-17
**Branch:** feat/ssrf-slice-c

---

## Schema Version

- **Current:** `currentSchemaVersion = 67` (line 1325 of `lib/core/database/database.dart`)
- **Slice C migration target:** 68

Matches plan pre-findings. No drift.

---

## SSRF Persistence Bridge

The actual per-dive persistence bridge is **not** in `universal_import_providers.dart`. That file delegates to a `UddfEntityImporter` via `importer.import(...)`. The bridge lives in:

**File:** `lib/features/dive_import/data/services/uddf_entity_importer.dart`

**Method:**
```dart
Future<_DiveImportResult> _importDives(
  List<Map<String, dynamic>> items,
  Set<int> selected,
  ImportRepositories repos,
  String diverId, {
  required Map<String, String> tripIdMapping,
  required Map<String, String> equipmentIdMapping,
  required Map<String, String> buddyIdMapping,
  required Map<String, String> diveCenterIdMapping,
  required Map<String, String> tagIdMapping,
  required Map<String, DiveSite> siteIdMapping,
  required Map<String, String> courseIdMapping,
  String? sourceFileName,
  bool retainSourceDiveNumbers = false,
  required DateTime now,
  ImportProgressCallback? onProgress,
}) async
```

**Line ranges for key payload consumption:**
| Key | Line(s) |
|-----|---------|
| `diveData['profile']` consumed (cast) | 968 |
| `diveData['tanks']` consumed (via `_buildTanks`) | 989 (called), 1280 (impl) |
| `diveData['gasSwitches']` consumed | 1188-1189 |
| `diveData['events']` **insertion point for Task 8** | after line 1227 (after gas-switch block, before buddy-link at 1229) |

The `diveId` is assigned at line 1045 and available throughout. The `repos.diveRepository` is the write target. Task 8 should insert an event-persistence block at approximately line 1228, following the same pattern as the gas-switch block above it.

**Note on universal_import_providers.dart:** The file that orchestrates the overall import is at `lib/features/universal_import/presentation/providers/universal_import_providers.dart`. The `parser.parse(...)` call is indirectly at line 428 area, but the parser instantiation and payload extraction happen inside `_parserFor(...)` (line 421) and are passed to `UddfEntityImporter.import(...)` at line 594. The `diveData['events']` key does not yet exist — Task 8 adds both the parser-side producer and the importer-side consumer.

---

## Existing DiveProfileEvents Writers

3 non-generated write sites:

| # | File : Line | What Triggers It | Has Source Field? | Recommendation |
|---|-------------|-----------------|-------------------|----------------|
| 1 | `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart:1148` | Native DC download (`importProfile`) — live download from hardware | No | `source='dc_download'` or leave null (native path, not imported) |
| 2 | `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart:1282` | Manual `addProfileEvent` — user-added events via UI | No | `source='user'` or leave null |
| 3 | `lib/features/dive_computer/data/services/reparse_service.dart:424-438` | `reparseDive` — re-running libdivecomputer parser over stored raw bytes | No | `source='dc_download'` (same provenance as #1) |
| 4 | `lib/core/services/sync/sync_data_serializer.dart:780-783` | Cloud sync inbound `insertOrUpdateRecord` | No | `source` preserved from synced JSON; no change needed at write site |

Writers 1 and 3 both originate from native DC data and should share `source='dc_download'`. Writer 2 is a user-facing operation and should use `source='user'`. Writer 4 is a passthrough — it round-trips whatever is in the JSON so it will automatically pick up the `source` field once it exists in the DB and the serializer maps it.

---

## Existing DiveProfileEvents Readers

Readers outside `data/` and `domain/entities/` (i.e., presentation/service layer):

| File : Line | Role | Exhaustive match? |
|------------|------|-------------------|
| `lib/core/constants/enums.dart:363-398` | `ProfileEventType.iconName` getter — switch over `this` | **YES — no `default`**; adding a new `ProfileEventType` value would be a compile error here. Adding a `source` field to the DB row does NOT add a new enum value, so this is safe for Slice C. |
| `lib/features/dive_log/domain/entities/profile_event.dart:79-93` | `formattedValue` getter — switch over `eventType` | Has `default`; safe. |
| `lib/features/dive_log/domain/services/profile_event_mapper.dart:10-34` | `mapDiveProfileEventToProfileEvent` + `_parseEventType` | Iterates `ProfileEventType.values`; safe. |
| `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart:32-35` | Reads DB events, maps to domain via `mapDiveProfileEventToProfileEvent` | Safe; no destructuring. |
| `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart:3061` | Chart rendering — `byTimestamp` map | No switch on type; safe. |
| `lib/features/settings/presentation/providers/export_providers.dart:383-415, 875-904` | UDDF export — reads events, maps to `ProfileEvent` domain objects | No exhaustive switch; safe. |
| `lib/core/services/export/uddf/uddf_export_builders.dart:99` | UDDF XML builder receives `List<ProfileEvent>` | No exhaustive switch; safe. |
| `lib/core/services/export/export_service.dart:254-325` | Export service passes events through | No exhaustive switch; safe. |
| `lib/core/services/sync/sync_service.dart:643-644` | Sync service exports `diveProfileEvents` table | No switch; safe. |
| `lib/core/services/sync/sync_data_serializer.dart:617-621, 945-947, 1296-1312, 1861` | Sync serializer: read, delete-check, export, JSON-map | `_diveProfileEventToJson` at line 1861 — will need updating to include `source` once column is added. |

**Action required for Slice C:** `sync_data_serializer.dart:1861` (`_diveProfileEventToJson`) needs to emit the new `source` field. No exhaustive `ProfileEventType` switch needs updating for Slice C (adding `source` is a DB column addition, not a new enum value).
