# PDF Logbook Export Rework

Date: 2026-08-20
Issue: #1017 (Dive Log Export needs love), plus a user report that the
Detailed template produces summary-level output.

## Problem

Two reports, one root cause.

A user selected the Detailed log type and received a sparse card showing only
depth, duration, temperature and first-cylinder pressures, with the notes cut
off mid-sentence. Issue #1017 independently lists roughly 28 fields the
Detailed logbook should carry and reports content gaps in every other
template.

The template selection mechanism is not broken. `PdfExportDialog` collects the
choice, `export_providers.dart:336` resolves it through `PdfTemplateFactory`,
and the correct builder runs. The screenshot was produced by
`PdfTemplateDetailed`, confirmed by the `-` separator in the Air chip
(`pdf_template_detailed.dart:168`) which distinguishes it from the legacy
builder's `→` (`pdf_export_service.dart:449`).

The defect is that `PdfTemplateDetailed._buildDiveEntry` renders 6 of the
roughly 80 fields on `Dive` and applies `maxLines: 2` to notes. Its own class
docstring promises "all available information including notes, gas info, tank
data, ratings". The code was extracted from the legacy hardcoded layout and
never enriched.

### Secondary defects found while investigating

1. **Certifications silently truncate.** `buildCertificationCardsPage` renders
   every certification passed to it with no cap, but all four callers wrap it
   in a single `pw.Page` rather than `pw.MultiPage`. Anything past one page is
   dropped. This is what #1017 reports as "not all certifications are
   displayed".
2. **Units are hardcoded metric.** No template imports `unit_formatter.dart`.
   Depth, temperature and pressure are printed with literal `m`, `°C` and
   `bar` suffixes off the metric-base fields. This violates the project rule
   that displayed units follow the active diver. PADI prints cylinder
   pressures with no unit label at all (`pdf_template_padi.dart:342`).
3. **A sixth, unselectable copy of the layout exists.**
   `PdfExportService._buildDivePdf` / `_buildPdfDiveEntry`
   (`pdf_export_service.dart:233-470`) duplicates the Detailed layout. It is
   reached by the dive-list bulk export and the single-dive export on the
   detail page, neither of which offers a template choice. It hardcodes A4,
   ignores the requested page size, and builds `pw.Document()` without
   `PdfFonts.instance.theme`, so it has no Unicode font and mangles accented
   site names.
4. **Profile data is never available to the exporter.** `getAllDives` skips
   profile hydration by design (`dive_repository_impl.dart:307`), so
   `dive.profile` is empty for every dive that reaches a template.
5. **NAUI recomputes aggregates inline** (`pdf_template_naui.dart:113-117`)
   instead of using `buildSummaryPage`, so its numbers can drift from the
   shared ones.

## Decisions

Confirmed with the maintainer before design:

| Decision | Choice |
| --- | --- |
| Scope | All templates in one PR |
| Professional template | Delete it as redundant |
| Detailed density | One dive per page |
| Units | Fix as part of this work |
| Bulk and single-dive exports | Route through the factory, delete the legacy duplicate |
| Professional's diver page | Absorb into shared front matter, keep stamp and signature areas as an option |

## Goals

- Detailed carries the full #1017 field list on one page per dive, including a
  depth profile chart.
- Every template respects the diver's unit settings.
- Certifications paginate and show agency, name, number, issue date.
- Simple gains the key metrics and certification listing #1017 asks for.
- Every PDF entry point in the app produces output from the same template
  system.

## Non-goals

- Redesigning the PADI and NAUI page layouts. They keep their current visual
  identity and receive only content and correctness fixes.
- Dive photos in PDFs. `Dive.photoIds` stays unrendered. Only the diver
  portrait and certification card scans are images.
- Localising template body labels. The templates currently use English field
  labels inline; changing that is a separate concern.

## Architecture

### Unit plumbing

