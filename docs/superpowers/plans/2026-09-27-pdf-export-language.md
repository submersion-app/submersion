# PDF Export Language Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every generated PDF prints in a chosen language (issue #2252). The logbook export sheet gets a language picker that defaults to the app language, and every other PDF follows the app language.

**Architecture:** A new `PdfLocalization` value object carries the language code, its `AppLocalizations`, and the text direction. `PdfFonts.themeFor(localization)` adds a Noto fallback font for Arabic, Hebrew and Chinese. Every PDF builder takes a `PdfLocalization`, reads its strings from `pdf_*` ARB keys, prints enums through the existing `localizedName(l10n)` helpers, and sets `textDirection` on every page.

**Tech Stack:** Flutter, `pdf` 3.13 (`pw.ThemeData.withFont(fontFallback:)`, `pw.Page(textDirection:)`, Arabic shaping only on RTL pages), `printing` (`PdfGoogleFonts.notoSans*`), gen-l10n ARB files.

**Spec:** GitHub issue #2252 plus the maintainer's four decisions from 2026-09-27:
1. A language picker in the PDF export sheet that defaults to the app language and lists every supported language.
2. All PDF exports are in scope: the logbook templates, trip, course training log, planner slate, passport labels and blender invoice.
3. Full non-Latin support: Noto fallback fonts for ar/he/zh, and RTL layout for ar/he.
4. PDFs other than the logbook follow the app language, with no new picker.

## Global Constraints

- No em-dashes anywhere (code, comments, ARB values, commits, PR text).
- English output must stay byte-for-byte what it is today, so the existing English assertions in `test/core/services/pdf_templates/` keep passing unchanged. Where two templates print the same idea differently today ("Generated on" vs "Generated", "45min" vs "45 min"), keep separate keys rather than unifying them.
- The enum `displayName` values stay English on purpose (data interchange). PDFs switch to the existing `localizedName(l10n)` extensions and never change `displayName`.
- ARB edits: insert new lines by anchor into every ARB file, and never round-trip a file through JSON (see memory `project_l10n_translate_all_locales`). Locale files need no `@meta`. `app_en.arb` needs `@meta` with placeholders. Plural keys use `one{...}`, never `=1{...}` with a literal digit.
- Paths are built with `p.join`, and temp space is reached through `Directory.systemTemp`.
- A PDF builder never touches `BuildContext`. The language is resolved by the caller and passed in.
- Tests must not download fonts. The non-Latin fallback loader has a `@visibleForTesting` override.

## Review Focus

1. **English output drifting.** A key typo or a unified string changes what an English user already gets. The existing English tests pin this and must pass untouched.
2. **An unsupported or null language code.** `PdfLocalization.forLanguageCode(null)`, `'xx'` and `'pt_BR'` must resolve to a supported language (English, English, Portuguese), never throw.
3. **Offline export in ar/he/zh.** If the Noto download fails, the export must still complete, with the characters missing, exactly like today's Roboto fallback. It must never throw.
4. **RTL pages throwing.** A page with `textDirection: rtl` has to lay out every template without a "won't fit" or assertion error.
5. **A picker default the list doesn't contain.** An app locale outside the list (the system resolved to an unsupported language) must default the picker to English, not crash the dropdown.

---

### Task 1: PdfLocalization, font fallback and the options field

**Files:**
- Create: `lib/core/services/pdf_templates/pdf_localization.dart`
- Modify: `lib/core/services/pdf_templates/pdf_fonts.dart`
- Modify: `lib/core/constants/pdf_templates.dart` (`PdfExportOptions` gains `languageCode`)
- Test: `test/core/services/pdf_templates/pdf_localization_test.dart`

**Interfaces:**
- Produces:
  - `class PdfLocalization { factory PdfLocalization.forLanguageCode(String? code); factory PdfLocalization.english(); String get languageCode; AppLocalizations get l10n; bool get isRtl; pw.TextDirection get textDirection; }`
  - `Future<pw.ThemeData> PdfFonts.themeFor(PdfLocalization localization)`
  - `@visibleForTesting static Future<pw.Font?> Function(String languageCode)? PdfFonts.debugFallbackLoader`
  - `PdfExportOptions.languageCode` (a nullable `String`, where null means "the caller's app language")

