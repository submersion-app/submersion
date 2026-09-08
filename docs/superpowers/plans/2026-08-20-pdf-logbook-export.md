# PDF Logbook Export Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Detailed PDF logbook actually detailed (one dive per page, a depth profile chart, and the full field list from issue #1017), fix unit handling and certification pagination across every template, delete the redundant Professional template, and route every PDF entry point through the same template system.

**Architecture:** Templates stay behind `PdfTemplateBuilder` and `PdfTemplateFactory`. A `UnitFormatter` is threaded into `buildPdf` the same way `PdfDateFormatter` was for #964. Depth profiles are loaded in batch by the export provider, downsampled to a bounded point count, and drawn as native PDF vector charts with the `pdf` package's own `Chart` widgets. The legacy duplicate builder inside `PdfExportService` is deleted and its two callers are routed through the factory.

**Tech Stack:** Flutter, Dart, `pdf` 3.13.0 (`pw.Chart`, `pw.LineDataSet`, `pw.CartesianGrid`, `pw.MultiPage`), Drift, Riverpod, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-20-pdf-logbook-export-design.md`

## Global Constraints

- **No em-dashes** (U+2014) in any output: code, comments, docs, commit messages. En-dashes as prose punctuation and spaced hyphens are equally forbidden. Hyphens inside compound words and CLI flags are fine.
- **No emojis** in code, comments, or documentation.
- **Units must follow the active diver's settings.** Never print a hardcoded `m`, `°C`, `bar`, `kg`, or `L`. Use `UnitFormatter`.
- **`dart format .`** must run clean after every task. Run it over the whole project, not just changed files.
- **`flutter analyze`** must be clean. Info-level diagnostics are fatal in CI.
- **Never pipe `flutter test` into `grep`/`tail`.** The pipeline returns the last command's exit status, so a failing run reads as exit 0. Run it bare and read the summary.
- **l10n changes must cover all 11 arb files** in `lib/l10n/arb/`.
- **Do not use `git stash`.** The stash stack is shared with other worktrees. Use a WIP commit instead.
- Work only inside the worktree at `.claude/worktrees/pdf-detailed-log-export`.

## File Structure

**Created:**
- `lib/core/services/pdf_templates/pdf_front_matter.dart` - diver information page absorbed from the deleted Professional template
- `lib/core/services/pdf_templates/pdf_profile_series.dart` - downsampled profile value object
- `lib/core/services/pdf_templates/pdf_profile_chart.dart` - vector depth-profile chart widget

**Modified:**
- `lib/core/constants/pdf_templates.dart` - remove `professional`, add `includeVerificationAreas`
- `lib/core/services/pdf_templates/pdf_template_builder.dart` - `units`, `profiles`, `diverPhoto`, `includeVerificationAreas` parameters
- `lib/core/services/pdf_templates/pdf_shared_components.dart` - unit-aware output, paginating certifications, enriched summary
- `lib/core/services/pdf_templates/pdf_template_detailed.dart` - full rebuild
- `lib/core/services/pdf_templates/pdf_template_simple.dart` - summary block, certifications, units
- `lib/core/services/pdf_templates/pdf_template_padi.dart` - units, certification pagination
- `lib/core/services/pdf_templates/pdf_template_naui.dart` - units, shared summary helper
- `lib/core/services/pdf_templates/pdf_template_factory.dart` - drop the Professional branch
- `lib/features/dive_log/data/repositories/dive_repository_impl.dart` - batch profile loading
- `lib/features/settings/presentation/providers/export_providers.dart` - pass units, profiles, diver photo
- `lib/features/transfer/presentation/widgets/pdf_export_dialog.dart` - verification-areas switch
- `lib/core/services/export/export_service.dart`, `lib/core/services/export/pdf/pdf_export_service.dart` - accept options, delete legacy builder
- `lib/features/dive_log/presentation/widgets/dive_list_content.dart`, `lib/features/dive_log/presentation/pages/dive_detail_page.dart` - template picker

**Deleted:**
- `lib/core/services/pdf_templates/pdf_template_professional.dart`

## Task Ordering Rationale

Professional's diver page is absorbed (Task 1) before Professional is deleted (Task 2), so nothing is lost. Units land (Task 3) after the deletion so no unit work is spent on a doomed file. The profile pipeline (Tasks 6 and 7) is built before the Detailed rebuild (Task 8) consumes it.

---

### Task 1: Absorb Professional's diver page into shared front matter

The Professional template owns the only diver information page in the app. It draws an empty 100x120 box literally labelled `'Photo'` and caps the certification list at five. Move it to a shared file, render the real portrait from `Diver.photoPath`, and remove the cap.

**Files:**
- Create: `lib/core/services/pdf_templates/pdf_front_matter.dart`
- Create: `test/core/services/pdf_templates/pdf_front_matter_test.dart`
- Modify: `lib/core/services/pdf_templates/pdf_template_professional.dart:53-66` (call the shared version)

**Interfaces:**
- Consumes: `PdfSharedComponents`, `Certification`, `Diver`, `PdfDateFormatter`, `certificationTitle`
- Produces:
  ```dart
  class PdfFrontMatter {
    static pw.Widget buildDiverPage({
      required Diver diver,
      required PdfDateFormatter dates,
      required int diveCount,
      List<Certification> certifications = const [],
      Uint8List? photoBytes,
      PdfColor accentColor = PdfColors.blue800,
    });
  }
  ```

- [ ] **Step 1: Write the failing test**

Create `test/core/services/pdf_templates/pdf_front_matter_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_front_matter.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/pdf_text.dart';

