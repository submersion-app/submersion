# Bulk File Import — Design

**Date:** 2026-07-06
**Issue:** [#501](https://github.com/submersion-app/submersion/issues/501) — "option to bulk import dive files from Garmin FIT files, UDDF, Shearwater XML, ..."
**Status:** Approved

## Problem

The universal import wizard handles exactly one file per session. A diver
migrating from another platform may hold hundreds of files — Garmin exports
one FIT file per dive — and today must run the wizard once per file. The
pipeline downstream of parsing (duplicate checking, review, persistence,
consolidation) already operates on lists of dives; what is missing is fan-in
of multiple files into one import session.

## Goals

- Import many files (2 to hundreds) in one wizard session with one review
  and one summary.
- Accept multiple files from the wizard's file picker, from global
  drag-and-drop, and (desktop only) from a recursively scanned folder pick.
- Detect duplicates across files in the batch, not just against the
  database.
- A single selected file behaves exactly as today, including the CSV
  field-mapping and two-CSV preset steps.

## Non-goals (v1)

- CSV files in a batch (they need manual field mapping; they are triaged
  out with a "needs individual import" label).
- Folder pick on iOS/Android (multi-select in the picker covers mobile;
  SAF / security-scoped folder traversal is deferred).
- Multi-file share intents / "open with".
- Parallel parsing (sequential per-file parsing is sufficient).

## Approach

**Payload-level merge.** Each file runs the existing per-file pipeline
(`FormatDetector.detect` → `_parserFor(format).parse`) to produce an
`ImportPayload`; a new `PayloadMerger` folds N payloads into one. Everything
downstream — `UniversalAdapter.buildBundle`, `ImportDuplicateChecker`,
review UI, `UddfEntityImporter`, consolidation — runs once, on one payload,
essentially unchanged. A 300-dive Shearwater `.db` already flows through
this pipeline as a single payload; bulk import makes N files look like that.

Alternatives considered and rejected:

- **Bundle-level merge** — merging N `ImportBundle`s requires per-payload
  adapter work (selections, group wiring) to run N times and then be
  reconciled; more surgery in `UniversalAdapter` for no user-visible gain.
- **Separate `BulkImportAdapter`** — maximum isolation but duplicates the
  trickiest code in the import stack (bundle building, import,
  consolidation).

## User flow

1. **Selection.** The Select File step's picker uses
   `allowMultiple: true`. On macOS/Windows/Linux a "Choose Folder…" button
   picks a directory via `getDirectoryPath` and recursively collects files
   with importable extensions (`.fit`, `.uddf`, `.xml`, `.db`, `.sqlite`,
   ...). Global drag-and-drop (`global_drop_target.dart`) accepts all
   dropped files instead of only the first; a dropped folder on desktop is
   scanned like Choose Folder. Share intent stays single-file.
2. **Triage.** With more than one file, the Confirm Source step's content is
   replaced by a file list: each file with its detected format and status.
   CSV and unrecognized files appear greyed with "import individually" /
   "unsupported" labels and are excluded without blocking the batch. With
   exactly one file the wizard routes through today's steps unchanged.
3. **Parse.** Files are parsed sequentially with per-file progress
   ("Parsing file 12 of 300…"), cancellable at file boundaries. A file that
   fails to parse is recorded and skipped; the batch continues.
4. **Review.** One merged bundle in the existing Review step. Per-dive
   duplicate actions (skip / import as new / consolidate) work as today.
   When the batch has more than one file, each dive row shows its source
   file as a subtitle.
5. **Import + summary.** One import pass, one summary, extended with a
   per-file outcome table: imported / duplicates skipped / failed to parse /
   needs individual import.

## Architecture

```
[N files] → per-file: FormatDetector.detect → _parserFor(format).parse
         → N ImportPayloads (+ per-file FileParseResult)
         → PayloadMerger.merge(List<(fileId, ImportPayload)>)   ← NEW
         → one ImportPayload → existing: buildBundle → ImportDuplicateChecker
         → Review → UddfEntityImporter → consolidation → Summary
```

### PayloadMerger (new)

`lib/features/universal_import/data/services/payload_merger.dart`

1. **Namespace IDs.** Dives reference sites and other entities through
   per-payload string IDs (`uddfId`, resolved via `siteIdMapping` in
   `UddfEntityImporter`). Every `uddfId` and reference field in file *k*'s
   maps is prefixed (`f{k}:site_1`) so IDs cannot collide across files.
2. **Fold reference entities across files.** Sites, buddies, equipment,
   tags, dive types, trips, certifications, and dive centers are deduplicated
   by normalized name (case-insensitive, trimmed). The surviving entry is
   the richest one (most non-null fields). Dive-side reference fields
   (`uddfSiteId`, `directSiteId`, buddy/equipment refs) pointing at a folded
   entity are rewritten to the survivor's namespaced ID. **Dives are never
   folded** — cross-file dive duplicates go to the duplicate checker so the
   user decides.
3. **Attribute provenance.** Each entity map gains a `_sourceFile` key
   (file display name), used by review subtitles and the per-file summary
   and ignored by the importer.

### State changes

`UniversalImportState.fileBytes` / `fileName` scalars become a
`List<PickedImportFile>` (name, detection result, parse status; bytes are
read lazily per file during the parse loop so a large folder pick does not
hold every raw buffer simultaneously). N=1 keeps the existing step routing,
including CSV's Map Fields and additional-file steps; N>1 routes
Select → Triage → Review.

## Duplicate detection

Three layers, in order:

1. **Cross-file dive duplicates (new).** After merging, an intra-batch pass
   in `ImportDuplicateChecker`: source-UUID exact match first, then
   `DiveMatcher` fuzzy scoring (threshold 0.7, with the existing time gate).
   The later of two matching in-batch dives is marked duplicate-of-in-batch
   with default action **skip**; the review UI shows it like any other
   duplicate and the user can flip it to import-as-new.
2. **Against-database duplicates (unchanged).** The existing
   `ImportDuplicateChecker.check` pass with skip / importAsNew / consolidate.
3. **Reference entities.** Cross-file folding happens in `PayloadMerger`;
   against-database matching for sites/buddies/etc. is the existing
   name-based checker, unchanged.

The intra-batch pass runs before the database pass so an in-batch duplicate
is not also double-reported against the database.

## Error handling, progress, cancellation

- Each file's detect+parse runs in its own try/catch; a corrupt file yields
  `FileParseResult.failed(name, error)` and the batch continues. The batch
  errors out only if zero files produce a usable payload.
- Parse progress reports "file X of N" through the existing wizard progress
  plumbing; import-phase progress is unchanged (already per-entity).
- The existing `ImportCancellationToken` is polled between files during
  parsing, so cancel takes effect at the next file boundary.
- Memory: parsed payloads for ~300 FIT files are comparable to one large
  Shearwater `.db` import, which the pipeline already survives; raw bytes
  are not held for the whole batch (lazy per-file reads).

## Testing

- **Unit — PayloadMerger:** ID namespacing under colliding `uddfId`s;
  folding by normalized name with richest-entry survivor; dive reference
  rewriting to the survivor; dives never folded; `_sourceFile` attribution.
- **Unit — intra-batch duplicate pass:** UUID match, fuzzy match above and
  below threshold, time gate respected, default action skip, ordering
  relative to the database pass.
- **Integration:** existing FIT/UDDF/Subsurface fixtures fed as a 3-file
  batch → merged bundle → import into an in-memory database → assert
  counts, the shared site folded once, dives linked to the folded site.
  Include one FK-ON round-trip.
- **Widget:** triage list shows formats and greys CSV; the N=1 path renders
  today's steps unchanged (regression guard).
- **Failure paths:** corrupt file mid-batch → batch completes and the
  summary lists the failure; all files fail → wizard error state.

## Key files touched

| Area | File(s) |
| --- | --- |
| Picker + parse loop + state | `lib/features/universal_import/presentation/providers/universal_import_providers.dart`, `universal_import_state.dart` |
| Merger (new) | `lib/features/universal_import/data/services/payload_merger.dart` |
| Intra-batch dedup | `lib/features/universal_import/data/services/import_duplicate_checker.dart` |
| Triage step (new widget) | `lib/features/universal_import/presentation/widgets/` |
| Drag-and-drop | `lib/shared/widgets/global_drop_target.dart` |
| Adapter / summary attribution | `lib/features/import_wizard/data/adapters/universal_adapter.dart`, summary/review widgets |
