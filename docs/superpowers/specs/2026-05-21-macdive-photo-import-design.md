# MacDive Photo Import (Reference-In-Place) — Design

**Date:** 2026-05-21
**Status:** Approved (design); pending implementation plan
**Supersedes:** the storage approach of the deferred branch `feature/macdive-photos` / PR #257 ("Add MacDive photo import", closed unmerged 2026-04-26)
**Related:** [2026-04-21-macdive-import-design.md](2026-04-21-macdive-import-design.md) (MacDive import), [2026-04-25-media-source-extension-design.md](2026-04-25-media-source-extension-design.md) (local media / MediaItem subsystem)

## Context & Motivation

MacDive photo import was built once (PR #257, 13-task plan in
[../plans/2026-04-21-macdive-photo-import.md](../plans/2026-04-21-macdive-photo-import.md))
and **deferred** because, at the time, the app had no local photo-linking
pipeline — imported photos had nowhere durable to live. PR #257 worked around
this with its own `ImportedPhotoStorage` that **copied** photo bytes into an
app-managed directory.

Since then, the **Media Source Extension** (Phases 1–3, merged) added a
first-class local media pipeline: the `MediaItem` model with a `localFile`
source type that **references files in place** (desktop `localPath`, iOS/macOS
security-scoped bookmark, Android content URI) rather than copying bytes, plus
orphan detection and a re-verification scan.

This makes #257's copy-based storage layer redundant and inconsistent. This
design revives the **reusable** parts of #257 (format extraction, path
resolver, dive identity mapping) and rebuilds the storage/linking layer on top
of the current media pipeline.

## Goals

- Import photos referenced by MacDive **native XML** (`<photos><photo>`) and
  **SQLite** (`ZDIVEIMAGE`) exports — the only two MacDive formats that embed
  photo references.
- Link imported photos to dives as standard `localFile` `MediaItem`s, so they
  behave identically to photos added via the Files tab (orphan detection,
  "Show in Finder", sync).
- Work on **desktop and mobile** via a unified "pick a folder, app scans it"
  flow.

## Non-Goals

- **UDDF and CSV photo import.** MacDive's UDDF exporter omits photo paths and
  CSV is tabular; neither carries photo references. Out of scope.
