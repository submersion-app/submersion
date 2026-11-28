# Suggest an Equipment Category Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A "Suggest a category" link under the gear editor's type field opens a short dialog and then a prefilled GitHub issue form; species suggestions move to an issue form too, so both labels land.

**Architecture:** Two pure URL builders in `domain/services/` produce `issues/new?template=<form>.yml&<field id>=<value>` URLs that match two new YAML issue forms. A dialog widget collects an `EquipmentSuggestion`; a small presentation helper builds the URL and opens it with the shared `openLinkOrOfferCopy`.

**Tech Stack:** Flutter, Riverpod (`package:submersion/core/providers/provider.dart`), gen-l10n ARBs (12 locales), GitHub issue forms.

**Spec:** `docs/design/specs/2026-11-27-equipment-category-suggestion-design.md` (issue #5103)

## Global Constraints

- Repository: `submersion-app/submersion`; URL path `/submersion-app/submersion/issues/new`.
- URLs stay at or under 8000 characters (`suggestionMaxUrlLength`, reuse the species constant's value).
- No `labels=` URL parameter: labels come from the forms only.
- Gear form labels: `["equipment-suggestion", "enhancement"]`; species form labels: `["species-suggestion"]`.
- Issue content is English labels plus enum names, whatever the app language; `locale` records the diver's language.
- Every new user-facing string goes into all 12 ARBs with real translations; run `flutter gen-l10n` last (after all ARBs are filled).
- No new package dependencies (parse YAML in tests with a regex; `yaml` is only transitive).
- No em-dashes anywhere, including ARB values and comments.

## Review Focus

1. Free text with `&`, `#`, `?`, newlines, emoji or non-Latin script: must survive the round trip as the exact field value (`Uri.queryParameters` decoding). Test in Task 1.
2. Whitespace-only name or reason: Open in GitHub stays disabled. Test in Task 3.
3. An item with brand only, model only, or neither: example shows what exists, and the checkbox is hidden when both are empty. Test in Task 3.
4. A dive-computer item whose type is locked: the link still shows and works. Test in Task 4.
5. A launch that fails or throws: the copy-link snackbar appears with the built URL. Test in Task 4.

---

### Task 1: Gear suggestion model, URL builder and issue form

**Files:**
- Create: `lib/features/equipment/domain/entities/equipment_suggestion.dart`
- Create: `lib/features/equipment/domain/services/equipment_suggestion_url.dart`
- Create: `.github/ISSUE_TEMPLATE/equipment-suggestion.yml`
- Test: `test/features/equipment/domain/services/equipment_suggestion_url_test.dart`

**Interfaces:**
- Produces:
  - `enum EquipmentSuggestionKind { category, subcategory }`
  - `class EquipmentSuggestion { final EquipmentSuggestionKind kind; final String name; final EquipmentType? parent; final String reason; final String? example; const EquipmentSuggestion({...}); }` (with `copyWith`, value equality)
  - `const String equipmentSuggestionTemplate = 'equipment-suggestion.yml';`
  - `Uri buildEquipmentSuggestionUrl({required EquipmentSuggestion suggestion, required String locale, required String appVersion})`

- [ ] **Step 1: Write the failing tests**

```dart
test('targets the equipment issue form with every field filled', () {
  final uri = buildEquipmentSuggestionUrl(
    suggestion: const EquipmentSuggestion(
      kind: EquipmentSuggestionKind.subcategory,
      name: 'Submersible pressure gauge',
      parent: EquipmentType.instrument,
      reason: 'Serviced on its own schedule.',
      example: 'Scubapro 52 mm brass',
    ),
    locale: 'sv',
    appVersion: '1.8.7.8001',
  );
  expect(uri.host, 'github.com');
  expect(uri.path, '/submersion-app/submersion/issues/new');
  expect(uri.queryParameters, {
    'template': 'equipment-suggestion.yml',
    'title': 'Equipment suggestion: Submersible pressure gauge',
    'kind': 'Subcategory',
    'name': 'Submersible pressure gauge',
    'parent': 'Instrument / Gauge (instrument)',
    'reason': 'Serviced on its own schedule.',
    'example': 'Scubapro 52 mm brass',
    'locale': 'sv',
    'app_version': '1.8.7.8001',
  });
});
// 'a category with no parent sends kind Category and parent None, and no example key'
// 'free text with & # ? newlines and non-Latin script round-trips exactly'
// 'keeps the URL under 8000 by trimming the reason first' (reason 'x' * 20000:
//    length <= 8000, name and example intact, reason shorter)
// 'trims the example after the reason' (reason and example both 20000)
// 'trims the name last and keeps at least one character' (all three 20000:
//    name non-empty, length <= 8000)
// 'every field the builder sends is an id in the issue form, and the form
//    carries the equipment-suggestion and enhancement labels'
//    (read File(p.join('.github', 'ISSUE_TEMPLATE', 'equipment-suggestion.yml')),
//    ids via RegExp(r'^\s+id:\s*(\S+)', multiLine: true); every key except
//    template and title is in the set; the labels line equals
//    'labels: ["equipment-suggestion", "enhancement"]')
```

- [ ] **Step 2: Run, expect FAIL** (missing files): `flutter test test/features/equipment/domain/services/equipment_suggestion_url_test.dart`

- [ ] **Step 3: Implement.** Kind text `Category` / `Subcategory`; parent `'${type.displayName} (${type.name})'` or `None`; omit `example` when null or blank. Trim with the species `shrink` loop: reason to 0, example to 0, name to 1. Write the YAML form: `name: Equipment category suggestion`, `description`, `title: "Equipment suggestion: "`, the labels above, a markdown intro (public page, leave out personal details), then inputs `kind`, `name` (required), `parent`, textarea `reason` (required), inputs `example`, `locale`, `app_version`.

- [ ] **Step 4: Run, expect PASS.**

- [ ] **Step 5: Commit** `feat(equipment): build equipment category suggestion issue URLs`

### Task 2: Species suggestions through an issue form

**Files:**
- Create: `.github/ISSUE_TEMPLATE/species-suggestion.yml`
- Modify: `lib/features/marine_life/domain/services/species_suggestion_url.dart`
- Modify: `lib/features/marine_life/presentation/helpers/species_suggestion_launcher.dart`
- Modify: `docs/developer/species-catalog.md` (Suggestions from divers)
- Modify: 12 ARBs: remove `marineLife_suggest_copyLink` and its `@` entry
- Test: `test/features/marine_life/domain/services/species_suggestion_url_test.dart`, `test/features/marine_life/presentation/pages/species_detail_page_suggest_test.dart`

**Interfaces:**
- Produces: `const String speciesSuggestionTemplate = 'species-suggestion.yml';` `buildSpeciesSuggestionUrl` keeps its signature. `launchSpeciesSuggestion(context, uri, launch:)` keeps its signature and delegates to `openLinkOrOfferCopy(..., failureMessage: l10n.marineLife_suggest_couldNotOpen)`.

- [ ] **Step 1: Update the tests first.** Replace the JSON-body assertions with: `template` is `species-suggestion.yml`; no `labels` and no `body` key; `common_name`, `scientific_name`, `category` (`invertebrate`), `taxonomy_class`, `description`, `locale`, `app_version` as before. A species with no scientific name or class omits those keys. Keep the trimming tests, reading `description` / `common_name` / `scientific_name` from the query. Add the same form contract test against `species-suggestion.yml` with labels line `labels: ["species-suggestion"]`. In the page test, the expected URL check follows the new parameters, and the copy-link label is `Copy link` (unchanged text).

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement** the builder change and the form (`title: "Species suggestion: "`, inputs `common_name` (required), `scientific_name`, `category`, `taxonomy_class`, textarea `description`, inputs `locale`, `app_version`). Make the launcher delegate. Remove the orphaned ARB key from all 12 files. Update the dev doc: suggestions arrive through the form with the `species-suggestion` label.

- [ ] **Step 4: Run both test files, expect PASS.**

- [ ] **Step 5: Commit** `feat(marine-life): file species suggestions through an issue form`

### Task 3: Suggestion dialog

**Files:**
- Create: `lib/features/equipment/presentation/widgets/equipment_suggestion_dialog.dart`
- Modify: `lib/l10n/arb/app_en.arb` (keys below, in the equipment group)
- Test: `test/features/equipment/presentation/widgets/equipment_suggestion_dialog_test.dart`

**Interfaces:**
- Consumes: `EquipmentSuggestion`, `EquipmentSuggestionKind` (Task 1)
- Produces: `Future<EquipmentSuggestion?> showEquipmentSuggestionDialog(BuildContext context, {required EquipmentType currentType, String? example})`

English strings (keys `equipment_suggest_*`):
`link` "Can't find a fit? Suggest a category"; `title` "Suggest a category"; `intro` "This opens a prefilled feature request on GitHub. You review it and post it from your browser."; `kindQuestion` "What are you suggesting?"; `kindCategory` "New type of gear"; `kindSubcategory` "New kind of a type"; `nameLabel` "Name"; `parentSubcategoryLabel` "A kind of"; `parentCategoryLabel` "Closest existing type"; `parentNone` "None"; `reasonLabel` "Why is it needed?"; `reasonHint` "What sets it apart from the existing types?"; `includeExample` "Include this item as an example ({example})"; `open` "Open in GitHub". Cancel uses `common_action_cancel`.

- [ ] **Step 1: Write the failing widget tests**
  - `defaults to a subcategory of the current type` (currentType bcd: subcategory selected, parent shows BCD)
  - `defaults to a category with no parent for Other` (currentType other: category selected, parent shows None)
  - `Open in GitHub is disabled until name and reason have text` (whitespace-only counts as empty)
  - `a subcategory needs a parent` (switch to subcategory after picking None: button disabled)
  - `returns the trimmed suggestion` (enter values with surrounding spaces, tap Open: result fields trimmed, example null while unticked)
  - `the example checkbox adds the example` and `is hidden when there is no example`
  - `Cancel returns null`

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement** an `AlertDialog` with a `SingleChildScrollView` body: `SegmentedButton<EquipmentSuggestionKind>`, name `TextField`, `DropdownButtonFormField<EquipmentType?>` (null item = None, only offered for a category; types via `sortedByLocalizedName`), multi-line reason `TextField` (`minLines: 2, maxLines: 5`), `CheckboxListTile` when `example` is non-blank, actions Cancel and `FilledButton.icon` with `Icons.open_in_new`. Keys: `equipment-suggest-kind`, `-name`, `-parent`, `-reason`, `-example`, `-open`.

- [ ] **Step 4: Run, expect PASS** (English ARB only at this point; tests pin `Locale('en')`).

- [ ] **Step 5: Commit** `feat(equipment): suggestion dialog for a new category`

### Task 4: Link under the type field

**Files:**
- Create: `lib/features/equipment/presentation/helpers/equipment_suggestion_action.dart`
- Modify: `lib/features/equipment/presentation/editing/gear_item_header_editor.dart` (after the type dropdown)
- Modify: `lib/features/equipment/presentation/helpers/equipment_web_link_launcher.dart` (doc comment: also opens suggestion links)
- Test: `test/features/equipment/presentation/editing/gear_item_header_editor_test.dart`

**Interfaces:**
- Consumes: Task 1 builder, Task 3 dialog, `equipmentWebLinkLaunchProvider`, `openLinkOrOfferCopy`, `packageInfoProvider`, `formatAppVersion`, `localeProvider`
- Produces: `Future<void> suggestEquipmentCategory(BuildContext context, WidgetRef ref, {required EquipmentType currentType, String? brand, String? model})`; example = non-blank of brand and model joined by a space, or null.

- [ ] **Step 1: Write the failing tests** in the header editor test file:
  - `shows the suggest link under the type field`
  - `shows the link while the type is locked` (item with a device)
  - `the link opens the dialog and launches the form URL` (override `equipmentWebLinkLaunchProvider` to record, `packageInfoProvider`, `localeProvider`; fill name and reason, tap Open; one URI with `template=equipment-suggestion.yml` and `parent` of the working type)
  - `offers the working brand and model as the example`
  - `a failed launch offers Copy link` (launcher returns false: snackbar with `Copy link`)

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement** the helper and a `TextButton.icon` (`Icons.lightbulb_outline`, key `gear-edit-suggest-category`, aligned start) below the dropdown, passing `working.type`, `working.brand`, `working.model`.

- [ ] **Step 4: Run, expect PASS.**

- [ ] **Step 5: Commit** `feat(equipment): suggest a category from the gear editor`

### Task 5: Translations and checks

**Files:**
- Modify: the 11 non-English ARBs (`ar de es fr he hu it ja nl pt zh`), then generated `app_localizations*.dart`

- [ ] **Step 1:** Add every `equipment_suggest_*` key, translated, next to the English group's position in each ARB (the ARBs are feature-grouped; anchor on a neighbouring equipment key). Keep `{example}` as is.
- [ ] **Step 2:** `flutter gen-l10n`; confirm a non-English generated file holds the translation, such as `grep equipment_suggest_open lib/l10n/arb/app_localizations_de.dart`.
- [ ] **Step 3:** `dart format .`, `flutter analyze`, and the test files this plan touches, by path (the pre-push hook runs the architecture guards).
- [ ] **Step 4: Commit** `i18n(equipment): translate the category suggestion strings`