- [ ] **Step 1: Write the failing tests**

```dart
test('unsupported and null codes fall back to English', () {
  expect(PdfLocalization.forLanguageCode(null).languageCode, 'en');
  expect(PdfLocalization.forLanguageCode('xx').languageCode, 'en');
});
test('a region suffix resolves to its language', () {
  expect(PdfLocalization.forLanguageCode('pt_BR').languageCode, 'pt');
});
test('French reads French strings', () {
  expect(PdfLocalization.forLanguageCode('fr').l10n.localeName, 'fr');
});
test('Arabic and Hebrew are right to left', () {
  expect(PdfLocalization.forLanguageCode('ar').textDirection, pw.TextDirection.rtl);
  expect(PdfLocalization.forLanguageCode('he').isRtl, isTrue);
  expect(PdfLocalization.forLanguageCode('fr').textDirection, pw.TextDirection.ltr);
});
test('themeFor adds a fallback only for non-Latin scripts', () async {
  final requested = <String>[];
  PdfFonts.debugFallbackLoader = (code) async { requested.add(code); return null; };
  addTearDown(() => PdfFonts.debugFallbackLoader = null);
  await PdfFonts.instance.themeFor(PdfLocalization.forLanguageCode('fr'));
  await PdfFonts.instance.themeFor(PdfLocalization.forLanguageCode('zh'));
  expect(requested, ['zh']);
});
test('a failing fallback download still yields a theme', () async {
  PdfFonts.debugFallbackLoader = (_) async => throw Exception('offline');
  addTearDown(() => PdfFonts.debugFallbackLoader = null);
  expect(await PdfFonts.instance.themeFor(PdfLocalization.forLanguageCode('ar')), isNotNull);
});
test('PdfExportOptions carries languageCode through copyWith and equality', () {
  const a = PdfExportOptions(languageCode: 'fr');
  expect(a.copyWith().languageCode, 'fr');
  expect(a == const PdfExportOptions(languageCode: 'de'), isFalse);
});
```

- [ ] **Step 2: Run `flutter test test/core/services/pdf_templates/pdf_localization_test.dart`.** Expected: a compile failure, because nothing exists yet.

- [ ] **Step 3: Implement.** `pdf_localization.dart`:

```dart
class PdfLocalization {
  PdfLocalization._(this.languageCode, this.l10n);

  factory PdfLocalization.forLanguageCode(String? code) {
    final language = (code ?? 'en').split(RegExp('[-_]')).first.toLowerCase();
    final supported = AppLocalizations.supportedLocales
        .any((l) => l.languageCode == language);
    final resolved = supported ? language : 'en';
    return PdfLocalization._(resolved, lookupAppLocalizations(Locale(resolved)));
  }

  factory PdfLocalization.english() => PdfLocalization.forLanguageCode('en');

  final String languageCode;
  final AppLocalizations l10n;

  bool get isRtl => Bidi.isRtlLanguage(languageCode);
  pw.TextDirection get textDirection =>
      isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
}
```

`PdfFonts.themeFor` keeps today's base-font behaviour. It must not call `initialize()`, because the tests rely on Helvetica for text extraction. It adds `fontFallback: [font]` when `_fallbackFor(languageCode)` returns a font. `_fallbackFor` maps `ar` to `PdfGoogleFonts.notoSansArabicRegular`, `he` to `notoSansHebrewRegular` and `zh` to `notoSansSCRegular`, caches the result per code, and returns null on any error. `debugFallbackLoader` replaces the download when it is set. Also add `languageCode` to `PdfExportOptions` (constructor, `copyWith`, `==`, `hashCode`, `toString`).