- **Copying photo bytes into app storage.** We reference in place. Fragile
  references (e.g. into MacDive's sandbox container) degrade to orphans handled
  by the existing media tooling.
- **Cross-session pending photos.** Photo intentions are session-only
  (in-memory); no new database table. Re-trying means "pick another folder
  before closing the wizard."
- **Video import.** Photos only; non-image references are skipped and counted
  (matches the media subsystem's current video-gated stance).

## Decisions (locked)

| Decision | Choice | Rationale |
|---|---|---|
| Formats | native XML + SQLite | Only formats embedding photo refs |
| Storage | Reference in place (`localFile` MediaItem) | Consistency with media subsystem; no byte copy; orphan tooling handles fragility |
| Platforms | Desktop + mobile | Explicit product choice |
| Mobile access | Pick a folder, app scans it | Unified UX; platform-specific tree enumeration underneath |
| Integration | Approach B — import dives, then post-import prompt | Avoids the wizard-step state bugs that stalled #257 |
| Pending refs | Session-only (in-memory) | YAGNI; no schema/migration |
| Dive targeting | Imported **and** matched-existing dives | High value, low risk given idempotent-by-basename linking |

## Architecture & Data Flow

Three phases. Parse and Import reuse #257's extraction and the existing import
wizard unchanged; Post-Import is new.

```
PARSE  (XML / SQLite — reuses #257 extraction logic)
  reader extracts photo elements   XML: <photos><photo>   SQLite: ZDIVEIMAGE rows
        -> ImportImageRef { originalPath, caption?, diveSourceUuid, position }
        -> ImportPayload.imageRefs : List<ImportImageRef>

IMPORT  (existing wizard — UNCHANGED)
  dives written; result exposes sourceUuid -> diveId (new + matched-existing)
  imageRefs + the sourceUuid->diveId map are held in wizard result state (in memory)

POST-IMPORT  (new — Approach B, session-only)
  done screen: "N dives reference photos - locate them?"  -> [Skip] (refs dropped on close)
        -> user picks a folder (platform-specific grant)
        -> DirectoryScanner enumerates folder (desktop dart:io / iOS scoped dir / Android SAF tree)
        -> PhotoResolver: direct -> rebase -> filename-index  => resolved file per ref
        -> LocalMediaLinker -> MediaRepository.createMedia(localFile MediaItem, diveId)
           (dedupe by diveId+basename)
        -> summary: "47 of 52 linked - 5 not found"
  RE-TRY (same session): pick another folder; idempotent linking makes re-runs safe
```

The seam between dive import and photo linking is the in-memory pair
(`imageRefs`, `sourceUuid->diveId`) carried in the wizard's result state. Parsing
produces photo *intentions*; import resolves dive identity; the post-import
controller drains the intentions against a user-picked folder.

## Components

### Salvaged from #257 (ported onto current `main`)

| Unit | Responsibility | Interface / shape |
|---|---|---|
| `ImportImageRef` | Value type for one photo intention | `{ originalPath, caption?, diveSourceUuid, position }` |
| `ImportPayload.imageRefs` | Additive field carrying refs out of parse | `List<ImportImageRef>` |
| XML/SQLite extraction | Read photo elements into refs | `MacDiveXmlReader` (`<photos>`), `MacDiveDbReader` (`ZDIVEIMAGE` -> `MacDiveRawDiveImage`), `MacDiveDiveMapper` (rows -> `ImportImageRef`); parsers emit `imageRefs` |
| `PhotoResolver` | Translate recorded paths -> actual files via direct -> rebase -> filename-index; single scan per run | `resolveAll(refs, scanner) -> List<ResolvedRef>` (path/handle only, no bytes) |

### New

| Unit | Responsibility | Interface / deps |
|---|---|---|
| `DirectoryScanner` | Platform abstraction enumerating a user-granted folder, yielding referenceable handles | `Stream<ScannedFile> scan(GrantedFolder)`; `ScannedFile { basename, MediaHandle }` |
| `LocalMediaLinker` | **Extracted** from `FilesTabNotifier._persistOne`: `(diveId, handle, exif)` -> `localFile` `MediaItem` | wraps `MediaRepository.createMedia` + `LocalMediaPlatform` / `LocalBookmarkStorage` |
| `ImportPhotoLinkController` | Holds in-memory `imageRefs` + `sourceUuid->diveId`; on folder pick drives scanner -> resolver -> linker; emits progress + summary | Riverpod notifier; deps: resolver, linker, scanner factory |
| Post-import prompt UI | Done-screen prompt -> folder pick -> summary; "try another folder" within session | widget reading the controller |
| `UddfEntityImportResult.sourceUuidToDiveId` | Expose the mapping the linker needs (as #257 did) | add `Map<String,String>` |

`LocalMediaLinker` is the load-bearing unit: it is an **extraction** of the
existing `localFile` persistence (currently buried in the presentation-layer
`FilesTabNotifier._persistOne`), so imported photos and Files-tab photos share
one persistence path and cannot drift.

## Platform Abstraction: `DirectoryScanner`

The highest-risk new work; the abstraction is small but implementations diverge.

```
abstract class DirectoryScanner {
  /// Enumerate the user-granted folder recursively, yielding each file's
  /// basename plus a handle LocalMediaLinker can persist as-is.
  Stream<ScannedFile> scan(GrantedFolder folder);
}
class ScannedFile { final String basename; final MediaHandle handle; }
// MediaHandle = desktop path | iOS bookmark key | Android document URI
```

| Platform | Folder grant | Enumeration | Per-file handle |
|---|---|---|---|
| Desktop (Win/Linux/macOS) | `getDirectoryPath()` | `dart:io` `Directory.list(recursive:true)` | absolute path -> `localPath` |
| iOS | `UIDocumentPicker` (folder mode) -> scoped dir URL | **new channel method** `enumerateScopedDirectory` via `FileManager` | security-scoped bookmark per file -> keychain -> `bookmarkRef` |
| Android | `ACTION_OPEN_DOCUMENT_TREE` -> persisted tree URI | **new channel method** `enumerateTree` via `DocumentsContract` | per-file document URI -> `bookmarkRef` |

Mobile work **extends the existing `LocalMediaPlatform` channel** (already owns
`createBookmark` / `takePersistableUri`) with the two enumeration methods. No
new plugin.

**iOS/macOS scope-lifetime rule (correctness-critical):** per-file
security-scoped bookmarks must be created **while the directory's scope is held**
(inside the same `startAccessingSecurityScopedResource` / `stopAccessing` window
as the enumeration). Therefore `scan()` produces the referenceable handle
*during* the walk — this is why `ScannedFile` carries a `handle`, not just a
name. Android's persisted tree permission is more forgiving but follows the
analogous pattern.

**Performance:** `scan()` enumerates once; the resolver builds its filename
index from that single stream and reuses it across all refs (the lazy-index fix
#257 landed under review). MacDive containers can hold thousands of files; we
never re-walk.

## Resolver behavior by platform

- **Direct-path** strategy resolves only on desktop (recorded paths are from the
  Mac that wrote the export). On mobile it effectively never matches.
- **Rebase** (recorded path tail grafted onto the picked root) and
  **filename-index** (match by basename) work on all platforms via the scanner.
  Mobile relies on these two.

## Error Handling & Edge Cases

All best-effort; the already-completed dive import is never compromised.

| Situation | Behavior |
|---|---|
| Folder pick cancelled | No-op; dives stay imported; prompt remains dismissible |
| Scope/permission failure | Clear error, abort scan gracefully, allow retry |
| Per-file read error mid-enumeration | Skip file, continue |
| Photo not found | Count "not found", leave unlinked, show in summary |
| Per-photo link failure | Isolate; bump counter; loop continues |

- **Idempotent retry:** linking dedupes by `(diveId + basename)`; re-picking a
  folder never double-links. This same invariant makes linking to
  matched-existing dives safe against re-imports.
- **Video refs:** photos only; non-image extensions skipped and counted.
- **Captions:** stored directly on the existing `MediaItem.caption` column.
- **EXIF:** copy lat/long/takenAt/dimensions like the Files tab; on failure fall
  back to file mtime / dive date.

## Dive Targeting

Photos link to whichever dive their `diveSourceUuid` resolves to — whether
**newly created** in this import or **matched as an existing duplicate**. The
import result exposes `sourceUuidToDiveId` covering both; `getSourceUuidByDiveId`
backs the matched-existing case. Idempotent-by-basename linking keeps re-imports
safe.

## Testing Strategy (TDD throughout)

- **Unit:** `ImportImageRef`; XML/SQLite extraction (synthetic fixtures);
  `PhotoResolver` strategies + single-scan against a fake `DirectoryScanner`;
  `LocalMediaLinker` (mock `MediaRepository` + `LocalMediaPlatform`);
  `ImportPhotoLinkController` orchestration (mapping, per-photo isolation,
  dedupe-on-retry, summary counts).
- **`DirectoryScanner`:** desktop impl against a real temp dir; iOS/Android Dart
  wrappers against a mock channel (native Swift/Kotlin verified manually — the
  channel bridge is the one coverage-ignore candidate).
- **Widget:** post-import prompt — prompt / in-progress / summary states;
  folder-pick drives the controller.
- **Gated real-sample:** port #257's real MacDive SQLite test (261 imageRefs) +
  a fixture photo folder asserting resolve/link counts.

## Future Work (explicitly deferred)

- Cross-session pending photos (a `pending_import_photos` table) for
  "import now, locate photos next week".
- Generic photo attach for non-photo-carrying formats (UDDF/CSV) via
  timestamp/filename matching.
- Video import once the media subsystem ungates video.

## References

- Deferred branch `feature/macdive-photos` (PR #257, closed unmerged) — reusable
  commits: `ImportImageRef`/payload field, `PhotoResolver`, XML/SQLite
  extraction, `sourceUuidToDiveId`, `PhotoLinkingStep` (UI ideas only).
- Current media pipeline: `lib/features/media/presentation/providers/files_tab_providers.dart`
  (`_persistOne`), `lib/features/media/data/repositories/media_repository.dart`,
  `lib/features/media/data/services/local_media_platform.dart`,
  `lib/features/media/domain/entities/media_item.dart`.
- Import pipeline: `lib/features/universal_import/`,
  `lib/features/import_wizard/data/adapters/universal_adapter.dart`,
  `lib/features/dive_import/data/services/uddf_entity_importer.dart`.