void main() {
  final dates = PdfDateFormatter(
    dateFormat: DateFormatPreference.ddmmyyyy,
    timeFormat: TimeFormat.twentyFourHour,
  );

  Certification cert(String name, {String? card}) => Certification(
    id: name,
    name: name,
    agency: CertificationAgency.padi,
    cardNumber: card,
    issueDate: DateTime(2020, 5, 1),
    createdAt: DateTime(2020, 5, 1),
    updatedAt: DateTime(2020, 5, 1),
  );

  Future<String> render(List<Certification> certs) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (context) => PdfFrontMatter.buildDiverPage(
          diver: Diver(
            id: 'd1',
            name: 'Ada Lovelace',
            createdAt: DateTime(2020, 1, 1),
            updatedAt: DateTime(2020, 1, 1),
          ),
          dates: dates,
          diveCount: 42,
          certifications: certs,
        ),
      ),
    );
    return pdfVisibleText(await doc.save());
  }

  test('renders the diver name and dive count', () async {
    final text = await render([cert('Open Water')]);
    expect(text, contains('Ada Lovelace'));
    expect(text, contains('42'));
  });

  test('renders every certification, not just the first five', () async {
    final certs = List.generate(8, (i) => cert('Course $i'));
    final text = await render(certs);
    for (var i = 0; i < 8; i++) {
      expect(text, contains('Course $i'), reason: 'certification $i missing');
    }
    expect(text, isNot(contains('more')));
  });
}
```

Adjust the `Diver` and `Certification` constructor arguments if the required fields differ; read the entity files first.

- [ ] **Step 2: Run the test and verify it fails**

Run: `flutter test test/core/services/pdf_templates/pdf_front_matter_test.dart`
Expected: FAIL, `pdf_front_matter.dart` does not exist.

- [ ] **Step 3: Create the shared front matter**

Create `lib/core/services/pdf_templates/pdf_front_matter.dart`. Port the body of `PdfTemplateProfessional._buildDiverProfilePage` (currently `pdf_template_professional.dart:213-323`) with three changes:

1. Replace the placeholder photo box at `:249-264` with a real image when `photoBytes` is non-null, falling back to the existing empty box when it is null:

```dart
photoBytes != null
    ? pw.Container(
        width: 100,
        height: 120,
        child: pw.Image(pw.MemoryImage(photoBytes), fit: pw.BoxFit.cover),
      )
    : pw.Container(
        width: 100,
        height: 120,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
        child: pw.Center(child: pw.Text('Photo', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500))),
      ),
