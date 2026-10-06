# Subsurface Picture Import: Design

**Status:** approved 2026-08-26
**Issue:** #1147 (split out of #153)
**Branch:** `worktree-issue-1147-subsurface-picture-import`
**Supersedes nothing.** Closes the last open thread of the #153 umbrella; the
coordinate and duplicate-site threads landed in #1146.

## Problem

Subsurface writes one `<picture>` element per attached photo inside each
`<dive>`:

```xml
<picture filename='/home/jai/Pictures/2025/dive042.jpg'
         offset='+3:20 min'
         gps='18.465562 -66.084902'/>
```

Nothing in the app reads it. A user migrating a Subsurface logbook gets their
dives and sites but silently loses every photo association they had built up.

The hard part is not parsing. Subsurface stores an absolute path from the
machine that produced the export, so `/home/jai/Pictures/...` will not exist on
the importing device and on iOS or Android cannot exist at all. Import needs a
path-resolution strategy, and the resolution result needs to be visible to the
user rather than quietly reducing to a subset.

## Findings

Every claim below was verified against this branch at d32723a5807.

**F1. Media cannot be carried by a payload at all.** `ImportEntityType` is
declared twice, at `import_enums.dart:261` (the parser-facing enum, aliased
`ui.` in the adapter) and `import_bundle.dart:25` (the wizard-facing enum,
aliased `wizard.`). Neither has a media member, so `ImportPayload.entities`
has no key a parser could file pictures under. This is an absence, not a bug.

**F2. No parser touches media.** `grep -rn "'picture'"` over
`lib/features/universal_import/` returns nothing.

**F3. The one existing photo path is narrow and does not fit.**
`ZipExpansionService` collects `.jpg/.jpeg/.png/.heic/.heif` members next to a
dive file, and `universal_adapter.dart:919` attaches them only when the source
file produced exactly one dive. Two things make this unusable for Subsurface:
the gate excludes any multi-dive logbook, and `zip_expansion_service.dart:48`
sets `_diveFileExtensions = {'.zxu', '.zxl'}`, so an `.ssrf` inside a ZIP is
discarded as junk before the gate is ever reached. Fixing the gate alone would
not help.

**F4. The resolution ladder we need already exists.**
`media_repair_matcher.dart:8` `detectPrefixMove({brokenPaths, foundPaths})`
votes on `(fromPrefix, toPrefix)` pairs over shared trailing segments and
returns the pair covering the most paths, requiring at least two covered paths
so a single coincidental filename is not read as evidence of a move. It votes
at every shared suffix length, not only the longest, so a folder name common to
both sides cannot mask the true move root. `media_repair_matcher.dart:83`
`buildRepairProposals(...)` then runs prefix-move first and a lowercase
basename index second, emitting `RepairConfidence.unmatched` when neither hits.
`folder_candidate_source.dart:14` `FolderCandidateSource` supplies the
recursive scan that builds that index.

**F5. Those three are pure and operate on `MediaItem`, not on a bespoke type.**
`_filenameOf` (`media_repair_matcher.dart:149`) reads `originalFilename` and
falls back to the basename of `localPath ?? filePath`. A parsed `<picture>` has
exactly those two facts, so it can be dressed as a transient unsaved
`MediaItem` and fed through the existing ladder unchanged.

**F6. `MediaItem` already models the GPS attribute.**
`media_item.dart:73` and `:74` declare `latitude` and `longitude`. The writer
does not pass them: `media_import_service.dart:70` `importLocalFileForDive`
takes only `sourceFile`, `diveId` and `takenAt`, hardcodes `MediaType.photo`,
and always copies into a `scanned_logs/` subdirectory named for the OCR flow
that introduced it.

**F7. The wizard has no post-review step slot.**
`import_source_adapter.dart:38` documents acquisition steps as shown *before*
the shared Review, Import and Summary steps, and `calculateNextPage` in
`step_skip_calculator.dart` only advances while `nextPage < reviewIndex`. A
step between Review and Import is not expressible without changing the wizard
shell. `universal_adapter.dart:176` currently declares three acquisition steps:
Select File, Confirm Source, Map Fields.

