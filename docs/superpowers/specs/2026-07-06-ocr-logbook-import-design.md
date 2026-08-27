# OCR Paper Logbook Import - Design

Date: 2026-07-06
Status: Implemented (plan: docs/superpowers/plans/2026-07-06-ocr-logbook-import.md); device smoke pending

## Summary

Let a diver photograph a page of a physical dive logbook and turn it into a
Submersion dive entry. The photo is processed entirely on-device: an OCR
engine extracts positioned text, a pure-Dart parser maps that text to dive
fields, and the user reviews the result in the existing dive edit form with
the source photo attached.

## Decisions

| Question | Decision |
| --- | --- |
| Primary use case | Occasional single-dive capture (not bulk back-catalog migration) |
| Extraction | On-device OCR only; no cloud services, photos never leave the device |
| Platforms | All five: iOS, Android, macOS, Windows, Linux |
| Review UX | Prefilled `DiveEditPage` in create mode with source photo attached |
| Parsing | Layout-aware heuristics (label geometry + pattern regexes); no per-brand templates |

## Architecture

New feature directory `lib/features/ocr_import/` with three layers.

### Layer 1: OCR engine abstraction

A Dart interface with one job: image bytes in, positioned text out.

```dart
abstract class OcrEngine {
  Future<OcrResult> recognize(Uint8List imageBytes);
  Future<bool> get isAvailable;
}

class OcrResult {
  final List<OcrTextBlock> blocks;
  final Size imageSize;
}

class OcrTextBlock {
  final String text;
  final Rect boundingBox; // image pixel coordinates, top-left origin
  final double? confidence;
}
```

Per-platform implementations:

| Platform | Engine | Integration |
| --- | --- | --- |
| iOS / macOS | Apple Vision (`VNRecognizeTextRequest`, accurate mode) | New in-repo plugin `submersion_ocr` (same pattern as `submersion_saf`) |
| Android | ML Kit Text Recognition (Latin, bundled model) | `submersion_ocr` plugin, native Kotlin implementation (the `google_mlkit_text_recognition` pub package was dropped: its iOS pods force a higher deployment target and its multi-script references break R8) |
| Windows | Windows.Media.Ocr (WinRT) | `submersion_ocr` plugin, Windows implementation |
| Linux | Tesseract system binary invoked as a process | Thin Dart wrapper; graceful degradation when not installed |

Native code does only the dumb, well-defined thing (pixels to positioned
text); all domain intelligence lives in pure Dart. Future upgrades (template
packs, an opt-in cloud extractor) would slot in behind the same seams.

### Layer 2: Logbook field parser

Pure Dart, no platform code. Input: `OcrResult`. Output: the existing
`IncomingDiveData` struct (`lib/core/domain/models/incoming_dive_data.dart`)
plus per-field extraction notes (which label or pattern produced each value).

Pipeline stages:

1. **Label binding.** A keyword table matches label fragments (English plus
   the app's existing locale strings for these terms): `Dive No./Dive #`,
   `Date`, `Location`, `Time IN/Time (IN)`, `Time OUT`, `START/END` with
   `bar/psi`, `Bottom Time`, `ABT`, `Visibility`, `Temperature` with
   `Air/Surface/Bottom`, `Weight`, `Buddy`, `Divemaster/Instructor`,
   `Comments/Notes/Dive Notes & Observations`. The bound value is the
   nearest non-label fragment **right-of, below, or above** the label's
   bounding box (PADI Z-diagrams place the handwritten value above the
   printed label), within a distance threshold scaled to text height,
   preferring the direction consistent with other bindings on the page.
2. **Label specificity ordering.** Longest / most specific label wins:
   `Certification No.` must never bind to dive number; `Bottom Time To
   Date` and `Cumulative Time` must never bind to duration.
3. **Pattern extraction.** Independent of labels, global regexes catch
   self-describing values anywhere on the page: dates in common formats,
   `18m` / `60ft` / `11.1m`, `42 min`, `200 bar` / `3000 psi`, `EAN32` /
   `32%`, clock times. Label-bound results win over pattern-only results on
   conflict.
4. **Value normalizer.** Real-world shorthand between OCR and assignment:
   `3K` = 3000 (pressure K-multiplier), `10:00A` AM/PM suffixes, two-digit
   years (`'06`), month names (`6 Feb '06`), decimal depths. `MM/DD` vs
   `DD/MM` disambiguated by the >12 rule, otherwise by device locale.
5. **Page-level unit inference.** Explicit unit tokens are authoritative
   and converted to metric for storage. One field with explicit imperial
   units (`60 ft`, `psi`) makes imperial the default interpretation for
   bare numbers on the same page; absent any signal, fall back to the
   active diver's unit settings.
6. **Sanity gates.** Parsed values must be plausible before prefilling:
   depth 0-350 m, duration 1-600 min, water temp -2-40 C, dates not in the
   future. Implausible values are dropped to blank, never shown. OCR
   misreads look numerically plausible (`180m` from `18.0m`), so gating is
   load-bearing.

Everything not label-bound or pattern-matched is ignored by construction:
pre-printed instructional text, skills checklists, wheel diagrams, stamps,
signatures, URLs.

### Layer 3: Flow and UI

Entry points:

- Dive list add menu: "Scan paper log" next to "New dive".
- Import hub: an OCR source tile alongside file and dive-computer imports.

Flow: acquire image (camera or gallery via existing `image_picker` on
mobile, file picker on desktop) -> progress state while OCR + parse runs ->
`DiveEditPage` in create mode (`embedded`/`onSaved` hooks already exist),
prefilled from `IncomingDiveData`, source photo attached via the existing
media pipeline (`PhotoImportHelper` / `Dive.photoIds`), and
`importSource: 'ocr'` set for provenance.

Saving uses the ordinary manual-dive path (`DiveRepositoryImpl.createDive`).
No new persistence code; sync sees a normal manual dive.

## Extracted fields

| Group | Fields |
| --- | --- |
| Core | dive number, date, entry time, duration (bottom time), max depth |
| Environment | water temp, air temp, visibility |
| Location | site name (text), location/country (text) |
| People | buddy, divemaster/instructor |
| Gas and gear | start pressure, end pressure, O2 percent (nitrox), cylinder volume, weight used |
| Subjective | notes (content below the Comments/Notes label), rating only when written as text or a number (graphic scales like smiley faces are not readable) |

Derivations and fallbacks:

- `Time Out` present with `Time In` but no bottom time: duration computed
  from the pair. When all three exist, In/Out validates bottom time.
- `ABT` serves as bottom-time fallback when the plain label is absent.
- Anything not confidently found is left blank in the edit form. Never
  guessed.

Site resolution: the extracted site name is fuzzy-matched against existing
dive sites (reusing the text-similarity helpers in `dive_sites`). A
confident match pre-links the site; otherwise the name prefills the site
field for the user to confirm or create. The GPS-based `site_matcher` does
not apply (paper logs rarely carry coordinates).

### Out of scope for v1

- **Checkbox-borne data**: water type, boat/shore, suit type, and unit
  tick-boxes (`m`/`ft`, `kg`/`lbs`). OCR engines do not reliably read
  checkbox marks. Unit resolution relies on explicit unit text, then
  page-level inference, then diver settings; the user corrects in review.
  This is the most likely manual correction and is acceptable in an
  edit-form review flow.
- Per-brand template packs (could be layered on later behind the same
  parser seam).
- Batch / multi-page capture.
- Cloud LLM extraction.
- Marine life extraction from notes text.

## Error handling

Cardinal rule: the flow never dead-ends. Every failure degrades to a manual
dive entry with the photo attached.

| Failure | Behavior |
| --- | --- |
| OCR finds little or nothing (blur, glare, illegible) | Open the edit form blank with photo attached and a notice that fields were left blank |
| Partial extraction | Expected case, not an error; unmatched fields stay blank, no per-field warnings |
| Sanity-gate rejection | Silently blank |
| Engine unavailable (Linux without Tesseract) | Entry point stays visible and explains what to install |
| Cancellation during processing | Return to origin; captured photo discarded |
| Photo attach failure | Dive still saves; error surfaces as a snackbar |

## Testing

TDD; tests lead implementation.

- **Parser fixture tests (core asset).** Hand-built `OcrResult` fixtures
  (text + bounding boxes) modeled on five real sample pages: PADI
  handwritten imperial, PADI training metric, generic third-party,
  typewriter-boxed, Diving-For-Fun. Each with hand-transcribed expected
  `IncomingDiveData`. Adversarial variants: the `Certification No.` trap,
  `Bottom Time To Date` bleed, missing bottom time with Time In/Out
  present, `DD/MM` vs `MM/DD`, page-level unit inference flipping a bare
  `69` between feet and meters.
- **Normalizer unit tests.** `3K`, `10:00A`, `6 Feb '06`, `11.1m`, month
  names, two-digit years.
- **Engine contract tests.** `OcrEngine` mocked at the platform-channel
  boundary; native implementations kept thin enough that on-device
  golden-image checks are a manual smoke item per platform, not CI.
- **Widget test.** Flow delivers a prefilled `DiveEditPage` with photo
  attached and provenance set; blank-form fallback on empty OCR result.

Adding support for a new logbook brand starts by adding a fixture.

## Reference: sample pages

Five sample logbook pages informed the parsing rules (PADI blue template
with handwritten entries, PADI Open Water training page, a generic
third-party template, a typewriter-style boxed template, and a Diving For
Fun page). Key lessons encoded above: values sit above labels in PADI
Z-diagrams, unit checkboxes carry units OCR cannot read, shorthand like
`3K` and `10:00A` is common, and `Certification No.` collides with naive
"No." matching.