`PdfTemplateBuilder.buildPdf` gains a required `UnitFormatter units`
parameter, mirroring how `PdfDateFormatter dates` was threaded through for
#964.

`lib/core/utils/unit_formatter.dart` already provides `formatDepth`,
`depthSymbol`, `formatTemperature`, `formatPressure`, `formatVolume`,
`formatTankVolume`, `formatWeight` and `sacSymbol`. Nothing new is needed
there.

The single caller already holds the settings object:

```dart
// export_providers.dart, existing
final settings = _ref.read(settingsProvider);
// added
units: UnitFormatter(settings),
```

Every hardcoded `'m'`, `'°C'` and `'bar'` in the templates and in
`pdf_shared_components.dart` is replaced by the corresponding formatter call.

### Profile chart

New file `lib/core/services/pdf_templates/pdf_profile_chart.dart`.

Rendered as native PDF vector graphics using the `pdf` package's own chart
widgets (`pdf` 3.13.0 ships `chart/line_chart.dart`, `grid_cartesian.dart`,
`grid_axis.dart`):

```dart
pw.Chart(
  grid: pw.CartesianGrid(xAxis: ..., yAxis: ...),
  datasets: [pw.LineDataSet(data: points, drawSurface: true, drawPoints: false)],
)
```

Rasterizing the existing `dive_profile_chart.dart` via its `exportKey`
`RepaintBoundary` was rejected. `buildPdf` has no `BuildContext`, and
`track_shape_painter.dart:10` documents that `toImage()` hangs under
`flutter test`, which would make the feature untestable. Vector output is also
sharp at print resolution and adds few bytes.

Depth is drawn increasing downward. Temperature is not plotted; water
temperature appears as a field.

### Profile data loading

This is the highest-risk part of the change.

A new `PdfProfileSeries` value object carries a downsampled point list per
dive. `buildPdf` gains an optional `Map<String, PdfProfileSeries> profiles`.

Loading rules:

1. **Do not use `getDiveProfile`.** It filters `isPrimary = true`. Per the
   #623 investigation, `setPrimaryDataSource` can leave a file-imported dive
   with zero primary rows, so that query would render blank charts for exactly
   the dives imported from other logbooks. Use the `getMergedProfile`
   behaviour, which keeps every source's rows and drops the originals a saved
   edit superseded (`_dropSupersededOriginals`, added in #1161).
2. **Batch.** Add a repository method that selects profile rows for a list of
   dive ids in one query and groups them, rather than calling a per-dive
   method N times. Chunk the id list to keep the `IN` clause and peak memory
   bounded.
3. **Downsample** to a target of roughly 200 points per dive before the
   template sees them. A chart a few inches wide cannot resolve more, and this
   bounds memory for large logbooks.
4. **Load only when needed.** Only templates that draw charts request
   profiles, so Simple, PADI and NAUI exports do no profile work.
5. **Absent data collapses.** A dive with no samples omits the chart region
   entirely rather than printing an empty frame.

### Shared front matter

New file `lib/core/services/pdf_templates/pdf_front_matter.dart`, absorbing
the useful half of the deleted Professional template.

- **Cover page**: existing `buildCoverPage`, unchanged apart from units.
- **Diver page**: Professional's `_buildDiverProfilePage` (`:213-323`) moved
  here, with the empty box currently labelled `'Photo'` (`:249-264`) replaced
  by the real portrait loaded from `Diver.photoPath`. The five-certification
  cap at `:279` is removed.
- **Summary page**: `buildSummaryPage` extended with first dive date, last
  dive date and total dive time, which #1017 requests for both Detailed and
  Simple. Existing stats (count, total time, deepest, average depth, unique
  sites) are retained and unit-formatted.
- **Verification areas**: Professional's `buildStampArea` and
  `buildLargeSignatureBlock` are retained and become an opt-in element on
  Detailed, controlled by a new flag on `PdfExportOptions`.

### Certification rendering

`buildCertificationCardsPage` changes from returning a single `pw.Widget`
placed on a `pw.Page` to producing a `List<pw.Widget>` used as a
`pw.MultiPage` body, so long certification lists paginate instead of
overflowing. Card fields become agency, name or type, card number, issue date
and expiry date.

`supportsCertificationCards` returns true for Simple, which currently refuses
them.

### Template changes

| Template | Change |
| --- | --- |
| Detailed | Rebuilt. One dive per page. Profile chart, all #1017 fields in labelled groups, every cylinder with mix, size, material, pressures and SAC, buddies with signatures, full untruncated notes, optional verification areas |
| Simple | Table layout kept. Gains the summary block and certification pages. Units fixed |
| PADI | Layout kept. Units fixed including the unlabelled pressures at `pdf_template_padi.dart:342`, certifications paginated |
| NAUI | Layout kept. Units fixed, inline aggregate computation replaced by the shared helper, certifications paginated |
| Professional | Deleted |

Deleting Professional is safe: `PdfTemplate` is not persisted anywhere in the
app, so no stored value can fail to deserialize. Removal covers the enum case,
the `divesPerPage` and `supportsCertificationCards` branches, the factory
branch, `pdf_template_professional.dart`, its l10n keys in every locale, and
its tests.

### Unifying the remaining entry points

`ExportService.exportDivesToPdf`, `saveDivesToPdfFile` and
`generateDivePdfBytes` gain an optional `PdfExportOptions`. Both callers get a
template picker and route through `PdfTemplateFactory`:

- `dive_list_content.dart:600-610` (bulk export from selection)
- `dive_detail_page.dart:2969` (single dive)

`PdfExportService._buildDivePdf`, `_buildPdfDiveEntry`, `_buildPdfStatRow`,
`_buildPdfInfoChip` and `_buildPdfSignatureBlock` are then deleted.
`PdfExportService` retains the save, share and byte-writing helpers, which are
still used.

`exportTripToPdf` and `pdf_course_export_service.dart` are out of scope; they
are separate documents with their own layouts.

## Testing

The existing suite provides the pattern. `export_pdf_logbook_test.dart` uses a
`pdfVisibleText` helper to extract rendered strings and assert on content, and
already contains "saves the template the user picked, not the legacy layout".

New coverage:

- Detailed renders each #1017 field group when data is present, and omits
  groups cleanly when absent.
- Notes are not truncated. This is the direct regression test for the reported
  bug, asserting that a long note's final words appear in the output.
- Every template renders imperial units under imperial settings and metric
  under metric.
- A certification list long enough to overflow one page produces a document
  where the last certification is still present.
- The profile chart appears for a dive with samples and is omitted for one
  without.
- Profile loading returns points for a dive whose rows are all
  `isPrimary = false`, the file-import case from #623.
- Downsampling caps point count while preserving first and last samples and
  maximum depth.
- Bulk export and single-dive export honour the selected template.
- `PdfTemplate.values` no longer contains `professional`.

Baseline before changes: 30 tests pass across `test/core/services/export/pdf`
and `export_pdf_logbook_test.dart`.

## Risks

| Risk | Mitigation |
| --- | --- |
| Profile loading makes large exports slow or memory-heavy | Batch query, chunked ids, downsample to ~200 points, load only for templates that chart |
| Blank charts for file-imported dives | Use the merged-profile rule, not the `isPrimary` filter. Explicit test |
| One dive per page makes large logbooks very long | Accepted. Simple remains the compact option, and the maintainer chose this density |
| Unit sweep misses a hardcoded suffix | Grep for the literal suffixes as a completion check, plus per-template imperial tests |
| Deleting Professional breaks a saved preference | Verified `PdfTemplate` is never persisted |
| l10n key removal missed in some locale | Remove `enum_pdfTemplate_professional` and its description across every arb file |

## Open items

None. All scope questions were resolved before this document was written.