```

2. Delete the `.take(5)` at `:279` and the `'... and N more'` block at `:315-317`. Map over the full list.
3. Add the card number to each entry when present, since #1017 asks for it:

```dart
if (cert.cardNumber != null) pw.Text('Card #: ${cert.cardNumber}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
```

- [ ] **Step 4: Point Professional at the shared version**

In `pdf_template_professional.dart:53-66`, replace the call to the private `_buildDiverProfilePage` with `PdfFrontMatter.buildDiverPage(...)` and delete the private method. This keeps the template green until Task 2 removes it.

- [ ] **Step 5: Run the tests and verify they pass**

Run: `flutter test test/core/services/pdf_templates/`
Expected: PASS, including the pre-existing template tests.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "refactor(export): move the diver page into shared front matter"
```

---

### Task 2: Delete the Professional template

**Files:**
- Delete: `lib/core/services/pdf_templates/pdf_template_professional.dart`
- Modify: `lib/core/constants/pdf_templates.dart` (enum case at `:10`, `divesPerPage` at `:48`, `supportsCertificationCards` at `:64`)
- Modify: `lib/core/services/pdf_templates/pdf_template_factory.dart:36-37`
- Modify: `lib/l10n/arb/*.arb` (11 files, keys `enum_pdfTemplate_professional` and `enum_pdfTemplate_professional_description`)
- Modify: any test referencing `PdfTemplateProfessional` (notably `test/core/services/pdf_templates/pdf_date_preference_test.dart:47` and `pdf_visibility_test.dart`)

**Interfaces:**
- Consumes: nothing new
- Produces: `PdfTemplate.values` with 4 entries: `simple`, `detailed`, `padiStyle`, `nauiStyle`

`PdfTemplate` is never persisted anywhere in the app, so there is no stored value that can fail to deserialize and no migration is required. This was verified before planning.

- [ ] **Step 1: Write the failing test**

Add to `test/core/services/pdf_templates/pdf_templates_test.dart`:

```dart
test('the professional template is gone', () {
  expect(PdfTemplate.values.map((t) => t.name), isNot(contains('professional')));
  expect(PdfTemplate.values, hasLength(4));
});
```

- [ ] **Step 2: Run it and verify it fails**

Run: `flutter test test/core/services/pdf_templates/pdf_templates_test.dart`
Expected: FAIL, `professional` is still present and there are 5 values.

- [ ] **Step 3: Remove the enum case and its switch branches**

In `lib/core/constants/pdf_templates.dart`, delete `professional` from the enum and its `case` in `displayName`, `description`, `divesPerPage` and `supportsCertificationCards`. Dart exhaustiveness checking will point at any switch you miss, so let `flutter analyze` guide you.

- [ ] **Step 4: Remove the factory branch and the file**

```bash
git rm lib/core/services/pdf_templates/pdf_template_professional.dart
```

Delete the `case PdfTemplate.professional:` branch and the now-unused import in `pdf_template_factory.dart`.

- [ ] **Step 5: Remove the l10n keys from all 11 locales**

For each file in `lib/l10n/arb/`, remove `enum_pdfTemplate_professional`, `enum_pdfTemplate_professional_description`, and any `@enum_pdfTemplate_professional*` metadata entries. Verify none remain:

```bash
grep -rn "pdfTemplate_professional" lib/l10n/arb/
```

Expected: no output. Then regenerate:

```bash
flutter gen-l10n
```

- [ ] **Step 6: Update tests that enumerate templates**

Remove the `'Professional': PdfTemplateProfessional.new` entry and its import from `pdf_date_preference_test.dart`, `pdf_visibility_test.dart`, and any other test that lists all builders. Delete any Professional-specific test file.

- [ ] **Step 7: Run the tests and verify they pass**

Run: `flutter test test/core/services/pdf_templates/`
Expected: PASS.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(export): remove the redundant Professional PDF template"
```

---

### Task 3: Thread UnitFormatter through every template

Nothing in `pdf_templates/` imports `unit_formatter.dart` today. Every depth, temperature and pressure is printed off the metric-base field with a literal suffix, and PADI prints cylinder pressures with no unit at all.

**Files:**
- Modify: `lib/core/services/pdf_templates/pdf_template_builder.dart:37-45`
- Modify: all four remaining templates and `pdf_shared_components.dart`
- Modify: `lib/features/settings/presentation/providers/export_providers.dart:342-353`
- Create: `test/core/services/pdf_templates/pdf_unit_preference_test.dart`
- Modify: every existing test that calls `buildPdf`

**Interfaces:**
- Consumes: `UnitFormatter` from `lib/core/utils/unit_formatter.dart`, constructed as `UnitFormatter(settings)`. Relevant methods: `formatDepth(double?, {int decimals = 1})`, `formatTemperature(double?, {int decimals = 1})`, `formatPressure(double?, {int decimals = 0})`, `formatWeight(double?, {int decimals = 1})`, `formatTankVolume(...)`, `depthSymbol`, `sacSymbol`.
- Produces: `buildPdf` gains `required UnitFormatter units`.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/pdf_templates/pdf_unit_preference_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_builder.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_naui.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_padi.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_simple.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../helpers/pdf_text.dart';

void main() {
  final dive = Dive(
    id: 'd1',
    diveNumber: 1,
    dateTime: DateTime(2026, 3, 28, 14, 30),
    runtime: const Duration(minutes: 50),
    maxDepth: 30.0,
    avgDepth: 18.0,
    waterTemp: 20.0,
    tanks: const [DiveTank(id: 't1', startPressure: 200, endPressure: 50)],
  );

  final dates = PdfDateFormatter(
    dateFormat: DateFormatPreference.ddmmyyyy,
    timeFormat: TimeFormat.twentyFourHour,
  );

  // Build the imperial and metric AppSettings the same way the existing
  // settings tests do; read test/helpers for an existing factory before
  // hand-rolling one.
  final imperial = UnitFormatter(imperialSettings());
  final metric = UnitFormatter(metricSettings());

  final builders = <String, PdfTemplateBuilder Function()>{
    'Simple': PdfTemplateSimple.new,
    'Detailed': PdfTemplateDetailed.new,
    'PADI': PdfTemplatePadi.new,
    'NAUI': PdfTemplateNaui.new,
  };

  Future<String> render(PdfTemplateBuilder b, UnitFormatter units) async =>
      pdfVisibleText(await b.buildPdf(
        dives: [dive],
        pageSize: PdfPageSize.a4,
        dates: dates,
        units: units,
      ));

  builders.forEach((name, make) {
    test('$name renders imperial depth for an imperial diver', () async {
      final text = await render(make(), imperial);
      expect(text, contains('ft'));
      expect(text, isNot(contains('30.0 m')));
    });

    test('$name renders metric depth for a metric diver', () async {
      final text = await render(make(), metric);
      expect(text, contains('m'));
      expect(text, isNot(contains('ft')));
    });
  });
}
```

Before writing this, look for an existing `AppSettings` test factory under `test/helpers/`. Reuse it rather than constructing `AppSettings` by hand.

- [ ] **Step 2: Run it and verify it fails**

Run: `flutter test test/core/services/pdf_templates/pdf_unit_preference_test.dart`
Expected: FAIL, `buildPdf` has no `units` parameter.

- [ ] **Step 3: Add the parameter to the base class**

In `pdf_template_builder.dart`, add `required UnitFormatter units,` to `buildPdf` and document it alongside the existing `dates` doc line.

- [ ] **Step 4: Sweep the hardcoded suffixes**

Replace in each template. The known sites, from the survey:

| File | Lines |
| --- | --- |
| `pdf_template_simple.dart` | 152 (`m`), 164 (`°C`) |
| `pdf_template_detailed.dart` | 153 (`m`), 163 (`°C`), 169 (`bar`) |
| `pdf_template_padi.dart` | 315 (`m`), 323 (`°C`), 342 (pressures with **no** unit), 338 |
| `pdf_template_naui.dart` | 173, 322, 326, 366 (`m`), 341, 345 (`bar`), 359 (`°C`) |
| `pdf_shared_components.dart` | 557, 558 (`m`) |

Pattern:

```dart
// before
'${dive.maxDepth?.toStringAsFixed(1) ?? '-'}m'
// after
units.formatDepth(dive.maxDepth)
```

`formatDepth`, `formatTemperature` and `formatPressure` already handle null by returning a placeholder, so the `?? '-'` fallbacks go away. Verify that behaviour by reading `unit_formatter.dart:22` before relying on it.

- [ ] **Step 5: Update the single production call site**

In `export_providers.dart`, inside `_buildLogbookPdfBytes`, the settings object is already read at `:337`. Add to the `builder.buildPdf(...)` call:

```dart
units: UnitFormatter(settings),
```

- [ ] **Step 6: Update every existing test that calls buildPdf**

`flutter analyze` will list them. Each needs `units: UnitFormatter(<settings>)` added.

- [ ] **Step 7: Verify no hardcoded suffixes remain**

```bash
grep -n "'m'\|°C\|'bar'\|}m'\|}°C'" lib/core/services/pdf_templates/*.dart
```

Expected: no matches other than inside `unit_formatter` calls or comments. Investigate anything that appears.

- [ ] **Step 8: Run the tests and verify they pass**

Run: `flutter test test/core/services/pdf_templates/ test/core/services/export/ test/features/settings/presentation/providers/export_pdf_logbook_test.dart`
Expected: PASS.

- [ ] **Step 9: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "fix(export): follow the diver's unit settings in PDF logbooks"
```

---

### Task 4: Paginate certifications and add the missing fields

`buildCertificationCardsPage` renders every certification with no cap, but all callers wrap it in a single `pw.Page`, so anything past one page is silently dropped. That is what #1017 reports as missing certifications.

**Files:**
- Modify: `lib/core/services/pdf_templates/pdf_shared_components.dart:241-283` and `_buildCertificationCard:285-466`
- Modify: `pdf_template_detailed.dart:64-76`, `pdf_template_padi.dart:56-70`, `pdf_template_naui.dart:54-68`
- Modify: `lib/core/constants/pdf_templates.dart` (`supportsCertificationCards` returns true for `simple`)
- Create: `test/core/services/pdf_templates/pdf_certification_pagination_test.dart`

**Interfaces:**
- Produces:
  ```dart
  // replaces buildCertificationCardsPage
  static List<pw.Widget> buildCertificationCardsBody({
    required List<Certification> certifications,
    required PdfDateFormatter dates,
    Diver? diver,
    String? highlightAgency,
    PdfColor accentColor = PdfColors.blue800,
  });
  ```
  Callers place the result as the `build` body of a `pw.MultiPage`.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/pdf_templates/pdf_certification_pagination_test.dart`:

```dart
test('a certification list longer than one page still renders the last card', () async {
  final certs = List.generate(
    24,
    (i) => Certification(
      id: 'c$i',
      name: 'Specialty $i',
      agency: CertificationAgency.padi,
      cardNumber: 'CARD-$i',
      issueDate: DateTime(2019, 1, 1),
      expiryDate: DateTime(2030, 1, 1),
      createdAt: DateTime(2019, 1, 1),
      updatedAt: DateTime(2019, 1, 1),
    ),
  );

  final bytes = await PdfTemplateDetailed().buildPdf(
    dives: [dive],
    pageSize: PdfPageSize.a4,
    dates: dates,
    units: metric,
    certifications: certs,
  );

  final text = pdfVisibleText(bytes);
  expect(text, contains('Specialty 0'));
  expect(text, contains('Specialty 23'), reason: 'last certification was dropped');
  expect(text, contains('CARD-23'));
});
```

- [ ] **Step 2: Run it and verify it fails**

Run: `flutter test test/core/services/pdf_templates/pdf_certification_pagination_test.dart`
Expected: FAIL, `Specialty 23` is absent because it overflowed the single page.

- [ ] **Step 3: Convert the renderer to a body list**

Rename `buildCertificationCardsPage` to `buildCertificationCardsBody` and change the return type from `pw.Widget` to `List<pw.Widget>`. Return the heading widget followed by the individual cards as separate list entries so `MultiPage` can break between them, rather than one `Wrap` that cannot split.

- [ ] **Step 4: Add expiry to the card**

In `_buildCertificationCard`, after the issue-date line at `:389-396`, add:

```dart
if (cert.expiryDate != null)
  pw.Text(
    'Expires: ${dates.date(cert.expiryDate!)}',
    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
  ),
```

- [ ] **Step 5: Switch every caller to MultiPage**

In Detailed, PADI and NAUI, replace:

```dart
pdf.addPage(pw.Page(pageFormat: pageFormat, build: (context) => PdfSharedComponents.buildCertificationCardsPage(...)));
```

with:

```dart
pdf.addPage(pw.MultiPage(
  pageFormat: pageFormat,
  margin: const pw.EdgeInsets.all(32),
  build: (context) => PdfSharedComponents.buildCertificationCardsBody(...),
));
```

- [ ] **Step 6: Enable certifications for Simple**

In `pdf_templates.dart`, `supportsCertificationCards` returns `true` for `PdfTemplate.simple`. The Simple template renders them in Task 9.

- [ ] **Step 7: Run the tests and verify they pass**

Run: `flutter test test/core/services/pdf_templates/`
Expected: PASS.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "fix(export): paginate certifications so none are dropped"
```

---

### Task 5: Enrich the shared summary page

#1017 asks for first dive, last dive and total dive time on both Detailed and Simple. `buildSummaryPage` has count, total time, deepest, average depth and unique sites, but no date range. NAUI recomputes its own aggregates inline and can drift.

**Files:**
- Modify: `lib/core/services/pdf_templates/pdf_shared_components.dart:517-565`
- Modify: `lib/core/services/pdf_templates/pdf_template_naui.dart:113-117, 166-173`
- Create: `test/core/services/pdf_templates/pdf_summary_page_test.dart`

**Interfaces:**
- Produces:
  ```dart
  static pw.Widget buildSummaryPage({
    required List<Dive> dives,
    required PdfDateFormatter dates,
    required UnitFormatter units,
    PdfColor accentColor = PdfColors.blue800,
  });
  ```
  Note the two new required parameters. Update the Detailed caller at `pdf_template_detailed.dart:58`.

- [ ] **Step 1: Write the failing test**

```dart
test('the summary reports the first and last dive dates and total time', () async {
  final dives = [
    diveOn(DateTime(2026, 8, 17), runtime: const Duration(minutes: 40)),
    diveOn(DateTime(2024, 1, 3), runtime: const Duration(minutes: 50)),
  ];

  final text = pdfVisibleText(await PdfTemplateDetailed().buildPdf(
    dives: dives,
    pageSize: PdfPageSize.a4,
    dates: dates,
    units: metric,
  ));

  expect(text, contains('First Dive'));
  expect(text, contains('03/01/2024'));
  expect(text, contains('Last Dive'));
  expect(text, contains('17/08/2026'));
  expect(text, contains('1h 30m'));
});
```

`dives` arrives newest-first from `getAllDives`, so first dive is `dives.last`. Do not assume sort order in the implementation; compute min and max explicitly.

- [ ] **Step 2: Run it and verify it fails**

Run: `flutter test test/core/services/pdf_templates/pdf_summary_page_test.dart`
Expected: FAIL, no `First Dive` row.

- [ ] **Step 3: Add the rows**

In `buildSummaryPage`, compute the range defensively and add two `buildStatRow` entries before the existing `Total Dive Time` row:

```dart
final sorted = dives.map((d) => d.dateTime).toList()..sort();
final firstDive = sorted.first;
final lastDive = sorted.last;
```

Then unit-format the depth rows at `:557-558` with `units.formatDepth(...)`.

- [ ] **Step 4: Point NAUI at the shared aggregates**

Replace the inline `totalRuntime` and `maxDepth` computation at `pdf_template_naui.dart:113-117` with the shared helpers, and unit-format the `'${maxDepth.toStringAsFixed(0)}m'` stat box at `:173`.

- [ ] **Step 5: Run the tests and verify they pass**

Run: `flutter test test/core/services/pdf_templates/`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(export): add the dive date range to the PDF summary"
```

---

### Task 6: Load dive profiles in batch for export

`getAllDives` skips profile hydration on purpose (`dive_repository_impl.dart:307-308`), so `dive.profile` is empty for every dive that reaches a template. The chart in Task 7 needs data.

**Do not use `getDiveProfile`.** It filters `isPrimary = true`, and per the #623 investigation `setPrimaryDataSource` can leave a file-imported dive with zero primary rows, so that query would render blank charts for exactly the dives imported from other logbooks. Mirror `getMergedProfile` instead, which keeps every source's rows and drops the originals a saved edit superseded.

**Files:**
- Create: `lib/core/services/pdf_templates/pdf_profile_series.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (add the batch method near `getMergedProfile` at `:4483`)
- Modify: the abstract repository interface that declares `getMergedProfile`
- Create: `test/core/services/pdf_templates/pdf_profile_series_test.dart`
- Create: `test/features/dive_log/data/repositories/batch_profile_load_test.dart`

**Interfaces:**
- Produces:
  ```dart
  // pdf_profile_series.dart
  class PdfProfileSeries {
    static const int maxPoints = 200;
    final List<DiveProfilePoint> points;
    const PdfProfileSeries(this.points);
    factory PdfProfileSeries.downsampled(List<DiveProfilePoint> raw);
    bool get isEmpty;
    double get maxDepth;
    int get durationSeconds;
  }

  // DiveRepository
  Future<Map<String, List<DiveProfilePoint>>> getMergedProfilesForDives(
    List<String> diveIds,
  );
  ```

- [ ] **Step 1: Write the failing downsample test**

Create `test/core/services/pdf_templates/pdf_profile_series_test.dart`:

```dart
void main() {
  DiveProfilePoint p(int t, double d) => DiveProfilePoint(timestamp: t, depth: d);

  test('leaves a short profile untouched', () {
    final raw = [p(0, 0), p(10, 5), p(20, 0)];
    expect(PdfProfileSeries.downsampled(raw).points, hasLength(3));
  });

  test('caps a long profile at maxPoints', () {
    final raw = List.generate(5000, (i) => p(i * 10, i % 30 + 1.0));
    final series = PdfProfileSeries.downsampled(raw);
    expect(series.points.length, lessThanOrEqualTo(PdfProfileSeries.maxPoints));
  });

  test('preserves the first sample, the last sample and the maximum depth', () {
    final raw = List.generate(5000, (i) => p(i * 10, i == 3111 ? 42.5 : 5.0));
    final series = PdfProfileSeries.downsampled(raw);
    expect(series.points.first.timestamp, 0);
    expect(series.points.last.timestamp, 49990);
    expect(series.maxDepth, 42.5);
    expect(series.points.map((e) => e.depth), contains(42.5),
        reason: 'the deepest sample must survive downsampling');
  });

  test('an empty profile reports isEmpty', () {
    expect(PdfProfileSeries.downsampled(const []).isEmpty, isTrue);
  });
}
```

The maximum-depth requirement matters: a naive "every Nth sample" downsample can drop the deepest point and make the chart lie about the dive. Bucket the samples and keep the deepest in each bucket, always retaining the first and last.

- [ ] **Step 2: Run it and verify it fails**

Run: `flutter test test/core/services/pdf_templates/pdf_profile_series_test.dart`
Expected: FAIL, the file does not exist.

- [ ] **Step 3: Implement PdfProfileSeries**

Bucketed downsample: split the sample list into at most `maxPoints` buckets and keep the deepest sample from each, preserving chronological order and always including the first and last raw samples.

- [ ] **Step 4: Write the failing batch-load test**

Create `test/features/dive_log/data/repositories/batch_profile_load_test.dart`. Follow the setup in the existing `edited_profile_supersedes_originals_test.dart`, which already builds an in-memory database with profile rows.

```dart
test('returns profiles for several dives in one call', () async {
  // insert profile rows for dive A and dive B
  final result = await repo.getMergedProfilesForDives(['diveA', 'diveB']);
  expect(result['diveA'], isNotEmpty);
  expect(result['diveB'], isNotEmpty);
});

test('returns rows for a dive whose samples are all non-primary', () async {
  // Insert profile rows for 'imported' with isPrimary: false on every row,
  // which is the file-import state described in issue #623.
  final result = await repo.getMergedProfilesForDives(['imported']);
  expect(result['imported'], isNotEmpty,
      reason: 'an isPrimary filter would silently drop file-imported dives');
});

test('drops the originals a saved edit superseded', () async {
  // Mirror the fixture from edited_profile_supersedes_originals_test.dart:
  // demoted originals plus promoted edited rows for the same dive.
  final result = await repo.getMergedProfilesForDives(['edited']);
  expect(result['edited'], hasLength(editedRowCount),
      reason: 'demoted originals must not be unioned back in');
});
```

- [ ] **Step 5: Run it and verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/batch_profile_load_test.dart`
Expected: FAIL, `getMergedProfilesForDives` is not defined.

- [ ] **Step 6: Implement the batch loader**

Add next to `getMergedProfile` (`:4483`). One query per chunk of ids, grouped by dive, then the existing per-dive rules applied to each group:

```dart
@override
Future<Map<String, List<domain.DiveProfilePoint>>> getMergedProfilesForDives(
  List<String> diveIds,
) async {
  const chunkSize = 50;
  final result = <String, List<domain.DiveProfilePoint>>{};

  for (var i = 0; i < diveIds.length; i += chunkSize) {
    final chunk = diveIds.skip(i).take(chunkSize).toList();
    final rows = await (_db.select(_db.diveProfiles)
          ..where((t) => t.diveId.isIn(chunk))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();

    final byDive = <String, List<DiveProfile>>{};
    for (final row in rows) {
      byDive.putIfAbsent(row.diveId, () => []).add(row);
    }

    for (final entry in byDive.entries) {
      final kept = await _dropSupersededOriginals(entry.key, entry.value);
      result[entry.key] =
          _dropDuplicateSamples(kept).map(_profilePointFromRow).toList();
    }
  }

  return result;
}
```

Declare it on the abstract repository as well. Chunking bounds both the `IN` clause size and peak memory.

- [ ] **Step 7: Run the tests and verify they pass**

Run: `flutter test test/features/dive_log/data/repositories/ test/core/services/pdf_templates/pdf_profile_series_test.dart`
Expected: PASS.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(export): batch-load merged dive profiles for PDF export"
```

---

### Task 7: Draw the depth profile as a vector chart

**Files:**
- Create: `lib/core/services/pdf_templates/pdf_profile_chart.dart`
- Create: `test/core/services/pdf_templates/pdf_profile_chart_test.dart`

**Interfaces:**
- Consumes: `PdfProfileSeries` from Task 6, `UnitFormatter`
- Produces:
  ```dart
  class PdfProfileChart {
    /// Returns null when [series] has no points, so callers omit the region
    /// entirely rather than printing an empty frame.
    static pw.Widget? build({
      required PdfProfileSeries series,
      required UnitFormatter units,
      double height = 150,
      PdfColor color = PdfColors.blue700,
    });
  }
  ```

Rasterizing the existing `dive_profile_chart.dart` through its `exportKey` `RepaintBoundary` was considered and rejected: `buildPdf` has no `BuildContext`, and `track_shape_painter.dart:10` documents that `toImage()` hangs under `flutter test`, which would make this untestable. The `pdf` package ships its own vector chart widgets.

- [ ] **Step 1: Write the failing test**

```dart
void main() {
  test('returns null for an empty series', () {
    expect(
      PdfProfileChart.build(series: const PdfProfileSeries([]), units: metric),
      isNull,
    );
  });

  test('renders a chart with depth axis labels for a real profile', () async {
    final series = PdfProfileSeries.downsampled([
      DiveProfilePoint(timestamp: 0, depth: 0),
      DiveProfilePoint(timestamp: 300, depth: 18.0),
      DiveProfilePoint(timestamp: 900, depth: 18.0),
      DiveProfilePoint(timestamp: 1500, depth: 0),
    ]);

    final doc = pw.Document();
    doc.addPage(pw.Page(
      build: (context) =>
          PdfProfileChart.build(series: series, units: metric)!,
    ));

    final bytes = await doc.save();
    expect(bytes, isNotEmpty);
    expect(pdfVisibleText(bytes), contains('18'));
  });
}
```

- [ ] **Step 2: Run it and verify it fails**

Run: `flutter test test/core/services/pdf_templates/pdf_profile_chart_test.dart`
Expected: FAIL, the file does not exist.

- [ ] **Step 3: Implement the chart**

Depth increases downward, so plot depth as a negative y value and label the axis with positive converted depths. Convert both axes through `units` so an imperial diver sees feet.

```dart
static pw.Widget? build({
  required PdfProfileSeries series,
  required UnitFormatter units,
  double height = 150,
  PdfColor color = PdfColors.blue700,
}) {
  if (series.isEmpty) return null;

  final data = series.points
      .map((p) => pw.PointChartValue(
            p.timestamp / 60.0,
            -units.convertDepth(p.depth),
          ))
      .toList();

  // Five evenly spaced depth ticks from the surface to the deepest sample,
  // negated because depth is plotted downward.
  final maxConverted = units.convertDepth(series.maxDepth);
  final depthStep = maxConverted / 4;
  final depthTicks = <double>[
    for (var i = 0; i <= 4; i++) -(depthStep * i),
  ];

  // A minute tick every 5 minutes for short dives, every 10 for longer ones,
  // so a 2 hour dive does not produce 24 crowded labels.
  final totalMinutes = series.durationSeconds / 60.0;
  final minuteStep = totalMinutes > 60 ? 10.0 : 5.0;
  final timeTicks = <double>[
    for (var t = 0.0; t <= totalMinutes; t += minuteStep) t,
  ];

  return pw.SizedBox(
    height: height,
    child: pw.Chart(
      grid: pw.CartesianGrid(
        xAxis: pw.FixedAxis(
          timeTicks,
          buildLabel: (v) => pw.Text(
            v.toStringAsFixed(0),
            style: const pw.TextStyle(fontSize: 7),
          ),
        ),
        yAxis: pw.FixedAxis(
          depthTicks,
          buildLabel: (v) => pw.Text(
            (-v).toStringAsFixed(0),
            style: const pw.TextStyle(fontSize: 7),
          ),
        ),
      ),
      datasets: [
        pw.LineDataSet(
          data: data,
          drawPoints: false,
          drawSurface: true,
          surfaceOpacity: 0.2,
          color: color,
          lineWidth: 1.0,
        ),
      ],
    ),
  );
}
```

Derive the tick lists from the series rather than hardcoding: roughly 5 depth ticks between 0 and max, and a minute tick every 5 or 10 minutes depending on duration. Read `~/.pub-cache/hosted/pub.dev/pdf-3.13.0/lib/src/widgets/chart/` for the exact axis API before finalising.

- [ ] **Step 4: Run the tests and verify they pass**

Run: `flutter test test/core/services/pdf_templates/pdf_profile_chart_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(export): draw dive profiles as vector charts in PDFs"
```

---

### Task 8: Rebuild the Detailed template

This is the task that fixes the reported bug. Today `_buildDiveEntry` renders 6 fields and truncates notes at `maxLines: 2`.

**Files:**
- Modify: `lib/core/services/pdf_templates/pdf_template_detailed.dart` (full rewrite of the dive page)
- Modify: `lib/core/services/pdf_templates/pdf_template_builder.dart` (add `profiles`, `diverPhoto`, `includeVerificationAreas`)
- Modify: `lib/core/constants/pdf_templates.dart` (`divesPerPage` for detailed becomes 1, add `includeVerificationAreas` to `PdfExportOptions`)
- Modify: `lib/features/settings/presentation/providers/export_providers.dart` (load profiles and the diver photo)
- Modify: `lib/features/transfer/presentation/widgets/pdf_export_dialog.dart` (verification-areas switch)
- Create: `test/core/services/pdf_templates/pdf_detailed_content_test.dart`

**Interfaces:**
- Consumes: `PdfProfileSeries`, `PdfProfileChart.build`, `PdfFrontMatter.buildDiverPage`, `UnitFormatter`
- Produces: final `buildPdf` signature, which every template implements:
  ```dart
  Future<List<int>> buildPdf({
    required List<Dive> dives,
    required PdfPageSize pageSize,
    required PdfDateFormatter dates,
    required UnitFormatter units,
    String title = 'Dive Logbook',
    Map<String, List<Signature>>? diveSignatures,
    List<Certification>? certifications,
    Diver? diver,
    Map<String, PdfProfileSeries>? profiles,
    Uint8List? diverPhoto,
    bool includeVerificationAreas = false,
  });
  ```

Field groups for the one-page layout, covering the #1017 checklist:

| Group | Fields |
| --- | --- |
| Header | dive number, site name, date, time, rating |
| Profile | the chart, max depth, average depth, runtime, entry and exit times, surface interval |
| Gas | every cylinder: name or preset, material, volume, gas mix O2 and He, start and end pressure, pressure used, per-cylinder SAC |
| Conditions | water temp, air temp, visibility, current direction and strength, water type, weather description, entry and exit method |
| Team | buddies with roles, dive master, dive center |
| Equipment | equipment items, weight amount and type, exposure suit |
| Technical | dive computer model, deco algorithm, gradient factors, dive mode, setpoints where present |
| Notes | full untruncated text |
| Sightings | marine life, when present |
| Verification | stamp area and large signature blocks, only when `includeVerificationAreas` |

Every group omits itself entirely when it has no data, so a manually logged dive does not print a page of empty labels.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/pdf_templates/pdf_detailed_content_test.dart`:

```dart
void main() {
  const longNote =
      'Dropped in from Devil Ray at Casique. Stayed on surface while Jack '
      'tied DSMB to a rock on the bottom as a marker. Backed off 100 yards, '
      'performed tired diver tow via push technique. Snorkel was flooding so '
      'switched to regulator and finished the tow on the surface.';

  final dive = Dive(
    id: 'd1',
    diveNumber: 197,
    dateTime: DateTime(2026, 8, 17, 11, 7),
    runtime: const Duration(minutes: 26),
    maxDepth: 9.8,
    avgDepth: 6.1,
    waterTemp: 28.0,
    airTemp: 31.0,
    notes: longNote,
    tanks: const [
      DiveTank(id: 't1', name: 'AL80', volume: 11.1, startPressure: 192, endPressure: 119),
      DiveTank(id: 't2', name: 'Deco 50', volume: 11.1, startPressure: 200, endPressure: 180),
    ],
  );

  // Shared render helper. Every test below goes through it so the parameter
  // list lives in one place.
  Future<List<int>> render(
    Dive d, {
    List<Dive> extra = const [],
    Map<String, PdfProfileSeries>? profiles,
    bool verification = false,
  }) =>
      PdfTemplateDetailed().buildPdf(
        dives: [d, ...extra],
        pageSize: PdfPageSize.a4,
        dates: dates,
        units: metric,
        profiles: profiles,
        includeVerificationAreas: verification,
      );

  final secondDive = dive.copyWith(id: 'd2', diveNumber: 198);
  final thirdDive = dive.copyWith(id: 'd3', diveNumber: 199);

  test('renders the notes in full, without truncation', () async {
    final text = pdfVisibleText(await render(dive));
    expect(text, contains('finished the tow on the surface'),
        reason: 'this is the reported bug: notes were capped at maxLines 2');
  });

  test('renders every cylinder, not only the first', () async {
    final text = pdfVisibleText(await render(dive));
    expect(text, contains('AL80'));
    expect(text, contains('Deco 50'));
  });

  test('renders average depth and air temperature', () async {
    final text = pdfVisibleText(await render(dive));
    expect(text, contains('6.1'));
    expect(text, contains('31'));
  });

  test('puts one dive on each page', () async {
    final bytes = await render(dive, extra: [secondDive, thirdDive]);
    expect(pdfPageCount(bytes), greaterThanOrEqualTo(3));
  });

  test('omits the profile section when the dive has no samples', () async {
    final text = pdfVisibleText(await render(dive));
    expect(text, isNot(contains('Depth Profile')));
  });

  test('renders the profile chart when samples are supplied', () async {
    final text = pdfVisibleText(await render(dive, profiles: {
      'd1': PdfProfileSeries.downsampled([
        DiveProfilePoint(timestamp: 0, depth: 0),
        DiveProfilePoint(timestamp: 600, depth: 9.8),
        DiveProfilePoint(timestamp: 1560, depth: 0),
      ]),
    }));
    expect(text, contains('Depth Profile'));
  });

  test('omits verification areas unless requested', () async {
    expect(pdfVisibleText(await render(dive)), isNot(contains('Official Stamp')));
    expect(
      pdfVisibleText(await render(dive, verification: true)),
      contains('Official Stamp'),
    );
  });
}
```

If `test/helpers/pdf_text.dart` has no page-count helper, add `int pdfPageCount(List<int> bytes)` there rather than inlining the parsing.

- [ ] **Step 2: Run it and verify it fails**

Run: `flutter test test/core/services/pdf_templates/pdf_detailed_content_test.dart`
Expected: FAIL. The notes assertion fails because of `maxLines: 2`, and the parameters do not exist yet.

- [ ] **Step 3: Extend the builder signature**

Add `profiles`, `diverPhoto` and `includeVerificationAreas` to `buildPdf` in `pdf_template_builder.dart` and to all four template implementations. Simple, PADI and NAUI accept and ignore them for now.

- [ ] **Step 4: Add the export option**

In `pdf_templates.dart`, add `includeVerificationAreas` to `PdfExportOptions` with a `false` default, and to `copyWith`, `operator ==` and `hashCode`. Set `divesPerPage` for `detailed` to 1.

- [ ] **Step 5: Rewrite the Detailed dive page**

Replace `_buildDiveEntry` with one `pw.MultiPage` per dive, or a `pw.Page` per dive with the groups laid out in two columns. Requirements:

- No `maxLines` on notes anywhere.
- Iterate `dive.tanks`, not `dive.tanks.first`.
- Each group returns null or an empty list when it has no data, and the layout filters those out.
- The profile section is headed `'Depth Profile'` and is included only when `profiles?[dive.id]` is non-null and not empty.
- Verification areas use the existing `PdfSharedComponents.buildStampArea` and `buildLargeSignatureBlock`.

- [ ] **Step 6: Load profiles and the diver photo in the provider**

In `_buildLogbookPdfBytes` in `export_providers.dart`, before building:

```dart
Map<String, PdfProfileSeries>? profiles;
if (exportOptions.template == PdfTemplate.detailed) {
  state = state.copyWith(message: _l10n.settings_export_progress_loadingProfiles);
  final raw = await _ref
      .read(diveRepositoryProvider)
      .getMergedProfilesForDives(dives.map((d) => d.id).toList());
  profiles = raw.map((id, pts) => MapEntry(id, PdfProfileSeries.downsampled(pts)));
}
```

Add the `settings_export_progress_loadingProfiles` string to all 11 arb files and run `flutter gen-l10n`. Load the diver portrait from `diver?.photoPath` with a guarded file read, passing null when the path is missing or unreadable. Do not let a missing photo fail the export.

- [ ] **Step 7: Add the dialog switch**

In `pdf_export_dialog.dart`, add a switch for verification areas next to the certification-cards switch, shown only for `PdfTemplate.detailed`, and include it in the `PdfExportOptions` built at `:307-315`.

- [ ] **Step 8: Run the tests and verify they pass**

Run: `flutter test test/core/services/pdf_templates/ test/features/settings/presentation/providers/export_pdf_logbook_test.dart`
Expected: PASS.

- [ ] **Step 9: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(export): rebuild the detailed logbook with full dive data (#1017)"
```

---

### Task 9: Give Simple its key metrics and certifications

#1017 reports that Simple is missing dive count, first dive, last dive, total dive time and max depth, and that certifications cannot be listed.

**Files:**
- Modify: `lib/core/services/pdf_templates/pdf_template_simple.dart`
- Create: `test/core/services/pdf_templates/pdf_simple_content_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('the simple logbook opens with the key metrics', () async {
  final text = pdfVisibleText(await PdfTemplateSimple().buildPdf(
    dives: dives,
    pageSize: PdfPageSize.a4,
    dates: dates,
    units: metric,
  ));
  expect(text, contains('Total Dives'));
  expect(text, contains('First Dive'));
  expect(text, contains('Last Dive'));
  expect(text, contains('Total Dive Time'));
  expect(text, contains('Deepest Dive'));
});

test('the simple logbook lists certifications when supplied', () async {
  final text = pdfVisibleText(await PdfTemplateSimple().buildPdf(
    dives: dives,
    pageSize: PdfPageSize.a4,
    dates: dates,
    units: metric,
    certifications: [openWaterCert],
  ));
  expect(text, contains('Open Water'));
  expect(text, contains('CARD-1'));
});
```

- [ ] **Step 2: Run it and verify it fails**

Run: `flutter test test/core/services/pdf_templates/pdf_simple_content_test.dart`
Expected: FAIL, Simple renders neither.

- [ ] **Step 3: Add the summary block**

Prepend a summary page using `PdfSharedComponents.buildSummaryPage(dives: dives, dates: dates, units: units)` before the table pages. Keep the compact table itself unchanged; Simple stays the dense option.

- [ ] **Step 4: Add the certification pages**

Append a `pw.MultiPage` using `buildCertificationCardsBody` when `certifications` is non-null and non-empty, matching the pattern from Task 4.

- [ ] **Step 5: Run the tests and verify they pass**

Run: `flutter test test/core/services/pdf_templates/`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(export): add key metrics and certifications to the simple logbook"
```

---

### Task 10: Route the remaining exports through the factory

The dive-list bulk export and the single-dive export never see a template and use a duplicated copy of the old layout that hardcodes A4 and builds `pw.Document()` with no Unicode font, so accented site names are mangled today.

**Files:**
- Modify: `lib/core/services/export/pdf/pdf_export_service.dart` (delete `_buildDivePdf:233-370`, `_buildPdfDiveEntry:393+`, `_buildPdfStatRow:374`, `_buildPdfInfoChip:593`, `_buildPdfSignatureBlock:528`)
- Modify: `lib/core/services/export/export_service.dart:101-131`
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart:600-610`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:2969-2975`
- Modify: `test/features/dive_log/presentation/widgets/dive_list_bulk_export_test.dart`, `test/core/services/export/pdf/pdf_export_service_test.dart`

**Interfaces:**
- Consumes: `PdfTemplateFactory`, `PdfExportOptions`, `UnitFormatter`, the full `buildPdf` signature from Task 8
- Produces:
  ```dart
  Future<({List<int> bytes, String fileName})> generateDivePdfBytes(
    List<Dive> dives, {
    required PdfDateFormatter dates,
    required UnitFormatter units,
    PdfExportOptions options = const PdfExportOptions(),
    Map<String, List<Signature>>? diveSignatures,
  });
  ```

`exportTripToPdf` and `pdf_course_export_service.dart` are out of scope. They are separate documents with their own layouts and keep their current builders.

- [ ] **Step 1: Write the failing test**

```dart
test('bulk export honours the selected template', () async {
  final simple = await service.generateDivePdfBytes(
    dives,
    dates: dates,
    units: metric,
    options: const PdfExportOptions(template: PdfTemplate.simple),
  );
  final detailed = await service.generateDivePdfBytes(
    dives,
    dates: dates,
    units: metric,
    options: const PdfExportOptions(template: PdfTemplate.detailed),
  );
  expect(pdfVisibleText(simple.bytes), isNot(pdfVisibleText(detailed.bytes)));
});

test('the legacy single-layout builder is gone', () async {
  // The legacy builder emitted no summary page. Every template does now.
  final result = await service.generateDivePdfBytes(
    dives,
    dates: dates,
    units: metric,
    options: const PdfExportOptions(template: PdfTemplate.detailed),
  );
  expect(pdfVisibleText(result.bytes), contains('Total Dives'));
});

test('renders a Unicode site name correctly', () async {
  final result = await service.generateDivePdfBytes(
    [diveAtSite('Café Réunion')],
    dates: dates,
    units: metric,
  );
  expect(pdfVisibleText(result.bytes), contains('Café Réunion'));
});
```

The Unicode test is the regression guard for the missing `PdfFonts.instance.theme` in the deleted builder.

- [ ] **Step 2: Run it and verify it fails**

Run: `flutter test test/core/services/export/pdf/pdf_export_service_test.dart`
Expected: FAIL, `generateDivePdfBytes` takes no `options`.

- [ ] **Step 3: Route the service through the factory**

Replace the body of `generateDivePdfBytes` with a factory lookup, mirroring `_buildLogbookPdfBytes`. Call `await PdfFonts.instance.initialize()` before building, which the legacy path never did. Thread `options` through `exportDivesToPdf` and `saveDivesToPdfFile`, and through the matching methods on `ExportService`.

- [ ] **Step 4: Delete the legacy builder**

Remove `_buildDivePdf`, `_buildPdfDiveEntry`, `_buildPdfStatRow`, `_buildPdfInfoChip` and `_buildPdfSignatureBlock`. Keep `savePdfBytesToFile`, `sharePdfBytes` and the trip export, which are still used. Confirm nothing else references the removed methods:

```bash
grep -rn "_buildPdfDiveEntry\|_buildDivePdf" lib test
```

Expected: no output.

- [ ] **Step 5: Add the picker to both call sites**

In `dive_list_content.dart`, when the chosen format is PDF, show `PdfExportDialog.show(context)` and pass the returned options through. A null return means the user cancelled, so abort the export without an error. In `dive_detail_page.dart`, do the same for the single-dive sheet.

Both sites need `UnitFormatter(ref.read(settingsProvider))`, which they can read the same way they already read `settingsProvider` for `PdfDateFormatter`.

- [ ] **Step 6: Run the full PDF and export suites**

Run: `flutter test test/core/services/export/ test/core/services/pdf_templates/ test/features/dive_log/presentation/widgets/dive_list_bulk_export_test.dart test/features/settings/presentation/providers/export_pdf_logbook_test.dart`
Expected: PASS.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "fix(export): route every PDF export through the template system"
```

---

### Task 11: Full verification

- [ ] **Step 1: Run the whole suite twice**

```bash
flutter test
flutter test
```

Run it bare, never piped into `grep` or `tail`, because a pipeline returns the last command's status and a failing run would read as exit 0. Run it twice: disjoint failure sets across the two runs indicate a pre-existing flake rather than a regression from this work. Known pre-existing flakes are recorded in the project memory index and should not be chased here. Do not start a second run while one is in flight.

- [ ] **Step 2: Verify the reported bug is actually fixed**

Export a Detailed PDF from the Transfer page with a dive whose notes run past two lines, and confirm the notes are complete, the profile chart is present, and every cylinder appears.

- [ ] **Step 3: Confirm the l10n sweep is complete**

```bash
grep -rn "pdfTemplate_professional" lib/
```

Expected: no output.

- [ ] **Step 4: Format and analyze the whole project**

```bash
dart format .
flutter analyze
```

- [ ] **Step 5: Commit any remaining formatting**

```bash
git add -A
git commit -m "chore(export): formatting after the PDF logbook rework"
```
