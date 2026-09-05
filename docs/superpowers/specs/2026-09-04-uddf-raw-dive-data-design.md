# Raw Dive Computer Data in UDDF Exports

**Issue:** [#228](https://github.com/submersion-app/submersion/issues/228)
**Date:** 2026-09-04
**Related:** [#227](https://github.com/submersion-app/submersion/issues/227), whose
spec is `2026-09-04-raw-dive-data-compression-design.md`. See "Relationship to
\#227" for the constraints it imposes on this work.

## Problem

`dive_data_sources.raw_data` holds the raw per-dive bytes libdivecomputer
handed back at download time. They are the only recoverable copy of a
download, and they are what makes re-parse work after a libdivecomputer fix.

UDDF export does not include them. A UDDF file exported from Submersion is
therefore not a complete archive of the logbook: restore it on a new device and
the dives come back, but every dive's raw bytes are gone and "Re-parse raw
data" has nothing to work with for the rest of that library's life.

## Goal

A Submersion UDDF export can carry the raw bytes, and a Submersion UDDF import
restores them in a state where re-parse still works. The bytes are written in
the form the UDDF standard prescribes, so other dive software and dive computer
manufacturers can read them too.

## Scope

- Both UDDF export paths (`UddfExportService`, `UddfFullExportService`), behind
  an opt-in toggle.
- The UDDF import path, restoring bytes and the metadata re-parse needs.
- Compression and base64 encoding per the UDDF specification.

## Out of Scope

| Item | Rationale |
|---|---|
| Compressing `raw_data` at rest | #227 owns it. This design consumes its output transparently; see below. |
| Any other export format (CSV, PDF, KML, DiveCloud) | UDDF is the only one of them with a standard place for a device dump. |
| Restoring more than one dump per dive | See "The multi-source asymmetry". |
| A new schema rung | Nothing in this design changes the schema. |
| Interpreting dumps written by other applications | We restore their bytes; we do not claim to know their parser. |

## Background: what the UDDF standard provides

UDDF 3.2.1 defines `<divecomputercontrol>` as the last section of the
document. It holds `<divecomputerdump>` elements, whose children are:

- `<link/>`: optional and **repeatable**, cross-referencing a declared id.
- `<datetime>`: required, when the dump was captured.
- `<dcdump>`: required, the payload.

The spec states of `<dcdump>`: "The memory dump data shall be compressed with
*bzip2* algorithm and encoded into ASCII using *Base64* encoder." bzip2 is
therefore not a choice this design makes; it is a requirement it satisfies.

`<divecomputerdump>` accepts **no attributes at all**, which is what drives the
pairing scheme below.

Two mismatches between the standard and what Submersion stores are worth
naming plainly:

1. The spec's `<dcdump>` means the whole binary contents transferred from a
   device. Submersion stores per-dive slices from libdivecomputer. Emitting one
   dump per dive is a defensible reading, and the explicit dive `<link>` makes
   the intent legible, but it is a reading rather than a literal match.
2. The spec has nowhere to record *which parser* a dump belongs to. Section
   "Why a sidecar is unavoidable" covers the consequences.

## Why a sidecar is unavoidable

`ReparseService.reparseAllForComputer` (`reparse_service.dart:319`) skips any
source whose `descriptorVendor`, `descriptorProduct` or `descriptorModel` is
null, counting it as a failure. Those three fields are the libdivecomputer
descriptor that says which parser the bytes belong to.

`<divecomputerdump>` has no element for them. A restore that carries only what
the standard can express therefore produces rows whose bytes are present and
permanently unparseable, which is the opposite of the goal. The descriptor has
to travel somewhere, and `<applicationdata><submersion>`, which this exporter
already writes (`uddf_export_builders.dart:895`), is where Submersion-specific
data already lives.

## Document Shape

Both new pieces sit at the end of the document. `<divecomputercontrol>` goes
last, per the spec, after the existing `<applicationdata>` that
`uddf_full_export_service.dart:405` already emits after `profiledata`.

```xml
  <applicationdata>
    <submersion version="1.0">
      <!-- existing equipment / trips / courses / etc -->
      <dcdumpindex>
        <entry diveref="dive_7f3a..." ordinal="0">
          <descriptor vendor="Shearwater" product="Perdix" model="5"/>
          <libdivecomputerversion>0.9.0-devel</libdivecomputerversion>
          <sourceuuid>...</sourceuuid>
          <fingerprint>A17F3C...</fingerprint>
          <primary>true</primary>
          <mergesourceslot>0</mergesourceslot>
          <timeoffsetseconds>0</timeoffsetseconds>
        </entry>
      </dcdumpindex>
    </submersion>
  </applicationdata>

  <divecomputercontrol>
    <divecomputerdump>
      <link ref="dive_7f3a..."/>
      <link ref="computer_9c21..."/>
      <datetime>2026-08-14T09:12:30</datetime>
      <dcdump>QlpoOTFBWSZTW...</dcdump>
    </divecomputerdump>
  </divecomputercontrol>
```

`<fingerprint>` is hex, not base64. `dive_repository_impl.dart:6224` documents
that fingerprints are "hex-encoded the same way SQLite's `hex()` function"
does, and #227 leaves `raw_fingerprint` uncompressed and hex-matched for
download de-duplication. A restored fingerprint is therefore directly
comparable to a stored one.

### Pairing

`<divecomputerdump>` cannot carry an id, so a sidecar entry cannot point at one
directly. Dumps are emitted grouped by dive in source order, and each sidecar
entry addresses one by `(diveref, ordinal)`.

Every `ref` this design emits points at an id the standard itself declares:
`dive_<id>` on `<dive>`, and the computer id on `<divecomputer>` under
`<owner><equipment>`.

**The computer link is emitted only when the document declares that computer.**
Only the full export writes `<divecomputer>` elements
(`uddf_full_export_service.dart:142`); the dives-only export writes none. A
dump in a dives-only export therefore carries the dive link alone. Teaching the
dives-only export to declare computers would be a larger change to a path whose
job is to stay lean, and the dive link already carries the attribution that
matters. Making the link conditional on declaration is what keeps the
invariant true in both paths.

The UDDF documentation describes `ref` as the "unique
identifier of the data object to be cross-referenced" without naming its XML
type, and UDDF's schema conventionally pairs `id`/`ref` as `xs:ID`/`xs:IDREF`.
If it does, a `ref` pointing into `<applicationdata>` could fail validation.
Referencing only standard-declared ids means nothing we write can dangle, at no
cost.

The ordering is part of the contract, not incidental: it is what makes the
ordinal meaningful. If another tool rewrites the file and reorders or drops
dumps, pairing degrades to a wrong or absent descriptor, which the importer
detects (see "Importing a foreign file") rather than trusting.

### Where the sidecar lives in each export

The top-level `<applicationdata><submersion version="1.0">` block exists only
in the full export (`uddf_export_builders.dart:895`). The dives-only export's
only `<applicationdata>` is a different element in a different place: a
per-dive inline one carrying custom fields
(`uddf_export_service.dart:525`), shaped `<name>Submersion</name>` plus
`<customfield>`.

So `<dcdumpindex>` is built by a small shared
`UddfExportBuilders.buildDcDumpIndex(builder, entries)`, called from two
places:

- The full export calls it from inside the existing `buildApplicationData`,
  alongside equipment, trips and courses.
- The dives-only export wraps it in a top-level
  `<applicationdata><submersion version="1.0">` emitted only when dumps are
  being written. The per-dive inline `<applicationdata>` elements are
  untouched; UDDF permits `<applicationdata>` in both positions, and they do
  not collide.

The importer therefore has to accept a `<submersion>` block containing nothing
but a `<dcdumpindex>`, with none of the full export's other payload present.

### `<datetime>`

The source row's `importedAt`. The spec means when the dump was captured, and
that is the closest thing recorded to the download moment. The dive's own
datetime would be friendlier to a reader that ignores our links, at the cost of
saying something the spec does not mean; the explicit dive `<link>` serves that
reader better anyway.

**This does not affect dive times.** The dive's own datetime lives at
`<dive><informationbeforedive><datetime>` and is read by a scoped lookup:
`diveElement.findElements('informationbeforedive')`, then
`getElementText(beforeElement, 'datetime')`
(`uddf_full_import_service.dart:1262`). The dump's datetime lives in a
different section entirely and is never in that element's scope. Neither UDDF
importer contains a single `findAllElements` call, so no document-wide scan can
stray across sections.

The format already reuses the `<datetime>` element name in an unrelated place,
equipment purchase dates (`uddf_full_import_service.dart:2474`), and it causes
no trouble for exactly this reason. A regression test pins it: a document
carrying both a dive datetime and a dump datetime that differ imports the dive
at its own time. That test is what fails if anyone later "simplifies" a lookup
to `findAllElements('datetime')`.

## Export

### Options

A new `UddfExportOptions`, mirroring `PdfExportOptions`
(`lib/core/constants/pdf_templates.dart:95`): a const class with defaults,
whose only field for now is `includeRawData`, defaulting to `false`. It threads
through `ExportService`'s four UDDF entry points as a defaulted named
parameter, so every existing call site compiles unchanged.

The full-backup UI presents the checkbox pre-checked, the dives-only share
paths present it unchecked. Same class, different presented default, so the
safe value stays the code-level default.

### Fetching

A new value type `DiveRawDump` and one bulk repository method,
`getRawDumpsForDives(List<String> diveIds)`: a single
`diveId.isIn(ids) & rawData.isNotNull()` query ordered by dive, then
`isPrimary`, then `createdAt`.

**It must be a Drift-typed select, never `customSelect`.** Two independent
reasons:

1. `getDataSources` (`dive_repository_impl.dart:6192`) runs rows through
   `_canonicalDataSourceRows`, which deliberately collapses rows sharing a
   merge slot into one *display* source. The `DiveDataSources` table comment
   states each carried row "is the sole surviving copy of its half's rawData".
   Exporting through that method would silently drop half of a combined dive's
   bytes, so this query maps Drift rows directly and reuses neither that method
   nor its collapsing.
2. Under #227, `raw_data` carries a `TypeConverter`. Drift-typed selects run
   converters; `customSelect` does not. A raw-SQL version of this query would
   put `SRD1`-framed zlib streams inside `<dcdump>` and no test would notice
   until someone tried to re-parse a restored dive.

`reparse_service.dart` already encodes the rule by example: `customSelect` for
the three counting queries (lines 246, 253, 269, all `IS NULL` /
`IS NOT NULL` predicates), and a typed `db.select(db.diveDataSources)` the
moment it needs bytes (line 292).

When `includeRawData` is false the provider never calls this method, so a
shared single dive costs nothing extra.

### Compression

Compression happens before XML building, not inside the builder, so
`UddfExportBuilders.buildDiveComputerControl(...)` stays a pure synchronous
function over already-encoded strings like every other builder in that file.

A new `UddfDumpCodec` holds `BZip2Encoder` plus base64, and an `Isolate.run`
hop shaped exactly like `backup_crypto.dart:54`, whose comment records the
reason: the hop is kept as its own method so the `Isolate.run` closure's
enclosing scope holds only sendable values, because Dart closures capture the
whole enclosing scope rather than only what they reference. The hop takes
`List<Uint8List>` and
returns `List<String?>`. `Uint8List` crosses the isolate boundary cheaply.

bzip2 is a block-sorting compressor and is markedly slower than zlib in pure
Dart, which is why this is on a worker isolate rather than inline.

**Decode-then-recompress is mandatory.** At rest the bytes are zlib-framed
(#227); on the wire the spec requires bzip2. Passing the stored blob through
untouched would be faster and would produce a spec-violating file that no other
UDDF tool can read. This is recorded because it is exactly the optimization a
future reader reaches for.

### Failure isolation

This is a backup path, so one bad blob must not cost the user the whole file.
Each dump is compressed independently; a failure yields `null` for that entry,
its `<divecomputerdump>` and its sidecar entry are both omitted, and the
failure is logged. The export completes.

The export result reports how many dumps were written and how many were
skipped, so a shortfall is visible rather than inferred.

### No export-side size cap

The document is already assembled in memory today, raw dumps are single-digit
KB in practice (#227 measured 400 B to 22 KB against the repository's own
fixtures), and a cap only adds a failure mode nobody asked for. If real-world
file sizes prove to be a problem, that is a follow-up with a measurement behind
it. Import is a different matter; see below.

## Import

### Parsing

`UddfFullImportService` gains a `<divecomputercontrol>` pass producing, per
dump: the dive ref, the ordinal, the decoded bytes, and whatever the paired
`<dcdumpindex>` entry supplies. It stays a pure parser returning maps, matching
the rest of that file. Dumps whose dive ref resolves to no imported dive are
dropped.

### Bounding untrusted input

A `<dcdump>` in someone else's file is hostile input, and bzip2 expands far
more aggressively than zlib, so a small element can decode to a great deal.
`inflateBounded` is zlib-specific and does not apply.

`BZip2Decoder.decodeStream(InputStream, OutputStream)` takes the abstract
`OutputStream` (`writeByte` / `writeBytes` / `length`), so decoding runs into a
bounded `OutputStream` subclass that throws once `length` exceeds the ceiling.
That aborts mid-stream rather than buffering the whole output and checking
afterwards, matching the posture #227's `inflateBounded` takes. `decodeBytes`
is not used.

The ceiling is `kMaxRawDiveBlobBytes` (8 MiB), the same constant #227
establishes. There must be exactly one definition of it; see "Relationship to
\#227".

### Restore

This lands in a seam that already exists. `uddf_entity_importer.dart:2078`
builds one `DiveDataSourcesCompanion` per imported dive and writes it through
`saveComputerReading`. Restoring a dump adds `rawData`, `rawFingerprint`, the
descriptor triple, `libdivecomputerVersion` and `timeOffsetSeconds` to that
companion.

No new table write, no new repository method, no change to import ordering.

### The multi-source asymmetry

The exporter writes one dump per source row. The importer writes one source row
per dive. A dive consolidated from two computers therefore exports two dumps
and restores one.

The primary source's dump is restored and the rest are dropped, with the count
of dropped dumps reported in the import result. The exported file stays
complete, both for other tools and for a future importer that learns to write
additional rows, so nothing is lost that cannot be recovered later. Only our
restore is lossy, only for multi-source dives, and visibly so.

Building multi-row restore now means teaching the importer a second write path
for a case the export already makes recoverable. That is speculative work, and
the count in the import result is what would justify it with evidence.

### Importing a foreign file

A spec-shaped `<divecomputerdump>` with no `<dcdumpindex>` restores its bytes
with a null descriptor. Re-parse then reports that source as a failure, which
it already does for any source missing a descriptor
(`reparseAllForComputer` returns `succeeded`/`failed`). The bytes are kept
because they are not ours to discard, and because a later Submersion may learn
to identify them.

## Relationship to #227

#227 compresses `raw_data` at rest with a Drift `TypeConverter`. Because the
converter operates below Drift's row mapping, this design reads plain
uncompressed bytes with no decompression step of its own.

The two features are independent in either merge order. This design adds no
schema rung, so nothing races #227's v188 claim.

### What is shared

| Shared | Form |
|---|---|
| `kMaxRawDiveBlobBytes` (8 MiB) | One definition. Whichever PR lands second deletes its duplicate and imports the other's. Preferred long-term home is #227's `raw_dive_data_codec.dart`, the more foundational layer. |
| The three libdivecomputer raw fixtures | Already committed. Both specs cite the same evidence rather than inventing test data. |
| The bounded-decode posture | A principle: abort mid-stream, never buffer-then-check. Two implementations, because `inflateBounded` is zlib-specific. |

### What is not shared, and why

| | #227 (at rest) | #228 (UDDF) |
|---|---|---|
| Algorithm | zlib level 6 | bzip2, mandated by the spec |
| Framing | `SRD1` magic + uint32 length | bare bzip2 then base64; a custom header is forbidden |
| When | only when the result is smaller | always, even if it grows |
| On failure | return stored bytes verbatim | skip that dump, count it, keep exporting |
| Layer | `TypeConverter` under the database | isolate hop in the export path |

Every row differs, and each for a reason belonging to a different master: #227
answers to "never lose a byte and use less disk", #228 to "another vendor's
reader must be able to open this". A shared abstraction over those would be a
facade whose two implementations have no behavior in common.

### Rejected: putting `SRD1` blobs inside `<dcdump>`

The obvious way to make the two features share an encoder is to write #227's
`SRD1`-framed zlib blob straight into `<dcdump>`, since the export would then
be a byte copy of what is already on disk and neither feature would need a
second codec.

It is rejected because it violates "shall be compressed with *bzip2*". The
resulting file would be opaque to every other UDDF reader, which destroys the
entire reason for using the standard `<divecomputercontrol>` section rather
than hiding the bytes in `<applicationdata>`. Interop is the feature; the
shared encoder would be the thing that removed it.

This is recorded because "share the compression code" is a reasonable instinct
that leads directly here.

## Testing

TDD throughout, per the project's rules.

**Codec**

- Round trip through base64(bzip2(...)) and back over the three committed
  libdivecomputer fixtures, asserting byte equality.
- Empty and single-byte payloads.
- A decode bounded at `kMaxRawDiveBlobBytes` aborts mid-stream on a bzip2 bomb
  rather than allocating the full output.

**Export**

- A dive with raw data produces one `<divecomputerdump>` carrying the dive link,
  the computer link, a datetime and a dcdump, plus a paired `<dcdumpindex>`
  entry with the descriptor triple.
- With `includeRawData` false, neither `<divecomputercontrol>` nor
  `<dcdumpindex>` appears at all, and the raw-dump query is never issued.
- A dump that fails to compress is skipped and counted; its siblings still
  export and the document is still valid.
- A dive with two source rows carrying bytes exports two dumps with ordinals 0
  and 1, both paired. This is the test that fails if the query is ever routed
  through `_canonicalDataSourceRows`.
- A dives-only export emits the dive link and **no** computer link, since that
  path declares no `<divecomputer>`, and hosts its `<dcdumpindex>` in a
  top-level `<applicationdata><submersion>` alongside the untouched per-dive
  inline `<applicationdata>` custom-field elements. A full export of the same
  dive emits both links. This pins the no-dangling-ref invariant in the path
  where it is easiest to break.

**The load-bearing test**

Write a download through the repository, read it back through
`getRawDumpsForDives`, and assert the bytes are byte-identical to what went in.
Under #227 this fails loudly if anyone converts that query to `customSelect`
for speed. It is the only thing standing between a plausible refactor and a
corrupted backup.

**Import**

- Full round trip: export a logbook with raw data, import it, assert the
  restored source row's bytes and descriptor triple are byte-identical, and
  that `ReparseService` can consume the restored row.
- A spec-shaped dump with no `<dcdumpindex>` restores bytes with a null
  descriptor, and re-parse reports the failure rather than crashing.
- A `<submersion>` block containing nothing but a `<dcdumpindex>` imports
  cleanly, which is what a dives-only export produces.
- A document whose dive datetime and dump datetime differ imports the dive at
  its own time. This pins the section scoping described under `<datetime>`.
- A dive whose export carried two dumps restores one and reports one dropped.
- An oversized dump is refused without taking the import down.

## Files Touched

| File | Change |
|---|---|
| `lib/core/services/export/uddf/uddf_dump_codec.dart` | New. bzip2 + base64, the isolate hop, the bounded output stream. |
| `lib/core/services/export/models/uddf_export_options.dart` | New. `includeRawData`. |
| `lib/core/services/export/uddf/uddf_export_builders.dart` | `buildDiveComputerControl`; shared `buildDcDumpIndex`, called from `buildApplicationData`. |
| `lib/core/services/export/uddf/uddf_export_service.dart` | Accept options; emit `<divecomputercontrol>` and a top-level `<applicationdata><submersion>` wrapper for the index. |
| `lib/core/services/export/uddf/uddf_full_export_service.dart` | Same. |
| `lib/core/services/export/export_service.dart` | Thread options through four entry points. |
| `lib/core/services/export/uddf/uddf_full_import_service.dart` | Parse `<divecomputercontrol>` and `<dcdumpindex>`. |
| `lib/features/dive_import/data/services/uddf_entity_importer.dart` | Extend the existing provenance companion. |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | `getRawDumpsForDives`. |
| `lib/features/dive_log/domain/entities/dive_raw_dump.dart` | New value type. |
| `lib/features/settings/presentation/providers/export_providers.dart` | Fetch dumps when enabled; carry counts into export state. |
| UI: settings export, dive detail, dive list, buddy detail, transfer page | The toggle. |
| `lib/l10n/arb/app_en.arb` and every other locale | Toggle label, help text, skipped/dropped counts. |

New user-facing strings mean ARB work across all locales, and the generated
l10n must be regenerated and committed or CI's staleness gate fails.