**F8. The repair ladder assumes POSIX separators on both sides.**
`folder_candidate_source.dart:41` and `media_repair_matcher.dart:154` both find
a basename with `path.lastIndexOf('/')`, and `detectPrefixMove` splits on `'/'`
(`:18`, `:22`). On a Windows host `Directory.list` yields backslash-separated
paths, so the harvest indexes whole paths as keys and every lookup misses. That
is a pre-existing defect in the repair feature. It becomes this feature's
problem twice over, because a logbook exported from Windows carries
`C:\Users\jai\...` on to whatever platform imports it.

**F9. The offset attribute has no native column yet.**
`database.dart:3168` pins `currentSchemaVersion = 161`, and `grep -rn
"manualElapsed"` over `lib/` returns nothing. The `media.manual_elapsed_seconds`
column (v162) that models exactly this quantity is still in the open PR #1287.

### D9. Separator handling

Two fixes, on opposite sides of the comparison (F8).

The harvest is fixed in place: `FolderCandidateSource` switches to
`p.basename`, which follows the host separator. This repairs the media repair
feature on Windows as a side effect, which is the right outcome; the two
features share the ladder precisely so they cannot disagree.

The foreign side is normalised by the resolver, because only the resolver knows
its input came from another machine. `ImportMediaResolver` converts backslashes
to forward slashes before handing a path to `detectPrefixMove`, and sets
`originalFilename` explicitly to a both-separator basename so the ladder never
has to parse the foreign path at all. Treating `\` as a separator on POSIX is
technically lossy, since a POSIX filename may legally contain one; that risk is
accepted against the certainty of Windows-exported logbooks.

## Design

### D1. Reuse the repair ladder rather than writing a resolver

The chosen strategy is a user-picked media root, re-rooting absolute paths by
their longest shared trailing segments, falling back to a basename match across
the picked tree, with anything left over reported as not found. F4 and F5
establish that this ladder is already implemented and already pure. The design
therefore adds no matching logic:

```
FolderCandidateSource(roots: [pickedRoot]).harvest(transientItems)
  -> detectPrefixMove(brokenPaths, foundPaths)
  -> buildRepairProposals(transientItems, byFilename, prefixMove, foundPaths)
  -> one RepairProposal per picture