- [ ] **Step 4: Run the test file.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(pdf): add PdfLocalization and a non-Latin font fallback (#2252)`.

### Task 2: English ARB keys for every PDF string

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (a new block of `pdf_*` keys inserted by anchor, plus `transfer_pdfExport_languageHeader`)
- Generated: `lib/l10n/arb/app_localizations*.dart` (`flutter gen-l10n`)

Keys and English values. Every value must equal today's literal.

| Key | English |
| --- | --- |
| pdf_unknownSite | Unknown Site |
| pdf_signaturePlaceholder | [Signature] |
| pdf_signerBuddy | Buddy |
| pdf_signerInstructor | Instructor |
| pdf_officialStamp | Official Stamp |
| pdf_certifications | Certifications |
| pdf_cardNumber | Card #: {number} |
| pdf_certIssued | Issued: {date} |
| pdf_certExpires | Expires: {date} |
| pdf_cardFront | Front |
| pdf_cardBack | Back |
| pdf_coverDiveCount | {count, plural, one{{count} Dive} other{{count} Dives}} |
| pdf_headerDiveCount | {count, plural, one{{count} dive} other{{count} dives}} |
| pdf_generatedOn | Generated on {dateTime} |
| pdf_generated | Generated {dateTime} |
| pdf_noDivesToSummarize | No dives to summarize |
| pdf_noDivesToDisplay | No dives to display |
| pdf_summary | Summary |
| pdf_totalDives | Total Dives |
| pdf_firstDive | First Dive |
| pdf_lastDive | Last Dive |
| pdf_totalDiveTime | Total Dive Time |
| pdf_deepestDive | Deepest Dive |
| pdf_averageDepth | Average Depth |
| pdf_uniqueSites | Unique Sites |
| pdf_hoursMinutes | {hours}h {minutes}m |
| pdf_minutesShort | {minutes}m |
| pdf_minutes | {minutes} min |
| pdf_minutesCompact | {minutes}min |
| pdf_diverProfile | Diver Profile |
| pdf_name | Name |
| pdf_email | Email |
| pdf_photo | Photo |
| pdf_depthProfileHeading | Depth Profile ({depthUnit} vs min) |
| pdf_columnDate | Date |
| pdf_columnSite | Site |
| pdf_columnDepth | Depth |
| pdf_columnTime | Time |
| pdf_columnTemp | Temp |
| pdf_pageOf | Page {page} of {total} |
| pdf_sectionProfile | Profile |
| pdf_sectionCylinders | Cylinders |
| pdf_sectionConditions | Conditions |
| pdf_sectionWeather | Weather |
| pdf_sectionTeam | Team |
| pdf_sectionEquipment | Equipment |
| pdf_sectionTechnical | Technical |
| pdf_sectionMarineLife | Marine Life |
| pdf_sectionNotes | Notes |
| pdf_sectionAdditionalFields | Additional Fields |
| pdf_sectionVerifiedBy | Verified By |
| pdf_sectionVerification | Verification |
| pdf_maxDepth | Max Depth |
| pdf_avgDepth | Avg Depth |
| pdf_runtime | Runtime |
| pdf_bottomTime | Bottom Time |
| pdf_timeIn | In |
| pdf_timeOut | Out |
| pdf_surfaceInterval | Surface Interval |
| pdf_sac | SAC |
| pdf_rmv | RMV |
| pdf_pressureUsed | {pressure} used |
| pdf_cylinderNumber | Cylinder {number} |
| pdf_waterTemp | Water Temp |
| pdf_airTemp | Air Temp |
| pdf_visibility | Visibility |
| pdf_current | Current |
| pdf_currentDirection | Current Dir |
| pdf_waterType | Water Type |
| pdf_entry | Entry |
| pdf_exit | Exit |
| pdf_altitude | Altitude |
| pdf_buddy | Buddy |
| pdf_diveMaster | Dive Master |
| pdf_diveCenter | Dive Center |
| pdf_trip | Trip |
| pdf_weight | Weight |
| pdf_weightType | Weight Type |
| pdf_equipmentSets | {count, plural, one{Set} other{Sets}} |
| pdf_computer | Computer |
| pdf_diveMode | Dive Mode |
| pdf_algorithm | Algorithm |
| pdf_gradientFactors | Gradient Factors |
| pdf_setpoint | Setpoint |
| pdf_diveType | Dive Type |
| pdf_weatherConditions | Conditions |
| pdf_wind | Wind |
| pdf_windDirection | Wind Dir |
| pdf_cloud | Cloud |
| pdf_precipitation | Precipitation |
| pdf_humidity | Humidity |
| pdf_swell | Swell |
| pdf_instructorSignature | Instructor Signature |
| pdf_buddySignature | Buddy Signature |
| pdf_diveLogBanner | DIVE LOG |
| pdf_loggedDives | Logged Dives |
| pdf_diveNumber | Dive #{number} |
| pdf_trainingBadge | TRAINING |
| pdf_gas | Gas |
| pdf_visibilityShort | Vis |
| pdf_air | Air |
| pdf_water | Water |
| pdf_verifiedBy | Verified by |
| pdf_nauiDiveLogBanner | NAUI DIVE LOG |
| pdf_statDives | Dives |
| pdf_statHours | Hours |
| pdf_avgShort | Avg |
| pdf_pressureStart | Start |
| pdf_pressureEnd | End |
| pdf_surfaceIntervalShort | SI: {minutes}min |
| pdf_diveDataHeading | DIVE DATA |
| pdf_verificationHeading | VERIFICATION |
| pdf_labelValue | {label}: {value} |
| pdf_resort | Resort |
| pdf_liveaboard | Liveaboard |
| pdf_totalRuntime | Total Runtime |
| pdf_tripDiveTitle | Dive {number} |
| pdf_date | Date |
| pdf_site | Site |
| pdf_duration | Duration |
| pdf_notesLabel | Notes: |
| pdf_trainingLog | Training Log |
| pdf_instructor | Instructor |
| pdf_instructorNumber | Instructor # |
| pdf_location | Location |
| pdf_startDate | Start Date |
| pdf_completionDate | Completion Date |
| pdf_status | Status |
| pdf_statusCompleted | Completed |
| pdf_statusInProgress | In Progress |
| pdf_trainingDives | Training Dives |
| pdf_totalMinutes | Total Minutes |
| pdf_courseNotes | Course Notes |
| pdf_slateMax | max |
| transfer_pdfExport_languageHeader | Language |

`pdf_labelValue` exists so French typography ("Site : X") is the translator's choice rather than a hardcoded `': '`. English stays "Site: X". The trip page's `Dive ${dive.diveNumber ?? ""}` keeps its trailing space when the number is missing (`pdf_tripDiveTitle` with `number: ''`).

- [ ] **Step 1:** Insert the keys into `app_en.arb` by anchor, with `@meta` placeholders (`count` as `int`, everything else as `String`).
- [ ] **Step 2:** Run `flutter gen-l10n`. Expected: it generates cleanly, and the untranslated count rises by the new keys × 10.
- [ ] **Step 3: Commit** `feat(l10n): add PDF export strings (#2252)`.

### Task 3: Localize the shared pieces and the four logbook templates

**Files:**
- Modify: `pdf_shared_components.dart`, `pdf_front_matter.dart`, `pdf_profile_chart.dart`, `pdf_template_builder.dart`, `pdf_template_simple.dart`, `pdf_template_detailed.dart`, `pdf_template_padi.dart`, `pdf_template_naui.dart`
- Test: `test/core/services/pdf_templates/pdf_template_language_test.dart` (new)

**Interfaces:**
- Consumes: Task 1 `PdfLocalization`, `PdfFonts.themeFor`; Task 2 keys.
- Produces: `PdfTemplateBuilder.buildPdf({..., PdfLocalization? localization})`, where null means English. Every static shared builder gains `required AppLocalizations l10n`: `buildSignatureBlock`, `buildCertificationCardsBody`, `buildCoverPage`, `buildSummaryPage`, `PdfFrontMatter.buildDiverPageBody`/`buildDiverPage`, `PdfProfileChart.build`. `buildLargeSignatureBlock` and `buildStampArea` make `label` required.

Enum mapping (each helper already exists, `localizedName(l10n)`):
`TankMaterial`, `TankRole`, `DiveMode` (`tank_enum_display.dart`); `CurrentStrength`, `CurrentDirection` (also used for wind), `WaterType`, `EntryMethod` (used for entry and exit), `CloudCover`, `Precipitation` (`environment_enum_display.dart`); `WeightType` (`weight_enum_display.dart`); `EquipmentType` (`equipment_enum_display.dart`, including the `arrangeEquipment` `typeLabel`); `DiveRole` (`dive_role_display.dart`, replacing the raw `buddy.role.name`); `CertificationAgency` (`certification_agency_display.dart`); `Visibility` via `visibilityName(v, l10n)` (`visibility_display.dart`).

- [ ] **Step 1: Write the failing tests.** For each template, render with `PdfLocalization.forLanguageCode('fr')` and assert on French labels with `pdfVisibleText` (Helvetica, since PdfFonts is not initialized). For example, Simple contains `l10n.pdf_totalDives` for fr and does not contain `'Total Dives'`. Detailed contains the fr `pdf_maxDepth`, and the fr `enum_currentStrength_strong` for a dive with strong current. PADI contains the fr `pdf_loggedDives`. NAUI contains the fr `pdf_statHours`. Read the expected strings from `lookupAppLocalizations(const Locale('fr'))` so the test does not duplicate translations. Add a smoke test: every template renders `ar`, `he` and `zh` with `PdfFonts.debugFallbackLoader = (_) async => null` without throwing and with `pdfPageCount > 0`.
- [ ] **Step 2: Run the test.** Expected: a compile failure on the `localization` parameter.
- [ ] **Step 3: Implement.** In each template: `final loc = localization ?? PdfLocalization.english(); final l10n = loc.l10n;`, `pw.Document(theme: await PdfFonts.instance.themeFor(loc))`, `textDirection: loc.textDirection` on every `pw.Page`/`pw.MultiPage`, and replace every literal from Task 2's table. Drop the detailed template's comment at `_equipmentFields` that says it has no AppLocalizations in scope.
- [ ] **Step 4: Run** `flutter test test/core/services/pdf_templates/ test/core/services/pdf_equipment_arrangement_test.dart`. Expected: the new tests and every existing English test PASS. Existing call sites compile because `localization` is optional; the shared static builders' callers are updated in this task.
- [ ] **Step 5: Commit** `feat(pdf): print the logbook templates in the chosen language (#2252)`.

### Task 4: Language picker and logbook call sites

**Files:**
- Modify: `lib/features/transfer/presentation/widgets/pdf_export_dialog.dart` (the Language section)
- Modify: `lib/features/settings/presentation/providers/export_providers.dart` (`_buildLogbookPdfBytes`)
- Modify: `lib/core/services/export/pdf/pdf_export_service.dart` (`generateDivePdfBytes`, `exportDivesToPdf`, `saveDivesToPdfFile`), `lib/core/services/export/export_service.dart` wrappers
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`, `lib/features/dive_log/presentation/widgets/dive_list_content.dart`
- Test: `test/features/transfer/presentation/widgets/pdf_export_dialog_language_test.dart` (new), plus an assertion in `test/features/settings/presentation/providers/export_pdf_logbook_test.dart`

**Interfaces:**
- Consumes: `PdfExportOptions.languageCode`, `PdfLocalization.forLanguageCode`.
- Produces: the dialog always returns options whose `languageCode` is set. `PdfExportService.generateDivePdfBytes({..., PdfLocalization? localization})` resolves its title from `localization.l10n.settings_export_pdfDocumentTitle` when no title is passed.

- [ ] **Step 1: Write the failing widget tests.** The dialog, pumped under `locale: Locale('fr')`, shows a Language dropdown whose value is `Français`. Choosing `Deutsch` and tapping Export pops options with `languageCode == 'de'`. Under an unsupported locale the dropdown defaults to English. The provider test: `exportDivesToPdf(PdfExportOptions(languageCode: 'fr'))` passes a French title (`settings_export_pdfDocumentTitle` in fr) to the builder.
- [ ] **Step 2: Run the tests.** Expected: FAIL.
- [ ] **Step 3: Implement.** The dialog holds `String _languageCode`, initialised in `didChangeDependencies` from `Localizations.localeOf(context).languageCode` (English if unsupported). It shows a `DropdownButtonFormField<String>` built from `LanguageSettingsPage.supportedLocales` minus `system`, each entry labelled with `nativeName`, under the header `transfer_pdfExport_languageHeader`, placed after Page Size. `_exportPdf` sets `languageCode`. The provider uses `PdfLocalization.forLanguageCode(options.languageCode ?? _l10n.localeName)` and passes `localization` plus `title: localization.l10n.settings_export_pdfDocumentTitle`. The dive detail page and dive list pass `PdfLocalization.forLanguageCode(options.languageCode ?? Localizations.localeOf(context).languageCode)`.
- [ ] **Step 4: Run the tests** plus `test/features/dive_log/presentation/pages/dive_detail_export_test.dart`, `test/features/dive_log/presentation/widgets/dive_list_bulk_export_test.dart` and `test/core/services/export/pdf/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(pdf): choose the logbook language in the export sheet (#2252)`.

### Task 5: Trip, course, blender, slate and passport PDFs follow the app language

**Files:**
- Modify: `pdf_export_service.dart` (`exportTripToPdf({..., PdfLocalization? localization})`), `pdf_course_export_service.dart` (`exportCourseTrainingLogToPdf({..., required PdfLocalization localization})`, reusing `PdfSharedComponents.buildSignatureBlock` in place of its private copy), `export_service.dart` wrappers
- Modify: `lib/features/courses/presentation/pages/course_detail_page.dart` (passes the app language)
- Modify: `lib/core/services/export/models/blender_invoice_export_data.dart` (adds `totalLabel`, `incompleteNote`, `languageCode`), `blender_invoice_pdf_export_service.dart`, `blender_invoice_card.dart` (fills them from `gasCalculators_blender_billedTotal` / `gasCalculators_blender_billedIncomplete`)
- Modify: `plan_slate_pdf_service.dart` (`PlanSlateLabels` gains `String Function(int minutes) minutes` and `String maxPrefix`, and `buildSlate` gains `PdfLocalization localization` for the theme and direction), `plan_canvas_page.dart`
- Modify: `passport_label_pdf_export_service.dart` (`generateBytes(labels, {PdfLocalization? localization})`), `print_passport_labels.dart`
- Test: the existing tests for each service, plus one French assertion per service where the text is extractable (trip, course, blender use Helvetica)

- [ ] **Step 1: Write the failing tests.** Course rendered with fr contains `pdf_trainingLog` (fr). Trip rendered with fr contains `pdf_resort` (fr). Blender data with `totalLabel: 'Summe'` renders `Summe`. `planSlateHeaderLine` with labels whose `minutes` returns `'$m Min.'` renders `Min.`.
- [ ] **Step 2: Run the tests.** Expected: FAIL.
- [ ] **Step 3: Implement.** Course, trip and blender switch from a bare `pw.Document()` to `pw.Document(theme: await PdfFonts.instance.themeFor(loc))`. A Latin locale keeps Helvetica unless Roboto was initialised, which is today's behaviour for templated PDFs. Set `textDirection` on every page. `planSlateHeaderLine` and `planSlateMinutes` take the labels. GF, RT, CNS and TTS stay as universal technical abbreviations.
- [ ] **Step 4: Run** `flutter test test/core/services/export/ test/features/planner/plan_slate_pdf_test.dart test/features/courses/ test/features/gas_calculators/ test/features/cylinder_passports/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(pdf): print course, trip, slate, invoice and label PDFs in the app language (#2252)`.

### Task 6: Translations for the ten locales

**Files:** `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb` and the generated Dart files.

- [ ] **Step 1:** For each locale, insert every Task 2 key by anchor after that locale's `settings_export_pdfDocumentTitle` line (`transfer_pdfExport_languageHeader` goes after `transfer_pdfExport_includeVerificationAreasSubtitle`). Match the established terms in each file: dive, site, buddy, the SAC/RMV terminology tests (`german_sac_terminology_test`, `rmv_relabel_test`), and the accents guards. `pdf_labelValue` in fr is `{label} : {value}`.
- [ ] **Step 2:** Run `flutter gen-l10n` (it must report zero untranslated for the new keys) and `flutter test test/l10n/`. Expected: PASS. Check that `git diff --numstat lib/l10n/arb/*.arb` rows are even across locales.
- [ ] **Step 3: Commit** `feat(l10n): translate PDF export strings (#2252)`.

### Task 7: Whole-branch verification

- [ ] `dart format .` and `flutter analyze` (whole project, infos are fatal).
- [ ] `flutter test test/architecture/ test/l10n/ test/core/services/ test/features/transfer/ test/features/settings/ test/features/dive_log/ test/features/planner/ test/features/courses/ test/features/gas_calculators/ test/features/cylinder_passports/`.
- [ ] Render sample Detailed PDFs in fr, ar and zh with real fonts (a scratch script with network), rasterize them with `qlmanage`/`sips`, and look at them: French accents, Arabic shaped right to left, Chinese glyphs present.
- [ ] Capture screenshots of the export sheet (with the Language row) in light and dark mode, and of French and Arabic PDF pages, for the PR.