```

`RepairConfidence` maps onto the import vocabulary directly: `probable` via
`viaPrefixMove` is a clean re-root, `probable` without it is a filename-only
match, and `unmatched` is a picture we could not find. The `exact` and `edited`
rungs need content hashes and cannot arise here, since a `<picture>` element
carries no hash; the code must not assume they are reachable but also must not
special-case them away.

The benefit beyond volume of code is that improvements to the repair ladder
accrue to import automatically, and the two features cannot drift apart in how
they interpret a moved photo library.

### D2. Payload slot

Add `media` to both enums from F1, with `displayName` "Photos" and `shortName`
"Photos". Dart's exhaustive switches will locate every site that must handle
the new member; the ui-to-wizard mapping in `universal_adapter` gains the pair.

A payload media entry is a `Map<String, dynamic>` in keeping with the existing
convention documented on `ImportPayload`:

| Key | Meaning |
| --- | --- |
| `filename` | the foreign absolute path, verbatim from the attribute |
| `offsetSeconds` | signed seconds from dive start, null when absent |
| `latitude`, `longitude` | from the `gps` attribute, null when absent |
| `_diveIndex` | index of the owning dive within the payload's dive list |

`_diveIndex` follows the existing underscore convention for adapter-internal
stamps such as `_sourceFileId`.

`PayloadMerger` gains media handling so a multi-file batch concatenates media
lists while rebasing each `_diveIndex` onto the merged dive list. Getting this
wrong would attach a photo to the wrong dive, so it is tested directly.

### D3. Parser

`subsurface_xml_parser.dart` gains `_parsePictures(XmlElement dive)`, called
from the same place `_collectTags` and `_collectBuddies` are called today, on
both dive-collection paths (the parser walks dives at two sites, `:108` and
`:141`, and missing one is the obvious defect to guard against).

Offset parsing handles the signed `M:SS min` form including a negative offset,
which Subsurface writes for a photo taken before the dive started. An
unparseable offset yields null rather than dropping the picture: the file is
still worth importing, only its timestamp is unknown.

A picture with an empty or absent `filename` is dropped with an
`ImportWarning`, since there is nothing to resolve.

### D4. Resolver

New `ImportMediaResolver` under
`lib/features/universal_import/domain/services/`. It is deliberately
format-agnostic and knows nothing about Subsurface: it takes payload media maps
plus a root path and returns an `ImportMediaResolution` holding the resolved
path per picture index, plus counts for re-rooted, filename-only and not-found.
UDDF's `<link ref>` into `<mediadata>` can later feed the same resolver by
adding only a parser.

The transient `MediaItem`s it constructs are never persisted. They exist for
the duration of one resolve call purely to satisfy the ladder's parameter type.

### D5. Wizard placement

Per F7, the Photos step is a fourth acquisition step in
`universal_adapter.acquisitionSteps`, after Map Fields and before Review. It
follows the Map Fields precedent of a stricter auto-advance condition than its
Next condition:

- `canAdvance`: true once the user has picked a root, or explicitly chosen to
  skip photos. Never blocks the import on a folder the user does not have.
- `canAutoAdvance`: true only when the parsed payload carries zero pictures, so
  the step is invisible for every import that has no photos in it, and is never
  auto-skipped past a decision the user still needs to make.

`buildBundle()` then adds a media `EntityGroup`, so Review displays the photos
alongside dives and sites with the match counts already resolved. This is a
better outcome than the originally sketched post-review step: the resolution
result becomes part of what the user reviews rather than something decided
after review.

### D6. Commit

`importLocalFileForDive` gains optional `latitude`, `longitude` and a
destination subdirectory parameter defaulting to the current `scanned_logs`, so
the OCR caller is unaffected while imported photos land in their own directory.

The adapter attaches each resolved picture to the dive id created for its
`_diveIndex`, reusing the existing `result.diveIdByIndex` map and skipping any
dive folded away by consolidation, exactly as `attachImportedPhotos` does
today. `takenAt` is the dive's `dateTime` plus `offsetSeconds` when both are
known, and the dive's `dateTime` otherwise.

`offsetSeconds` is retained on the payload map even though only `takenAt`
consumes it now. When #1287 lands `media.manual_elapsed_seconds` (F9), adopting
it is a single additional field on the write, with no rework of the parser or
resolver.

### D7. Platform scope

Desktop only. The resolver needs real filesystem paths, which Android's SAF
does not reliably provide and iOS does not expose at all.

On mobile the Photos step still appears whenever the payload carries pictures,
but instead of a folder picker it states the picture count and that importing
them requires running the import on desktop, and confirms that dives and sites
import normally. The deliberate choice here is that a mobile user is told what
is being left behind rather than silently receiving a subset.

## Error handling

An unreadable subtree under the picked root yields a partial harvest and a
logged warning, which is `FolderCandidateSource`'s existing behavior; the
pictures it would have covered simply report as not found.

A per-photo copy failure at commit is counted and surfaced in the summary. This
is a deliberate tightening relative to `attachImportedPhotos`, whose
`catch (_)` currently swallows the failure entirely. The dive import must still
not fail because a photo copy did: the failure is reported, not thrown.

Resolution never blocks the import. A user who cancels the folder picker
proceeds with dives and sites and no photos.

## Testing

Test-driven, in this order.

1. Parser unit tests against a new `.ssrf` fixture carrying `<picture>`
   elements: absolute POSIX and Windows paths, a positive offset, a negative
   offset, a malformed offset, gps present and absent, and a picture on the
   second of the parser's two dive-walk paths.
2. Resolver tests over a real temp directory tree: clean whole-tree re-root,
   reorganised tree resolved by basename only, a picture present nowhere, and
   an ambiguous basename appearing twice.
3. `PayloadMerger` test: two files each with pictures, asserting `_diveIndex`
   rebasing keeps every photo on its own dive.
4. Widget tests: step auto-skipped with zero pictures, shown otherwise, mobile
   message rendered on a mobile platform override.
5. Adapter test: resolved photos land on the correct dive ids, a consolidated
   away dive drops its photos, and counts reach the summary.

## Out of scope

ZIP sidecar photos, Android SAF, iOS, the UDDF `<link ref>` parser, per-file
disambiguation UI for ambiguous basename matches, and video. The resolver is
written format-agnostic (D4) so UDDF is later a parser change only.

## Follow-ups

- Adopt `media.manual_elapsed_seconds` for `offsetSeconds` once #1287 merges.
- Add the UDDF `<link ref>` parser against the same resolver.
- Revisit ZIP sidecars, which need `_diveFileExtensions` widened (F3) and
  therefore touch the DiveCloud archive path.
