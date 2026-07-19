# Edit Form Chrome Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the edit-form section chrome as header-in-card (`FormSection` v2), migrate every field on the dive and site edit pages onto the flat `FormRow` language, replace the tank hero card with an identity-first row, and unify sub-headers, actions, and empty states — per the approved spec `docs/superpowers/specs/2026-07-17-edit-form-chrome-redesign-design.md`.

**Architecture:** `FormSection` is rewritten in place (parameter-compatible, so all 10 consumer files keep compiling; the `hero` slot is deleted only in the final task once nothing passes it). Three new tiny shared widgets (`FormOverline`, `FormAppendRow`, `FormEmptyRow`) plus two new row primitives (`EnumPickerRow`, `SuggestionFormRow`) carry the unified language. The dive page's Conditions/Weather interiors and the whole site form then migrate onto rows; site sections are extracted into `edit_sections/` files mirroring the dive form. Pages keep all state management, controllers, picker sheets, save paths, and merge/bulk semantics.

**Tech Stack:** Flutter/Dart (Material 3), Riverpod, `flutter gen-l10n` (template `lib/l10n/arb/app_en.arb` + 10 locales: ar, de, es, fr, he, hu, it, nl, pt, zh). **No new pub dependencies.**

**Reference mockup (design freeze, keep open while implementing):**
`docs/superpowers/specs/assets/2026-07-17-edit-form-chrome-redesign-mockup.html`

## Global Constraints

- Branch: `feat/edit-form-chrome-redesign` (already exists, spec committed on it). All commits go here.
- TDD: write the failing test first, watch it fail, implement, watch it pass.
- Before each commit: `dart format .` must produce no changes, then `flutter analyze` (whole project, NEVER piped through `tail`/`grep`) must be clean.
- Run specific test files, not broad directories (timeout protection).
- Commit messages: conventional commits, **no Co-Authored-By lines, no session URLs**.
- No emojis anywhere. All user-visible strings via `context.l10n` (import `package:submersion/l10n/l10n_extension.dart`).
- **Every new l10n key lands in `lib/l10n/arb/app_en.arb` (with `@`-metadata) AND all 10 locale arbs in the same task** — translate the values, no English fallbacks. After arb edits run `flutter gen-l10n`.
- All numeric display through `UnitFormatter` (`lib/core/utils/unit_formatter.dart`). Never hard-code units.
- Colors/text styles only from `Theme.of(context).colorScheme` / `textTheme` / `FormStyle` — the app ships 6 theme variants, light and dark; nothing may assume one palette.
- Validation trap (spec section 2): a collapsed `FormSection` un-mounts its body, so any field with a validator must live in an always-open section, or the page must expand-all before `Form.validate()` (both pages already do this — do not remove that logic).
- Widget tests for form pages need tall viewports (`tester.view.physicalSize = const Size(900, 3200)`) because lazy lists never build below the fold.
- StatStrip (`lib/shared/widgets/forms/stat_strip.dart`) is USED by trip-story widgets (`trip_story_map_header.dart`, `trip_story_day_card.dart`). Remove its edit-form usage only; never delete the widget.
- Bulk dive edit mode and site merge mode keep their existing semantics. Bulk-form interiors (the `_buildBulk*` builders) are OUT of scope beyond inheriting the new `FormSection` chrome automatically.

---

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `lib/shared/widgets/forms/form_overline.dart` | `FormOverline` + `FormOverlineAction`: sub-header overline with trailing accent text actions |
| `lib/shared/widgets/forms/form_append_row.dart` | `FormAppendRow`: full-width left-aligned "+ Add x" accent row |
| `lib/shared/widgets/forms/form_empty_row.dart` | `FormEmptyRow`: single muted empty-state line |
| `lib/shared/widgets/forms/enum_picker_row.dart` | `EnumPickerRow<T>`: FormRow.picker + modal bottom sheet over enum values |
| `lib/shared/widgets/forms/suggestion_form_row.dart` | `SuggestionFormRow`: row-styled always-mounted autocomplete text field (validator-safe) |
| `lib/features/dive_log/presentation/widgets/edit_sections/tank_row.dart` | `TankRow`: identity-first two-line tank row, inline TankEditor on tap |
| `lib/features/dive_sites/presentation/widgets/edit_sections/merge_field_extras.dart` | `MergeFieldExtras`: per-field merge source label + cycle callback |
| `lib/features/dive_sites/presentation/widgets/edit_sections/identity_section.dart` | Site group 1: name/description/country/region/city/island/body of water rows |
| `lib/features/dive_sites/presentation/widgets/edit_sections/location_section.dart` | Site group 2: lat/lng rows, locate/map actions row, altitude row + indicator |
| `lib/features/dive_sites/presentation/widgets/edit_sections/dive_info_section.dart` | Site group 3: min/max depth rows, difficulty chips row, rating row |
| `lib/features/dive_sites/presentation/widgets/edit_sections/access_safety_section.dart` | Site group 4: access/mooring/parking/hazards rows |
| `lib/features/dive_sites/presentation/widgets/edit_sections/life_notes_section.dart` | Site group 5: species overline + chips, notes row, share toggle |
| `test/shared/widgets/forms/form_overline_test.dart` | FormOverline render + action tap + disabled action |
| `test/shared/widgets/forms/form_append_row_test.dart` | FormAppendRow render + tap |
| `test/shared/widgets/forms/form_empty_row_test.dart` | FormEmptyRow render |
| `test/shared/widgets/forms/enum_picker_row_test.dart` | Sheet opens, select, clear, dismiss |
| `test/shared/widgets/forms/suggestion_form_row_test.dart` | Typing filters suggestions, select fills controller, validator fires |
| `test/features/dive_log/presentation/widgets/edit_sections/tank_row_test.dart` | Collapsed row content, tap expands editor, Done collapses |

**Modified:**

| File | Change |
|---|---|
| `lib/shared/widgets/forms/form_style.dart` | Add `headerPadding`, `sectionTitleStyle`, `overlineStyle`, `cardBorderColor`, `invitationColor` |
| `lib/shared/widgets/forms/form_section.dart` | Full rewrite: header-in-card, optional `icon`, body-only AnimatedSize; `hero` kept until Task 10, then deleted |
| `lib/shared/widgets/forms/form_row.dart` | Text rows keep the row shell while editing (bare inline field); `FormRow.rating` gains `onClear` |
| `lib/features/dive_log/presentation/widgets/dive_mode_selector.dart` | Add `dense` mode (segmented only) + static `descriptionFor` |
| `lib/features/dive_log/presentation/widgets/edit_sections/gas_gear_section.dart` | v2 composition: icon, mode row slot, TANKS overline, tank rows, append row |
| `lib/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart` | Pass `icon`; profile child becomes a row (page-side) |
| `lib/features/dive_log/presentation/widgets/edit_sections/conditions_section.dart` | Drop hero/StatStrip; temp/visibility become rows; icon |
| `lib/features/dive_log/presentation/widgets/edit_sections/trip_section.dart` | Pass `icon` |
| `lib/features/dive_log/presentation/widgets/edit_sections/buddies_section.dart` | Pass `icon` |
| `lib/features/dive_log/presentation/widgets/edit_sections/experience_section.dart` | Pass `icon` |
| `lib/features/dive_log/presentation/widgets/edit_sections/rare_sections.dart` | Add `icon` param |
| `lib/features/dive_log/presentation/pages/dive_edit_page.dart` | Environment/weather/profile/equipment/weight children rebuilt on rows + overlines; tank rows |
| `lib/features/dive_sites/presentation/pages/site_edit_page.dart` | All `_build*Section` interiors replaced by extracted section widgets; StatStrip/SuggestionField imports removed |
| `lib/l10n/arb/app_en.arb` + 10 locale arbs | New keys (Task 6/7 tables) |
| `test/shared/widgets/forms/form_section_test.dart` | Rewritten for v2 anatomy |
| `test/shared/widgets/forms/form_row_test.dart` | Updated editing-state expectations + rating clear |
| `test/features/dive_log/presentation/pages/dive_edit_page_test.dart` (+ coverage/geofence/surface-gps/bulk tests) | Finder updates where chrome changed |
| `test/features/dive_sites/presentation/pages/site_edit_merge_page_test.dart` | Finder updates for extracted sections |

**Deleted (Task 6):** `lib/features/dive_log/presentation/widgets/edit_sections/tank_card.dart` (replaced by `tank_row.dart`).

**Key existing APIs (consume, do not modify):**

- `FormRow` variants (`lib/shared/widgets/forms/form_row.dart`): `.text(label, controller, {placeholder, suffixText, keyboardType, inputFormatters, maxLines, alwaysEditing, validator, onChanged, decoration, profileSuggestion})`, `.picker(label, value, onTap, {placeholder, onClear})`, `.display(label, value)`, `.toggle(label, value, onChanged)`, `.rating(label, value, onChanged)`, `.custom(label, child)`.
- `TankEditor` (`lib/features/dive_log/presentation/widgets/tank_editor.dart`): `TankEditor({required DiveTank tank, required int tankNumber, required onChanged, VoidCallback? onRemove, bool canRemove})`.
- `UnitFormatter`: `convertPressure`, `pressureSymbol`, `formatTankVolume(volume, workingPressure)`, `depthSymbol`, `temperatureSymbol`, `altitudeSymbol`, `windSpeedSymbol`, `formatWeight`.
- `SuggestionField` (`lib/features/dive_sites/presentation/widgets/suggestion_field.dart`): source for the autocomplete/fuzzy logic reused by `SuggestionFormRow`; keep the widget itself untouched.
- Site suggestion helpers (`lib/features/dive_sites/domain/services/site_suggestions.dart`): `suggestedSiteNames(sites, {excludeId})`, `suggestedCountries(sites)`, `suggestedRegions(sites, country)`, `suggestedCities(sites, country, region)`, `suggestedIslands(sites, country)`, `suggestedBodiesOfWater(sites, country)`.
- `SimilarValueHint` (`lib/features/dive_sites/presentation/widgets/similar_value_hint.dart`): `SimilarValueHint({required query, required candidates})`.
- l10n: existing keys reused throughout — `forms_section_issues(count)`, `diveLog_edit_notSpecified`, `diveLog_edit_section_equipment`, `diveLog_edit_section_weight`, `diveLog_edit_subsection_weather`, `diveLog_edit_useSet`, `diveLog_edit_add`, `diveLog_edit_addTank`, `diveLog_edit_addWeightEntry`, `diveLog_edit_noEquipmentSelected`, `diveLog_diveMode_title`, `diveSites_edit_gps_*`, `diveSites_edit_altitude_*`, `diveSites_edit_field_*`.

### Section icon map (spec section 1)

| Section | Icon constant |
|---|---|
| The Dive | `Icons.show_chart` |
| Gas & Gear | `MdiIcons.divingScubaTank` (import `package:submersion/core/icons/mdi_icons.dart`) |
| Conditions | `Icons.waves` |
| Trip | `Icons.flight_takeoff` |
| Buddies | `Icons.group_outlined` |
| Experience | `Icons.star_outline` |
| Training course | `Icons.school_outlined` |
| Custom fields | `Icons.tune` |
| Identity (site) | `Icons.bookmark_outline` |
| Location (site) | `Icons.place_outlined` |
| Dive Info (site) | `Icons.info_outline` |
| Access & Safety (site) | `Icons.shield_outlined` |
| Life & Notes (site) | `Icons.menu_book_outlined` |

---

### Task 1: `FormSection` v2 — header-in-card chrome

**Files:**
- Modify: `lib/shared/widgets/forms/form_style.dart`
- Modify: `lib/shared/widgets/forms/form_section.dart` (full rewrite)
- Test: `test/shared/widgets/forms/form_section_test.dart` (full rewrite)

**Interfaces:**
- Consumes: `FormStyle` tokens.
- Produces: `FormSection({required String label, required bool expanded, required VoidCallback? onToggle, required List<Widget> children, IconData? icon, String? summary, String? emptyInvitation, bool isEmpty = false, int errorCount = 0, Widget? hero})`. Same parameter surface as v1 plus optional `icon` — all 10 existing consumers compile unchanged. `hero` still renders (first body child) so ConditionsSection/site Dive Info keep working until Tasks 7/9; it is deleted in Task 10.
- Behavior contract later tasks rely on: title text renders as given (NOT uppercased); collapsed body children are absent from the tree; header is one `InkWell` whose `Semantics` is a button labeled with the title.

- [ ] **Step 1: Add v2 tokens to `FormStyle`**

Append inside `abstract final class FormStyle` in `lib/shared/widgets/forms/form_style.dart`:

```dart
  /// Padding of the header row inside a section card.
  static const EdgeInsets headerPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 12,
  );

  /// Section title inside the card header.
  static TextStyle sectionTitleStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.titleMedium!.copyWith(
      fontSize: 15.5,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface,
    );
  }

  /// Sub-header overline inside a section body (TANKS, EQUIPMENT, WEATHER).
  static TextStyle overlineStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.labelSmall!.copyWith(
      fontSize: 10.5,
      letterSpacing: 0.9,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  /// Hairline border around section cards (light-theme discernibility).
  static Color cardBorderColor(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  /// Fainter color for empty-invitation text in a collapsed header.
  static Color invitationColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
```

Do NOT remove `labelStyle`, `heroPadding`, `heroValueStyle`, `heroUnitStyle`, `heroLabelStyle` yet — StatStrip and the old chrome still use them (cleanup in Task 10).

- [ ] **Step 2: Rewrite the FormSection widget test for v2**

Replace the full contents of `test/shared/widgets/forms/form_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/l10n/generated/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

Widget harness(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('FormSection v2', () {
    testWidgets('expanded: title, icon, children and up-chevron; no summary', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          FormSection(
            label: 'Gas & Gear',
            icon: Icons.waves,
            expanded: true,
            onToggle: () {},
            summary: 'the summary',
            children: const [Text('row one'), Text('row two')],
          ),
        ),
      );
      expect(find.text('Gas & Gear'), findsOneWidget);
      expect(find.byIcon(Icons.waves), findsOneWidget);
      expect(find.text('row one'), findsOneWidget);
      expect(find.text('row two'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.text('the summary'), findsNothing);
    });

    testWidgets('collapsed with data: summary + down-chevron, no children', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          FormSection(
            label: 'Conditions',
            expanded: false,
            onToggle: () {},
            summary: 'Salt water',
            children: const [Text('row one')],
          ),
        ),
      );
      expect(find.text('Conditions'), findsOneWidget);
      expect(find.text('Salt water'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.text('row one'), findsNothing);
    });

    testWidgets('collapsed empty: invitation shown in header', (tester) async {
      await tester.pumpWidget(
        harness(
          FormSection(
            label: 'Buddies',
            expanded: false,
            onToggle: () {},
            isEmpty: true,
            emptyInvitation: 'Add buddies',
            children: const [Text('row one')],
          ),
        ),
      );
      expect(find.text('Add buddies'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.text('row one'), findsNothing);
    });

    testWidgets('collapsed with errors: issue badge replaces summary', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          FormSection(
            label: 'Location',
            expanded: false,
            onToggle: () {},
            summary: '12.0, -68.2',
            errorCount: 2,
            children: const [Text('row one')],
          ),
        ),
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.textContaining('2'), findsOneWidget);
      expect(find.text('12.0, -68.2'), findsNothing);
    });

    testWidgets('tapping the header title toggles', (tester) async {
      var toggled = 0;
      await tester.pumpWidget(
        harness(
          FormSection(
            label: 'Trip',
            expanded: false,
            onToggle: () => toggled++,
            summary: 'Bonaire',
            children: const [Text('row one')],
          ),
        ),
      );
      await tester.tap(find.text('Trip'));
      expect(toggled, 1);
    });

    testWidgets('always-open section: no chevron, header not tappable', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const FormSection(
            label: 'The Dive',
            expanded: true,
            onToggle: null,
            children: [Text('row one')],
          ),
        ),
      );
      expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
      expect(
        find.descendant(
          of: find.byType(FormSection),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });

    testWidgets('header semantics: button labeled with title', (tester) async {
      await tester.pumpWidget(
        harness(
          FormSection(
            label: 'Experience',
            expanded: false,
            onToggle: () {},
            summary: 'stars',
            children: const [Text('row one')],
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('Experience')),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          label: 'Experience',
        ),
      );
    });

    testWidgets('hero renders as first body child while param exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          FormSection(
            label: 'Dive Info',
            expanded: true,
            onToggle: () {},
            hero: const Text('hero widget'),
            children: const [Text('row one')],
          ),
        ),
      );
      expect(find.text('hero widget'), findsOneWidget);
    });
  });
}
```

Note on the semantics test: the header wraps title + summary + chevron in one `Semantics(button:, label:)` node with `container: true` and `excludeSemantics: false`; if `matchesSemantics` fails on extra flags in CI, relax the assertion to checking `isButton` and `label` via `SemanticsNode` properties, but the widget MUST mark the header as a button labeled with the section title.

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/shared/widgets/forms/form_section_test.dart`
Expected: FAIL (old chrome renders `GAS & GEAR` uppercase outside the card, chevrons are `keyboard_arrow_up`/`chevron_right`, summary text present while expanded, etc.)

- [ ] **Step 4: Rewrite `form_section.dart`**

Replace the full contents of `lib/shared/widgets/forms/form_section.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_style.dart';

/// A collapsible form group: one tonal card whose first row is a permanent
/// header (icon + title + trailing state + chevron).
///
/// One anatomy, four states (see the 2026-07-17 design-freeze mockup):
/// - expanded: header (up-chevron) + hairline divider + [children]
/// - collapsed with data: header only, muted [summary] before the chevron
/// - collapsed and empty: header only, fainter [emptyInvitation]
/// - collapsed with errors: header only, error badge + error-tinted edge
///
/// Expansion is owned by the page; pass [onToggle] null for sections that
/// are never collapsible (their header shows no chevron and is not
/// tappable). The whole header row is the toggle tap target.
///
/// NOTE: when collapsed, [children] are not mounted at all — fields inside
/// a collapsed section are invisible to Form.validate().
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.label,
    required this.expanded,
    required this.onToggle,
    required this.children,
    this.icon,
    this.summary,
    this.emptyInvitation,
    this.isEmpty = false,
    this.errorCount = 0,
    this.hero,
  });

  final String label;
  final bool expanded;
  final VoidCallback? onToggle;
  final List<Widget> children;
  final IconData? icon;
  final String? summary;
  final String? emptyInvitation;
  final bool isEmpty;
  final int errorCount;

  /// Transitional slot from the v1 chrome; renders as the first body child.
  /// Scheduled for removal once no caller passes it.
  final Widget? hero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCollapsedError = errorCount > 0 && !expanded;
    return Material(
      color: FormStyle.groupColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FormStyle.groupRadius),
        side: BorderSide(color: FormStyle.cardBorderColor(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        foregroundDecoration: hasCollapsedError
            ? BoxDecoration(
                border: Border(
                  left: BorderSide(color: theme.colorScheme.error, width: 3),
                ),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? _buildBody(context)
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final header = Padding(
      padding: FormStyle.headerPadding,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
          ],
          Text(label, style: FormStyle.sectionTitleStyle(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildTrailing(context),
            ),
          ),
          if (onToggle != null) ...[
            const SizedBox(width: 6),
            Icon(
              expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
    if (onToggle == null) return header;
    return Semantics(
      container: true,
      button: true,
      label: label,
      child: InkWell(onTap: onToggle, child: header),
    );
  }

  Widget _buildTrailing(BuildContext context) {
    final theme = Theme.of(context);
    if (expanded) return const SizedBox.shrink();
    if (errorCount > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 4),
          Text(
            context.l10n.forms_section_issues(errorCount),
            style: theme.textTheme.labelMedium!.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    final text = isEmpty ? (emptyInvitation ?? '') : (summary ?? '');
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      style: theme.textTheme.bodySmall!.copyWith(
        color: isEmpty
            ? FormStyle.invitationColor(context)
            : theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
    );
  }

  Widget _buildBody(BuildContext context) {
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: FormStyle.dividerColor(context),
    );
    final rows = <Widget>[divider];
    if (hero != null) {
      rows.add(hero!);
      if (children.isNotEmpty) rows.add(divider);
    }
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) rows.add(divider);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}
```

- [ ] **Step 5: Run the widget test to verify it passes**

Run: `flutter test test/shared/widgets/forms/form_section_test.dart`
Expected: PASS (8 tests)

- [ ] **Step 6: Sweep dependent tests for chrome-coupled finders**

The chrome no longer uppercases labels and no longer uses `Icons.chevron_right`/`Icons.add` in collapsed bars. Find affected assertions:

Run: `grep -rn "chevron_right\|Icons.add\b\|toUpperCase\|keyboard_arrow_up" test/shared/widgets/forms/ test/features/dive_log/presentation/pages/ test/features/dive_sites/presentation/pages/`

Then run the page suites that exercise sections:

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_page_test.dart test/features/dive_sites/presentation/pages/site_edit_merge_page_test.dart`

Fix any failures by updating finders to the v2 anatomy (summaries/invitations live in the header; expansion tap target is the header title; collapsed sections have no `+` icon — the invitation text plus down-chevron replaces it). Do not change page behavior to make tests pass.

Also run: `flutter test test/features/dive_log/presentation/pages/dive_edit_page_coverage_test.dart test/features/dive_log/presentation/pages/bulk_dive_edit_form_test.dart test/features/dive_log/presentation/pages/dive_edit_geofence_suggestion_test.dart test/features/dive_log/presentation/pages/dive_surface_gps_section_test.dart`
Expected: PASS after finder updates.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(forms): FormSection v2 header-in-card chrome"
```

---

### Task 2: `FormOverline`, `FormAppendRow`, `FormEmptyRow`

**Files:**
- Create: `lib/shared/widgets/forms/form_overline.dart`
- Create: `lib/shared/widgets/forms/form_append_row.dart`
- Create: `lib/shared/widgets/forms/form_empty_row.dart`
- Test: `test/shared/widgets/forms/form_overline_test.dart`
- Test: `test/shared/widgets/forms/form_append_row_test.dart`
- Test: `test/shared/widgets/forms/form_empty_row_test.dart`

**Interfaces:**
- Produces:
  - `FormOverlineAction({required String label, IconData? icon, required VoidCallback? onPressed, bool busy = false})` — `onPressed: null` renders disabled; `busy: true` renders a 16px spinner instead of the icon.
  - `FormOverline({required String label, List<FormOverlineAction> actions = const []})` — uppercase letter-spaced label left, accent text actions right.
  - `FormAppendRow({required String label, required VoidCallback onTap})` — full-width left-aligned "+ label" accent row.
  - `FormEmptyRow({required String label})` — single muted line.

- [ ] **Step 1: Write the failing tests**

`test/shared/widgets/forms/form_overline_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/forms/form_overline.dart';

Widget harness(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders uppercased label and actions; taps fire', (
    tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(
      harness(
        FormOverline(
          label: 'Equipment',
          actions: [
            FormOverlineAction(label: 'Use set', onPressed: () => tapped++),
            FormOverlineAction(
              label: 'Add',
              icon: Icons.add,
              onPressed: () => tapped += 10,
            ),
          ],
        ),
      ),
    );
    expect(find.text('EQUIPMENT'), findsOneWidget);
    await tester.tap(find.text('Use set'));
    await tester.tap(find.text('Add'));
    expect(tapped, 11);
  });

  testWidgets('null onPressed renders a disabled action', (tester) async {
    await tester.pumpWidget(
      harness(
        FormOverline(
          label: 'Weather',
          actions: const [FormOverlineAction(label: 'Fetch', onPressed: null)],
        ),
      ),
    );
    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('busy action shows a progress indicator', (tester) async {
    await tester.pumpWidget(
      harness(
        FormOverline(
          label: 'Weather',
          actions: const [
            FormOverlineAction(label: 'Fetch', onPressed: null, busy: true),
          ],
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

`test/shared/widgets/forms/form_append_row_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/forms/form_append_row.dart';

void main() {
  testWidgets('renders plus icon + label and fires onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormAppendRow(label: 'Add tank', onTap: () => tapped = true),
        ),
      ),
    );
    expect(find.text('Add tank'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    await tester.tap(find.text('Add tank'));
    expect(tapped, isTrue);
  });
}
```

`test/shared/widgets/forms/form_empty_row_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/forms/form_empty_row.dart';

void main() {
  testWidgets('renders the muted label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FormEmptyRow(label: 'No equipment yet')),
      ),
    );
    expect(find.text('No equipment yet'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/shared/widgets/forms/form_overline_test.dart test/shared/widgets/forms/form_append_row_test.dart test/shared/widgets/forms/form_empty_row_test.dart`
Expected: FAIL (files do not exist)

- [ ] **Step 3: Implement the three widgets**

`lib/shared/widgets/forms/form_overline.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/forms/form_style.dart';

/// A trailing action docked to a [FormOverline]: plain accent text button.
class FormOverlineAction {
  const FormOverlineAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Replaces [icon] with a small progress spinner (e.g. while fetching).
  final bool busy;
}

/// Sub-header inside a section body: uppercase letter-spaced overline with
/// optional accent text actions docked to its trailing edge. This is the
/// only sub-header style inside sections (spec: one subordinate style).
class FormOverline extends StatelessWidget {
  const FormOverline({super.key, required this.label, this.actions = const []});

  final String label;
  final List<FormOverlineAction> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: FormStyle.overlineStyle(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final action in actions)
            TextButton.icon(
              onPressed: action.busy ? null : action.onPressed,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: Theme.of(context).textTheme.labelMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: action.busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : (action.icon != null
                        ? Icon(action.icon, size: 16)
                        : const SizedBox.shrink()),
              label: Text(action.label),
            ),
        ],
      ),
    );
  }
}
```

`lib/shared/widgets/forms/form_append_row.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/forms/form_style.dart';

/// Full-width append action inside a section body: "+ Add tank".
/// One of the two sanctioned in-section action patterns (the other is
/// [FormOverlineAction]).
class FormAppendRow extends StatelessWidget {
  const FormAppendRow({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.textTheme.bodyMedium!.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: FormStyle.rowPadding,
        child: Row(
          children: [
            Icon(Icons.add, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(label, style: accent),
          ],
        ),
      ),
    );
  }
}
```

`lib/shared/widgets/forms/form_empty_row.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/forms/form_style.dart';

/// Quiet one-line empty state inside a section body ("No equipment yet").
/// Never pair with icons or instruction paragraphs; the relevant actions
/// belong on the group's [FormOverline].
class FormEmptyRow extends StatelessWidget {
  const FormEmptyRow({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: FormStyle.rowPadding,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: FormStyle.invitationColor(context),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/shared/widgets/forms/form_overline_test.dart test/shared/widgets/forms/form_append_row_test.dart test/shared/widgets/forms/form_empty_row_test.dart`
Expected: PASS

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(forms): FormOverline, FormAppendRow, FormEmptyRow primitives"
```

---

### Task 3: `FormRow` upgrades — row-shaped editing, rating clear

Today a tapped `FormRow.text` (and any row with a validator) swaps into a full-width outlined `TextFormField` — the exact boxed look this redesign removes. After this task, text rows keep the label-left/value-right shell in EVERY state; editing just makes the right side a live bare field. Rows with validators stay mounted (validator-safe) but no longer look boxed.

**Files:**
- Modify: `lib/shared/widgets/forms/form_row.dart`
- Test: `test/shared/widgets/forms/form_row_test.dart`

**Interfaces:**
- Produces (changed behavior, same names):
  - `FormRow.text`: editing/persistent state renders `Row[ label, Expanded(TextFormField(bare)) ]`; single-line fields right-aligned, multi-line left-aligned; validation errors appear under the field via the TextFormField's own error line.
  - `FormRow.rating` gains `VoidCallback? onClear` — when non-null and `value > 0`, a small clear icon renders after the stars.

- [ ] **Step 1: Update/add failing tests**

In `test/shared/widgets/forms/form_row_test.dart`, first read the existing tests. Update any test that asserts the old editing presentation (e.g. expecting `InputDecoration.labelText == label` while editing), then ADD these tests:

```dart
  testWidgets('text row keeps its label visible while editing', (tester) async {
    final controller = TextEditingController(text: '42');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Material(
            child: FormRow.text(label: 'Max depth', controller: controller),
          ),
        ),
      ),
    );
    await tester.tap(find.text('42'));
    await tester.pump();
    // Editing: label still rendered as row text, field is bare (no outline).
    expect(find.text('Max depth'), findsOneWidget);
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.enabled, isTrue);
    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.decoration!.border, InputBorder.none);
    expect(input.decoration!.filled, isFalse);
  });

  testWidgets('validator row stays mounted and shows its error inline', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Material(
            child: Form(
              key: formKey,
              child: FormRow.text(
                label: 'Name',
                controller: controller,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
            ),
          ),
        ),
      ),
    );
    // Persistent (validator) rows are mounted without tapping.
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    formKey.currentState!.validate();
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('rating row shows clear affordance and clears', (tester) async {
    var value = 3;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Material(
            child: StatefulBuilder(
              builder: (context, setState) => FormRow.rating(
                label: 'Rating',
                value: value,
                onChanged: (v) => setState(() => value = v),
                onClear: () => setState(() => value = 0),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.clear), findsOneWidget);
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();
    expect(value, 0);
    // Cleared: no clear icon anymore.
    expect(find.byIcon(Icons.clear), findsNothing);
  });
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `flutter test test/shared/widgets/forms/form_row_test.dart`
Expected: new tests FAIL (old editing swaps to labeled boxed field; rating has no `onClear`).

- [ ] **Step 3: Implement in `form_row.dart`**

(a) In the `FormRow.rating` constructor, replace the initializer entry `onClear = null` with an optional parameter: add `this.onClear,` to the constructor's parameter list (after `onChanged`) and delete `onClear = null,` from the initializer list.

(b) Add a bare-decoration helper to `_FormRowState`:

```dart
  InputDecoration _bareDecoration(BuildContext context) {
    return InputDecoration(
      isDense: true,
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
      hintText: widget.placeholder,
      suffixText: widget.suffixText,
    );
  }
```

(c) In `build`, `case _RowKind.text`: replace the `if (_persistent || _editing)` branch body with:

```dart
        if (_persistent || _editing) {
          return Padding(
            padding: FormStyle.rowPadding,
            child: Row(
              crossAxisAlignment: widget.maxLines > 1
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Text(widget.label, style: _labelTextStyle(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: widget.controller,
                    focusNode: _persistent ? null : _focusNode,
                    autofocus: !_persistent,
                    maxLines: widget.maxLines,
                    keyboardType: widget.keyboardType,
                    inputFormatters: widget.inputFormatters,
                    validator: widget.validator,
                    onChanged: widget.onChanged,
                    textAlign: widget.maxLines > 1
                        ? TextAlign.start
                        : TextAlign.end,
                    style: theme.textTheme.bodyMedium,
                    decoration: widget.decoration ?? _bareDecoration(context),
                    onFieldSubmitted: _persistent
                        ? null
                        : (_) => setState(() => _editing = false),
                  ),
                ),
              ],
            ),
          );
        }
```

(d) In `case _RowKind.rating`, wrap the stars row so a clear icon can trail it — replace the `trailing:` value with:

```dart
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...List.generate(5, (i) {
                final filled = i < widget.intValue!;
                return InkWell(
                  onTap: () => widget.onIntChanged!(i + 1),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      filled ? Icons.star : Icons.star_border,
                      size: 22,
                      color: filled
                          ? Colors.amber
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }),
              if (widget.onClear != null && widget.intValue! > 0) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: widget.onClear,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.clear,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
```

(e) The other named constructors (`.text`, `.picker`, `.display`, `.toggle`, `.custom`) each have `onClear` handling already (`.picker` uses it; the rest set `onClear = null` in initializers — leave those as they are).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/shared/widgets/forms/form_row_test.dart`
Expected: PASS

- [ ] **Step 5: Run dependent page suites**

The editing-state change affects any page test that taps a row then types.

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_page_test.dart test/features/dive_log/presentation/pages/dive_edit_page_coverage_test.dart test/features/dive_log/presentation/pages/bulk_dive_edit_form_test.dart`
Expected: PASS (fix finders that looked for the old labeled decoration; entering text via `tester.enterText(find.byType(TextFormField).first, ...)` still works).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(forms): row-shaped inline editing for FormRow.text; rating clear affordance"
```

---

### Task 4: `EnumPickerRow<T>`

**Files:**
- Create: `lib/shared/widgets/forms/enum_picker_row.dart`
- Test: `test/shared/widgets/forms/enum_picker_row_test.dart`

**Interfaces:**
- Consumes: `FormRow.picker`.
- Produces: `EnumPickerRow<T>({required String label, required T? value, required List<T> values, required String Function(T) displayName, required ValueChanged<T?> onChanged, bool allowClear = true, String? placeholder})`. Tap opens a modal bottom sheet of options; selecting calls `onChanged(v)`; the "Not specified" entry (when `allowClear`) calls `onChanged(null)`; dismissing changes nothing. When `placeholder` is null the row and sheet use `context.l10n.diveLog_edit_notSpecified`.

- [ ] **Step 1: Write the failing test**

`test/shared/widgets/forms/enum_picker_row_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/forms/enum_picker_row.dart';

enum Flavor { mild, medium, spicy }

String flavorName(Flavor f) => switch (f) {
  Flavor.mild => 'Mild',
  Flavor.medium => 'Medium',
  Flavor.spicy => 'Spicy',
};

Widget harness({
  required Flavor? value,
  required ValueChanged<Flavor?> onChanged,
}) => MaterialApp(
  home: Scaffold(
    body: Material(
      child: EnumPickerRow<Flavor>(
        label: 'Flavor',
        value: value,
        values: Flavor.values,
        displayName: flavorName,
        onChanged: onChanged,
        placeholder: 'Not specified',
      ),
    ),
  ),
);

void main() {
  testWidgets('shows value; tap opens sheet; selection fires onChanged', (
    tester,
  ) async {
    Flavor? changed;
    await tester.pumpWidget(
      harness(value: Flavor.mild, onChanged: (v) => changed = v),
    );
    expect(find.text('Mild'), findsOneWidget);
    await tester.tap(find.text('Flavor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spicy'));
    await tester.pumpAndSettle();
    expect(changed, Flavor.spicy);
  });

  testWidgets('clear option fires onChanged(null)', (tester) async {
    Flavor? changed = Flavor.mild;
    await tester.pumpWidget(
      harness(value: Flavor.mild, onChanged: (v) => changed = v),
    );
    await tester.tap(find.text('Flavor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not specified').last);
    await tester.pumpAndSettle();
    expect(changed, isNull);
  });

  testWidgets('dismissing the sheet changes nothing', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      harness(value: Flavor.mild, onChanged: (_) => calls++),
    );
    await tester.tap(find.text('Flavor'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // barrier
    await tester.pumpAndSettle();
    expect(calls, 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/forms/enum_picker_row_test.dart`
Expected: FAIL (file does not exist)

- [ ] **Step 3: Implement `enum_picker_row.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';

/// A [FormRow.picker] over a fixed list of enum-like values, opening a
/// modal bottom sheet of radio options. Replaces the outlined
/// DropdownButtonFormField pattern inside edit-form sections.
class EnumPickerRow<T> extends StatelessWidget {
  const EnumPickerRow({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.displayName,
    required this.onChanged,
    this.allowClear = true,
    this.placeholder,
  });

  final String label;
  final T? value;
  final List<T> values;
  final String Function(T value) displayName;

  /// Called with the picked value, or null when "Not specified" is chosen.
  final ValueChanged<T?> onChanged;
  final bool allowClear;
  final String? placeholder;

  Future<void> _openSheet(BuildContext context) async {
    final result = await showModalBottomSheet<_EnumChoice<T>>(
      context: context,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(label, style: theme.textTheme.titleMedium),
              ),
              if (allowClear)
                ListTile(
                  leading: Icon(
                    value == null
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(
                    placeholder ?? sheetContext.l10n.diveLog_edit_notSpecified,
                  ),
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(const _EnumChoice(null)),
                ),
              for (final v in values)
                ListTile(
                  leading: Icon(
                    v == value
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(displayName(v)),
                  onTap: () => Navigator.of(sheetContext).pop(_EnumChoice(v)),
                ),
            ],
          ),
        );
      },
    );
    if (result != null) onChanged(result.value);
  }

  @override
  Widget build(BuildContext context) {
    return FormRow.picker(
      label: label,
      value: value == null ? null : displayName(value as T),
      placeholder: placeholder ?? context.l10n.diveLog_edit_notSpecified,
      onTap: () => _openSheet(context),
    );
  }
}

/// Wrapper distinguishing "picked null (clear)" from "sheet dismissed".
class _EnumChoice<T> {
  const _EnumChoice(this.value);

  final T? value;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/widgets/forms/enum_picker_row_test.dart`
Expected: PASS

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(forms): EnumPickerRow bottom-sheet enum picker row"
```

---

### Task 5: `SuggestionFormRow`

Row-styled replacement for the site form's `SuggestionField` usage: always-mounted bare text field (validator-safe inside always-open sections) with the same substring+fuzzy autocomplete overlay, plus optional `caption` (merge source label) and `trailing` (merge cycle button) slots. With `suggestions: const []` it doubles as the merge-capable plain text row for every other site field. `SuggestionField` itself stays untouched (other consumers).

**Files:**
- Create: `lib/shared/widgets/forms/suggestion_form_row.dart`
- Test: `test/shared/widgets/forms/suggestion_form_row_test.dart`

**Interfaces:**
- Consumes: `diceCoefficient` from `package:submersion/core/text/fuzzy_match.dart`, `FormStyle`.
- Produces: `SuggestionFormRow({required String label, required TextEditingController controller, required List<String> suggestions, String? Function(String?)? validator, bool enableFuzzy = false, TextCapitalization textCapitalization = TextCapitalization.none, String? placeholder, int maxLines = 1, String? caption, Widget? trailing})`.

- [ ] **Step 1: Write the failing test**

`test/shared/widgets/forms/suggestion_form_row_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

void main() {
  testWidgets('typing surfaces suggestions; tapping one fills controller', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Material(
            child: SuggestionFormRow(
              label: 'Country',
              controller: controller,
              suggestions: const ['Nederland', 'Mexico', 'USA'],
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'Ned');
    await tester.pumpAndSettle();
    expect(find.text('Nederland'), findsOneWidget);
    await tester.tap(find.text('Nederland'));
    await tester.pumpAndSettle();
    expect(controller.text, 'Nederland');
  });

  testWidgets('validator error renders; caption and trailing render', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Material(
            child: Form(
              key: formKey,
              child: SuggestionFormRow(
                label: 'Name',
                controller: controller,
                suggestions: const [],
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Name required' : null,
                caption: 'From: Alice in Wonderland (1/2)',
                trailing: const Icon(Icons.sync_alt),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('From: Alice in Wonderland (1/2)'), findsOneWidget);
    expect(find.byIcon(Icons.sync_alt), findsOneWidget);
    formKey.currentState!.validate();
    await tester.pump();
    expect(find.text('Name required'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/forms/suggestion_form_row_test.dart`
Expected: FAIL (file does not exist)

- [ ] **Step 3: Implement `suggestion_form_row.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/shared/widgets/forms/form_style.dart';

/// Row-styled autocomplete text field: label left, always-mounted bare
/// field right (safe for validators inside always-open sections), with the
/// SuggestionField dropdown behavior (substring matches, then fuzzy
/// near-matches when [enableFuzzy]).
///
/// [caption] renders muted under the row (merge source label);
/// [trailing] docks a widget after the field (merge cycle button).
/// With an empty [suggestions] list this is simply a merge-capable text
/// row — the overlay never appears.
class SuggestionFormRow extends StatefulWidget {
  const SuggestionFormRow({
    super.key,
    required this.label,
    required this.controller,
    required this.suggestions,
    this.validator,
    this.enableFuzzy = false,
    this.textCapitalization = TextCapitalization.none,
    this.placeholder,
    this.maxLines = 1,
    this.caption,
    this.trailing,
  });

  final String label;
  final TextEditingController controller;
  final List<String> suggestions;
  final String? Function(String?)? validator;
  final bool enableFuzzy;
  final TextCapitalization textCapitalization;
  final String? placeholder;
  final int maxLines;
  final String? caption;
  final Widget? trailing;

  @override
  State<SuggestionFormRow> createState() => _SuggestionFormRowState();
}

class _SuggestionFormRowState extends State<SuggestionFormRow> {
  // RawAutocomplete requires controller and focusNode together; we own the
  // node and must never dispose the external controller.
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Iterable<String> _optionsFor(String text) {
    final query = text.trim();
    if (query.isEmpty) return const Iterable<String>.empty();
    final lower = query.toLowerCase();

    final substring = widget.suggestions
        .where((s) => s.toLowerCase().contains(lower))
        .toList();
    if (!widget.enableFuzzy) return substring;

    final substringSet = substring.map((s) => s.toLowerCase()).toSet();
    final fuzzy =
        widget.suggestions
            .where((s) => !substringSet.contains(s.toLowerCase()))
            .map((s) => (s, diceCoefficient(query, s)))
            .where((pair) => pair.$2 >= 0.7)
            .toList()
          ..sort((a, b) => b.$2.compareTo(a.$2));
    return [...substring, ...fuzzy.map((pair) => pair.$1)];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: FormStyle.rowPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: widget.maxLines > 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Text(widget.label, style: theme.textTheme.bodyMedium),
              const SizedBox(width: 12),
              Expanded(
                child: RawAutocomplete<String>(
                  textEditingController: widget.controller,
                  focusNode: _focusNode,
                  optionsBuilder: (value) => _optionsFor(value.text),
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          validator: widget.validator,
                          textCapitalization: widget.textCapitalization,
                          maxLines: widget.maxLines,
                          textAlign: widget.maxLines > 1
                              ? TextAlign.start
                              : TextAlign.end,
                          style: theme.textTheme.bodyMedium,
                          decoration: InputDecoration(
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: widget.placeholder,
                          ),
                          onFieldSubmitted: (_) => onFieldSubmitted(),
                        );
                      },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return ListTile(
                                dense: true,
                                title: Text(option),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                widget.trailing!,
              ],
            ],
          ),
          if (widget.caption != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                widget.caption!,
                style: theme.textTheme.bodySmall!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/widgets/forms/suggestion_form_row_test.dart`
Expected: PASS

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(forms): SuggestionFormRow autocomplete row primitive"
```

---

### Task 6: Row-scale tanks + Gas & Gear v2 (dive page)

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/edit_sections/tank_row.dart`
- Delete: `lib/features/dive_log/presentation/widgets/edit_sections/tank_card.dart`
- Modify: `lib/shared/widgets/forms/form_overline.dart` (add `trailingText`)
- Modify: `lib/features/dive_log/presentation/widgets/dive_mode_selector.dart`
- Modify: `lib/features/dive_log/presentation/widgets/edit_sections/gas_gear_section.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (`_buildGasGearSection`, `_equipmentChild`, `_weightChild`)
- Modify: `lib/l10n/arb/app_en.arb` + 10 locale arbs
- Test: `test/features/dive_log/presentation/widgets/edit_sections/tank_row_test.dart`
- Test: `test/shared/widgets/forms/form_overline_test.dart` (trailingText case)

**Interfaces:**
- Consumes: `FormOverline`/`FormAppendRow`/`FormEmptyRow` (Task 2), `FormRow.custom`.
- Produces:
  - `TankRow({required DiveTank tank, required int tankNumber, required UnitFormatter units, required ValueChanged<DiveTank> onChanged, VoidCallback? onRemove, bool canRemove = true, bool initiallyExpanded = false})` — same parameter surface as the old `TankCard`, so the page swap is name-only.
  - `FormOverline` gains `String? trailingText` (muted text rendered before the actions — used for the weight total).
  - `DiveModeSelector` gains `bool dense = false` (segmented button only, no title/description) and `static String descriptionFor(BuildContext context, DiveMode mode)`.
  - `GasGearSection`: parameter `modeSelector` renamed to `modeChild`; `tankCards` renamed to `tanks`; `addTankLabel` unchanged but rendered by `FormAppendRow` (no `+ ` prefix — the row adds its own plus icon).
- New l10n key (this task): `diveLog_edit_overline_tanks` = "Tanks".

- [ ] **Step 1: Write the failing TankRow test**

`test/features/dive_log/presentation/widgets/edit_sections/tank_row_test.dart` — model the harness on the existing tank-related tests (grep `TankCard` under `test/` first and port anything that exercises collapsed/expanded behavior). Core cases:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/tank_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/features/settings/domain/entities/app_settings.dart';
import 'package:submersion/l10n/generated/app_localizations.dart';

Widget harness(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: Material(child: child))),
);

void main() {
  final units = UnitFormatter(const AppSettings());
  final tank = DiveTank(
    id: 't1',
    diveId: 'd1',
    volume: 11,
    startPressure: 200,
    endPressure: 50,
    gasMix: GasMix.air,
  );

  testWidgets('collapsed: identity-first two-line row with chevron', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        TankRow(tank: tank, tankNumber: 1, units: units, onChanged: (_) {}),
      ),
    );
    expect(find.textContaining('Tank 1'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    // Subtitle contains mix and pressure range on one line.
    expect(find.textContaining('Air'), findsOneWidget);
    expect(find.byType(TankEditor), findsNothing);
  });

  testWidgets('tap expands inline editor; Done collapses', (tester) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        TankRow(tank: tank, tankNumber: 1, units: units, onChanged: (_) {}),
      ),
    );
    await tester.tap(find.textContaining('Tank 1'));
    await tester.pumpAndSettle();
    expect(find.byType(TankEditor), findsOneWidget);
  });
}
```

Adjust the `DiveTank`/`GasMix`/`AppSettings` constructor calls to the real entity signatures (read `lib/features/dive_log/domain/entities/dive.dart` and the existing tank tests; `DiveTank` may require more fields — copy a fixture from the old tank tests if one exists).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_log/presentation/widgets/edit_sections/tank_row_test.dart`
Expected: FAIL (tank_row.dart does not exist)

- [ ] **Step 3: Implement `tank_row.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One tank inside Gas & Gear: identity-first two-line row at ordinary row
/// scale ("Tank 1 - Back Gas" over "Air - 11 L - 200 -> 50 bar"). Tapping
/// the row expands the full TankEditor inline; Done collapses back. No
/// sheets, no navigation.
class TankRow extends StatefulWidget {
  const TankRow({
    super.key,
    required this.tank,
    required this.tankNumber,
    required this.units,
    required this.onChanged,
    this.onRemove,
    this.canRemove = true,
    this.initiallyExpanded = false,
  });

  final DiveTank tank;
  final int tankNumber;
  final UnitFormatter units;
  final ValueChanged<DiveTank> onChanged;
  final VoidCallback? onRemove;
  final bool canRemove;
  final bool initiallyExpanded;

  @override
  State<TankRow> createState() => _TankRowState();
}

class _TankRowState extends State<TankRow> {
  late bool _expanded = widget.initiallyExpanded;

  String _pressureText() {
    final units = widget.units;
    String fmt(double? bar) =>
        bar == null ? '--' : units.convertPressure(bar).round().toString();
    return '${fmt(widget.tank.startPressure)}'
        ' → ${fmt(widget.tank.endPressure)}'
        ' ${units.pressureSymbol}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (_expanded) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.primary),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            TankEditor(
              tank: widget.tank,
              tankNumber: widget.tankNumber,
              onChanged: widget.onChanged,
              onRemove: widget.onRemove,
              canRemove: widget.canRemove,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _expanded = false),
                child: Text(l10n.diveLog_edit_tankCard_done),
              ),
            ),
          ],
        ),
      );
    }
    final subtitle = [
      widget.tank.gasMix.name,
      widget.units.formatTankVolume(
        widget.tank.volume,
        widget.tank.workingPressure,
      ),
      _pressureText(),
    ].join(' · ');
    return InkWell(
      onTap: () => setState(() => _expanded = true),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.diveLog_edit_tankCard_title(widget.tankNumber)}'
                    ' · ${widget.tank.role.displayName}',
                    style: theme.textTheme.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
```

Then delete `lib/features/dive_log/presentation/widgets/edit_sections/tank_card.dart` and fix every reference: `grep -rn "TankCard\|tank_card" lib/ test/` — the page swap in Step 6 covers `dive_edit_page.dart`; port/delete any old tank_card test file.

- [ ] **Step 4: Add `trailingText` to FormOverline**

In `form_overline.dart`, add `this.trailingText` (`final String? trailingText;`) to the constructor, and in `build` insert before the actions loop:

```dart
          if (trailingText != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                trailingText!,
                style: Theme.of(context).textTheme.labelMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
```

Add to `test/shared/widgets/forms/form_overline_test.dart`:

```dart
  testWidgets('trailingText renders before actions', (tester) async {
    await tester.pumpWidget(
      harness(const FormOverline(label: 'Weight', trailingText: '4.0 kg')),
    );
    expect(find.text('4.0 kg'), findsOneWidget);
  });
```

- [ ] **Step 5: DiveModeSelector dense mode**

In `dive_mode_selector.dart`: add `final bool dense;` + `this.dense = false` to the constructor. Extract the description switch into a public static:

```dart
  static String descriptionFor(BuildContext context, DiveMode mode) {
    switch (mode) {
      case DiveMode.oc:
        return context.l10n.diveLog_diveMode_ocDescription;
      case DiveMode.ccr:
        return context.l10n.diveLog_diveMode_ccrDescription;
      case DiveMode.scr:
        return context.l10n.diveLog_diveMode_scrDescription;
      case DiveMode.gauge:
        return context.l10n.diveLog_diveMode_gaugeDescription;
    }
  }
```

Delete the private `_getDescriptionForMode` and use `descriptionFor` at its call site. In `build`, extract the existing `SegmentedButton<DiveMode>` into a local `selector` variable and add `style: const ButtonStyle(visualDensity: VisualDensity.compact)` to it; then:

```dart
    if (dense) return selector;
    return Column( ... existing title + selector + description ... );
```

- [ ] **Step 6: Rewrite GasGearSection composition**

Replace the full contents of `gas_gear_section.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_append_row.dart';
import 'package:submersion/shared/widgets/forms/form_overline.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Group 2 of the dive form: dive mode row, CCR/SCR panels, tank rows,
/// equipment and weights. Interiors are page-provided slots; this widget
/// owns only the group chrome and composition.
class GasGearSection extends StatelessWidget {
  const GasGearSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.modeChild,
    required this.tanks,
    required this.onAddTank,
    required this.addTankLabel,
    required this.equipmentChild,
    required this.weightChild,
    this.rebreatherPanel,
    this.showTankControls = true,
    this.errorCount = 0,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String summary;

  /// Dive-mode row (+ description caption) built by the page.
  final Widget modeChild;
  final List<Widget> tanks;
  final VoidCallback onAddTank;
  final String addTankLabel;
  final Widget equipmentChild;
  final Widget weightChild;

  /// CcrSettingsPanel / ScrSettingsPanel when the mode requires one.
  final Widget? rebreatherPanel;

  /// False for gauge dives, which log depth and time only.
  final bool showTankControls;

  final int errorCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveLog_edit_group_gasGear,
      icon: MdiIcons.divingScubaTank,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      emptyInvitation: l10n.diveLog_edit_invite_gasGear,
      errorCount: errorCount,
      children: [
        modeChild,
        ?rebreatherPanel,
        if (showTankControls)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormOverline(label: l10n.diveLog_edit_overline_tanks),
              ...tanks,
              FormAppendRow(label: addTankLabel, onTap: onAddTank),
            ],
          ),
        equipmentChild,
        weightChild,
      ],
    );
  }
}
```

- [ ] **Step 7: Update the page — mode row, tank rows, equipment, weight**

In `dive_edit_page.dart`:

(a) `_buildGasGearSection` (currently ~line 2401): replace `modeSelector:`/`tankCards:` wiring with:

```dart
      modeChild: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormRow.custom(
            label: context.l10n.diveLog_diveMode_title,
            child: DiveModeSelector(
              selectedMode: _diveMode,
              dense: true,
              onChanged: (mode) {
                _markDirty();
                setState(() => _diveMode = mode);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Text(
              DiveModeSelector.descriptionFor(context, _diveMode),
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      tanks: [
        for (var i = 0; i < _tanks.length; i++)
          TankRow(
            key: ValueKey(_tanks[i].id),
            tank: _tanks[i],
            tankNumber: i + 1,
            units: units,
            onChanged: (updatedTank) {
              setState(() {
                _markDirty();
                _tanksDirty = true;
                _tanks[i] = updatedTank;
              });
            },
            onRemove: _tanks.length > 1 ? () => _removeTank(i) : null,
            canRemove: _tanks.length > 1,
          ),
      ],
```

Update the import from `edit_sections/tank_card.dart` to `edit_sections/tank_row.dart`, and add imports for `form_overline.dart`, `form_append_row.dart`, `form_empty_row.dart`.

(b) Rewrite `_equipmentChild` (currently ~line 2811). The big icon + two-line empty state and the header Row are replaced; geofence banner, equipment list, and save/clear actions are preserved:

```dart
  Widget _equipmentChild() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormOverline(
          label: context.l10n.diveLog_edit_section_equipment,
          actions: [
            FormOverlineAction(
              label: context.l10n.diveLog_edit_useSet,
              icon: Icons.folder_special,
              onPressed: _showEquipmentSetPicker,
            ),
            FormOverlineAction(
              label: context.l10n.diveLog_edit_add,
              icon: Icons.add,
              onPressed: _showEquipmentPicker,
            ),
          ],
        ),
        if (_geofenceSuggestion != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: GeofenceSuggestionBanner(
              // ... keep the existing banner arguments verbatim ...
            ),
          ),
        if (_selectedEquipment.isEmpty)
          FormEmptyRow(label: context.l10n.diveLog_edit_noEquipmentSelected)
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ... keep the existing List.generate ListTile block and the
                // trailing Save-as-set / Clear-all TextButton row verbatim ...
              ],
            ),
          ),
      ],
    );
  }
```

Carry over the existing `GeofenceSuggestionBanner(...)` arguments and the equipment `ListTile` list + save/clear row exactly as they are today (only the wrapping/padding changes as shown). Delete the old header Row and the icon+two-line empty state entirely.

(c) Rewrite `_weightChild` (currently ~line 3986) — overline with the total docked as `trailingText`, append row instead of `OutlinedButton`:

```dart
  Widget _weightChild(UnitFormatter units) {
    final totalWeight = _weights.fold(0.0, (sum, w) => sum + w.amountKg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormOverline(
          label: context.l10n.diveLog_edit_section_weight,
          trailingText: _weights.isEmpty
              ? null
              : context.l10n.diveLog_edit_weightTotal(
                  units.formatWeight(totalWeight),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._weights.asMap().entries.map((entry) {
                return _buildWeightEntryRow(entry.key, entry.value, units);
              }),
            ],
          ),
        ),
        FormAppendRow(
          label: context.l10n.diveLog_edit_addWeightEntry,
          onTap: () {
            setState(() {
              _markDirty();
              _weights.add(
                DiveWeight(
                  id: _uuid.v4(),
                  diveId: widget.diveId ?? '',
                  weightType: WeightType.integrated,
                  amountKg: 0,
                ),
              );
            });
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ... keep the existing weighting-feedback label, SegmentedButton
              // and conditional amount TextFormField verbatim ...
            ],
          ),
        ),
      ],
    );
  }
```

(d) `_gasGearSummary` stays as is.

- [ ] **Step 8: Add the l10n key (all 11 arbs)**

In `lib/l10n/arb/app_en.arb` add:

```json
  "diveLog_edit_overline_tanks": "Tanks",
  "@diveLog_edit_overline_tanks": {
    "description": "Sub-header overline above the tank rows in the Gas & Gear edit section"
  },
```

Add the translated value to all 10 locale arbs (`app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`) — e.g. de "Flaschen", es "Botellas", fr "Blocs", nl "Flessen", pt "Cilindros", it "Bombole", hu "Palackok", ar/he/zh translated equivalently. Then run: `flutter gen-l10n`

- [ ] **Step 9: Run tests**

Run: `flutter test test/features/dive_log/presentation/widgets/edit_sections/tank_row_test.dart test/shared/widgets/forms/form_overline_test.dart test/features/dive_log/presentation/pages/dive_edit_page_test.dart test/features/dive_log/presentation/pages/dive_edit_page_coverage_test.dart test/features/dive_log/presentation/pages/dive_edit_geofence_suggestion_test.dart`
Expected: PASS after finder updates (equipment header text moved into an overline — uppercase now; "+ Add Tank" centered button replaced by append row text without the `+ ` prefix in the label).

Verify no stale references: `grep -rn "TankCard\|tank_card" lib/ test/` — expect no results.

- [ ] **Step 10: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(dive-edit): row-scale tanks, Gas & Gear overlines and unified actions"
```

---

### Task 7: Dive page — Conditions/Weather onto rows, profile row, section icons

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/edit_sections/conditions_section.dart` (rewrite)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (`_buildConditionsSection`, `_environmentChild` -> `_environmentRows`, `_weatherChild` -> `_weatherRows`, `_profileChild`)
- Modify: `lib/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart`, `trip_section.dart`, `buddies_section.dart`, `experience_section.dart`, `rare_sections.dart` (icons)
- Modify: `lib/l10n/arb/app_en.arb` + 10 locale arbs
- Test: existing page suites

**Interfaces:**
- Produces: `ConditionsSection({required bool expanded, required VoidCallback onToggle, required String summary, required bool isEmpty, required String temperatureSymbol, required TextEditingController waterTempController, required TextEditingController airTempController, required List<Widget> environmentRows, required List<Widget> weatherRows, int errorCount = 0})`. The `hero`, `visibilityValue`, `environmentChild`, `weatherChild` parameters are GONE. Rows are spread into `FormSection.children` so hairline dividers separate every row.
- Produces: `RareSection` gains `required IconData icon`.
- New l10n keys (this task): see Step 5 table.

- [ ] **Step 1: Rewrite `conditions_section.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Group 3 of the dive form. Water/air temperature lead as ordinary rows
/// (the hero strip is retired); the environment and weather row lists are
/// page-provided and spread into the section so dividers separate rows.
class ConditionsSection extends StatelessWidget {
  const ConditionsSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.isEmpty,
    required this.temperatureSymbol,
    required this.waterTempController,
    required this.airTempController,
    required this.environmentRows,
    required this.weatherRows,
    this.errorCount = 0,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String summary;
  final bool isEmpty;
  final String temperatureSymbol;
  final TextEditingController waterTempController;
  final TextEditingController airTempController;
  final List<Widget> environmentRows;
  final List<Widget> weatherRows;
  final int errorCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveLog_edit_group_conditions,
      icon: Icons.waves,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      isEmpty: isEmpty,
      emptyInvitation: l10n.diveLog_edit_invite_conditions,
      errorCount: errorCount,
      children: [
        FormRow.text(
          label: l10n.diveLog_edit_label_waterTemp,
          controller: waterTempController,
          suffixText: temperatureSymbol,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
          ],
        ),
        FormRow.text(
          label: l10n.diveLog_edit_label_airTemp,
          controller: airTempController,
          suffixText: temperatureSymbol,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
          ],
        ),
        ...environmentRows,
        ...weatherRows,
      ],
    );
  }
}
```

- [ ] **Step 2: Rewrite the page's environment/weather builders as row lists**

In `dive_edit_page.dart`, replace `_environmentChild(units)` with `_environmentRows(units)` returning `List<Widget>` (delete the old method):

```dart
  List<Widget> _environmentRows(UnitFormatter units) {
    final l10n = context.l10n;
    final altitudeWarning = _getAltitudeWarning(units);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: DiveTypeMultiSelectField(
          selectedTypeIds: _selectedDiveTypeIds,
          onChanged: (ids) => setState(() => _selectedDiveTypeIds = ids),
        ),
      ),
      EnumPickerRow<Visibility>(
        label: l10n.diveLog_edit_label_visibility,
        value: _selectedVisibility == Visibility.unknown
            ? null
            : _selectedVisibility,
        values: Visibility.values
            .where((v) => v != Visibility.unknown)
            .toList(),
        displayName: (v) => v.displayName,
        onChanged: (v) =>
            setState(() => _selectedVisibility = v ?? Visibility.unknown),
      ),
      EnumPickerRow<WaterType>(
        label: l10n.diveLog_edit_label_waterType,
        value: _waterType,
        values: WaterType.values,
        displayName: (v) => v.displayName,
        onChanged: (v) => setState(() => _waterType = v),
      ),
      EnumPickerRow<CurrentDirection>(
        label: l10n.diveLog_edit_label_currentDirection,
        value: _currentDirection,
        values: CurrentDirection.values,
        displayName: (v) => v.displayName,
        onChanged: (v) => setState(() => _currentDirection = v),
      ),
      EnumPickerRow<CurrentStrength>(
        label: l10n.diveLog_edit_label_currentStrength,
        value: _currentStrength,
        values: CurrentStrength.values,
        displayName: (v) => v.displayName,
        onChanged: (v) => setState(() => _currentStrength = v),
      ),
      FormRow.text(
        label: l10n.diveLog_edit_label_swellHeight,
        controller: _swellHeightController,
        suffixText: units.depthSymbol,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormRow.text(
            label: l10n.diveLog_edit_label_altitude,
            controller: _altitudeController,
            suffixText: units.altitudeSymbol,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          if (altitudeWarning != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Text(
                altitudeWarning,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: _getAltitudeWarningColor(units),
                ),
              ),
            ),
        ],
      ),
      EnumPickerRow<EntryMethod>(
        label: l10n.diveLog_edit_label_entryMethod,
        value: _entryMethod,
        values: EntryMethod.values,
        displayName: (v) => v.displayName,
        onChanged: (v) => setState(() => _entryMethod = v),
      ),
      EnumPickerRow<EntryMethod>(
        label: l10n.diveLog_edit_label_exitMethod,
        value: _exitMethod,
        values: EntryMethod.values,
        displayName: (v) => v.displayName,
        onChanged: (v) => setState(() => _exitMethod = v),
      ),
    ];
  }
```

Check `_getAltitudeWarning`'s return type before using it here (if it returns a non-nullable/empty-string sentinel, adapt the null check accordingly).

Replace `_weatherChild(units)` with `_weatherRows(units)` (delete the old method). The surface-pressure helper/hint and prefix icon are dropped (quiet design; the placeholder keeps the default value hint):

```dart
  List<Widget> _weatherRows(UnitFormatter units) {
    final l10n = context.l10n;
    final canFetchWeather =
        _selectedSite != null && _selectedSite!.hasCoordinates;
    return [
      FormOverline(
        label: l10n.diveLog_edit_subsection_weather,
        actions: [
          FormOverlineAction(
            label: l10n.diveLog_edit_button_fetchWeather,
            icon: Icons.cloud_download,
            busy: _isFetchingWeather,
            onPressed: canFetchWeather ? () => _fetchWeather(units) : null,
          ),
        ],
      ),
      FormRow.text(
        label: l10n.diveLog_edit_label_humidity,
        controller: _humidityController,
        suffixText: '%',
        keyboardType: TextInputType.number,
      ),
      FormRow.text(
        label: l10n.diveLog_edit_label_windSpeed,
        controller: _windSpeedController,
        suffixText: units.windSpeedSymbol,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      EnumPickerRow<CurrentDirection>(
        label: l10n.diveLog_edit_label_windDirection,
        value: _windDirection,
        values: CurrentDirection.values,
        displayName: (v) => v.displayName,
        onChanged: (v) => setState(() => _windDirection = v),
      ),
      FormRow.text(
        label: l10n.diveLog_edit_label_surfacePressure,
        controller: _surfacePressureController,
        suffixText: 'mbar',
        placeholder: l10n.diveLog_edit_surfacePressureDefault,
        keyboardType: TextInputType.number,
      ),
      EnumPickerRow<CloudCover>(
        label: l10n.diveLog_edit_label_cloudCover,
        value: _cloudCover,
        values: CloudCover.values,
        displayName: (v) => v.displayName,
        onChanged: (v) => setState(() => _cloudCover = v),
      ),
      EnumPickerRow<Precipitation>(
        label: l10n.diveLog_edit_label_precipitation,
        value: _precipitation,
        values: Precipitation.values,
        displayName: (v) => v.displayName,
        onChanged: (v) => setState(() => _precipitation = v),
      ),
      FormRow.text(
        label: l10n.diveLog_edit_label_weatherDescription,
        controller: _weatherDescriptionController,
        maxLines: 2,
      ),
    ];
  }
```

Update `_buildConditionsSection`:

```dart
  Widget _buildConditionsSection(UnitFormatter units) {
    return ConditionsSection(
      expanded: _isExpanded('conditions', defaultValue: false),
      onToggle: () => _toggleSection('conditions', defaultValue: false),
      summary: _conditionsSummary(units),
      isEmpty: _conditionsIsEmpty(),
      temperatureSymbol: units.temperatureSymbol,
      waterTempController: _waterTempController,
      airTempController: _airTempController,
      environmentRows: _environmentRows(units),
      weatherRows: _weatherRows(units),
    );
  }
```

Add imports to the page: `enum_picker_row.dart` (FormOverline/FormRow already imported from Task 6). NOTE: `Visibility` here is the app's dive-visibility enum, not Flutter's widget — the page already disambiguates; keep whatever import prefix it uses today.

- [ ] **Step 3: Profile child becomes a row**

Replace `_profileChild` (currently ~line 2316) with:

```dart
  Widget _profileChild() {
    final l10n = context.l10n;
    final hasProfile = _existingDive?.profile.isNotEmpty == true;
    final profileLength = _existingDive?.profile.length ?? 0;
    if (hasProfile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormRow.picker(
            label: l10n.diveLog_edit_row_diveProfile,
            value: l10n.diveLog_edit_profile_points(profileLength),
            onTap: () => _openProfileEditor(_existingDive!.id),
          ),
          Consumer(
            builder: (context, ref, _) {
              final outliersAsync = ref.watch(
                outlierSuggestionProvider(_existingDive!.id),
              );
              return outliersAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (outliers) {
                  if (outliers.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ActionChip(
                        avatar: const Icon(Icons.warning_amber, size: 18),
                        label: Text(
                          l10n.diveLog_edit_profile_outliers(outliers.length),
                        ),
                        onPressed: () => _openProfileEditor(
                          _existingDive!.id,
                          initialMode: 'outlier',
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      );
    }
    if (widget.isEditing) {
      return FormRow.picker(
        label: l10n.diveLog_edit_row_diveProfile,
        value: null,
        placeholder: l10n.diveLog_edit_profile_draw,
        onTap: () => context.pushNamed(
          'editProfile',
          pathParameters: {'diveId': widget.diveId!},
          queryParameters: {'mode': 'draw'},
        ),
      );
    }
    return FormRow.display(
      label: l10n.diveLog_edit_row_diveProfile,
      value: l10n.diveLog_edit_profile_none,
    );
  }
```

This also replaces four hardcoded English strings ('Dive Profile', '$n points', 'Edit Profile', 'Draw Profile', the outlier chip) with l10n keys.

- [ ] **Step 4: Section icons**

- `the_dive_section.dart`: add `icon: Icons.show_chart,` to its `FormSection` call.
- `trip_section.dart`: add `icon: Icons.flight_takeoff,`.
- `buddies_section.dart`: add `icon: Icons.group_outlined,`.
- `experience_section.dart`: add `icon: Icons.star_outline,`.
- `rare_sections.dart`: add `required this.icon` (`final IconData icon;`) and pass `icon: icon` to `FormSection`. In `dive_edit_page.dart`, pass `icon: Icons.school_outlined` in `_buildCourseGroupSection` and `icon: Icons.tune` in `_buildCustomFieldsGroupSection`.

- [ ] **Step 5: New l10n keys (all 11 arbs + gen-l10n)**

Add to `app_en.arb` (with `@`-metadata descriptions), then translated values to all 10 locale arbs, then run `flutter gen-l10n`:

| Key | English value |
|---|---|
| `diveLog_edit_row_diveProfile` | `Dive profile` |
| `diveLog_edit_profile_points` | `{count, plural, one{1 point} other{{count} points}}` (placeholder `count`, type `num`) |
| `diveLog_edit_profile_draw` | `Draw a profile` |
| `diveLog_edit_profile_none` | `Not recorded` |
| `diveLog_edit_profile_outliers` | `{count, plural, one{1 potential outlier detected} other{{count} potential outliers detected}}` |

- [ ] **Step 6: Run tests**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_page_test.dart test/features/dive_log/presentation/pages/dive_edit_page_coverage_test.dart test/features/dive_log/presentation/pages/dive_surface_gps_section_test.dart test/features/dive_log/presentation/pages/bulk_dive_edit_form_test.dart`
Expected: PASS after finder updates (dropdowns are now picker rows opening bottom sheets — tests that used `DropdownButtonFormField` finders must tap the row then tap the sheet option; 'Edit Profile' button finder becomes the profile row).

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(dive-edit): conditions and weather on rows, profile row, section icons"
```

---

### Task 8: Site form — merge plumbing, Identity + Location sections

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/edit_sections/merge_field_extras.dart`
- Create: `lib/features/dive_sites/presentation/widgets/edit_sections/identity_section.dart`
- Create: `lib/features/dive_sites/presentation/widgets/edit_sections/location_section.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart`
- Test: `test/features/dive_sites/presentation/pages/site_edit_merge_page_test.dart` (finder updates)

**Interfaces:**
- Produces:
  - `MergeFieldExtras({required String sourceLabel, required VoidCallback onCycle})` — per-field merge affordance data.
  - `MergeCycleButton({required VoidCallback onPressed})` — the small `Icons.sync_alt` icon button (visuals ported from the page's `_buildMergeCycleButton`, tooltip `diveSites_edit_merge_fieldSourceCycleTooltip`).
  - `MergeSourceRow({required String sourceLabel, required VoidCallback onCycle})` — caption + cycle button row for non-text fields (coordinates, difficulty, rating).
  - `IdentitySection({required List<DiveSite> allSites, String? excludeId, required TextEditingController nameController, descriptionController, countryController, regionController, cityController, islandController, bodyOfWaterController, required String? Function(String?) nameValidator, MergeFieldExtras? Function(String key)? mergeExtras, int errorCount = 0})` — always open.
  - `LocationSection({required bool expanded, required VoidCallback? onToggle, required String summary, required bool isEmpty, int errorCount = 0, required TextEditingController latitudeController, longitudeController, altitudeController, required String? Function(String?) latValidator, lonValidator, altitudeValidator, required bool isGettingLocation, required VoidCallback onUseMyLocation, required VoidCallback onPickFromMap, required UnitFormatter units, MergeFieldExtras? coordinatesExtras, MergeFieldExtras? altitudeExtras})`.
- Consumes: `SuggestionFormRow` (Task 5), `FormRow.text` bare persistent (Task 3), site suggestion helpers, `SimilarValueHint`, `AltitudeGroup` (`lib/core/deco/altitude_calculator.dart`).

- [ ] **Step 1: Create `merge_field_extras.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Per-field merge affordance: which source site the current value came
/// from, and how to cycle to the next candidate.
class MergeFieldExtras {
  const MergeFieldExtras({required this.sourceLabel, required this.onCycle});

  final String sourceLabel;
  final VoidCallback onCycle;
}

/// Small tonal cycle button shown next to a field in merge mode.
class MergeCycleButton extends StatelessWidget {
  const MergeCycleButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      tooltip: context.l10n.diveSites_edit_merge_fieldSourceCycleTooltip,
      icon: const Icon(Icons.sync_alt, size: 18),
      iconSize: 18,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: const EdgeInsets.all(6),
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// Caption + cycle button row for fields that are not text rows
/// (coordinates, difficulty, rating).
class MergeSourceRow extends StatelessWidget {
  const MergeSourceRow({
    super.key,
    required this.sourceLabel,
    required this.onCycle,
  });

  final String sourceLabel;
  final VoidCallback onCycle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              sourceLabel,
              style: theme.textTheme.bodySmall!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          MergeCycleButton(onPressed: onCycle),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Create `identity_section.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/site_suggestions.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/merge_field_extras.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/similar_value_hint.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

/// Site group 1 (always open): name, description, country, region, city,
/// island, body of water — all as suggestion-capable rows. Merge mode adds
/// a source caption + cycle button per field via [mergeExtras].
class IdentitySection extends StatelessWidget {
  const IdentitySection({
    super.key,
    required this.allSites,
    this.excludeId,
    required this.nameController,
    required this.descriptionController,
    required this.countryController,
    required this.regionController,
    required this.cityController,
    required this.islandController,
    required this.bodyOfWaterController,
    required this.nameValidator,
    this.mergeExtras,
    this.errorCount = 0,
  });

  final List<DiveSite> allSites;
  final String? excludeId;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController countryController;
  final TextEditingController regionController;
  final TextEditingController cityController;
  final TextEditingController islandController;
  final TextEditingController bodyOfWaterController;
  final String? Function(String?) nameValidator;
  final MergeFieldExtras? Function(String key)? mergeExtras;
  final int errorCount;

  Widget _row(
    BuildContext context, {
    required String key,
    required String label,
    required TextEditingController controller,
    List<String> suggestions = const [],
    bool enableFuzzy = false,
    String? placeholder,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    final extras = mergeExtras?.call(key);
    return SuggestionFormRow(
      label: label,
      controller: controller,
      suggestions: suggestions,
      enableFuzzy: enableFuzzy,
      textCapitalization: TextCapitalization.words,
      placeholder: placeholder,
      validator: validator,
      maxLines: maxLines,
      caption: extras?.sourceLabel,
      trailing: extras == null
          ? null
          : MergeCycleButton(onPressed: extras.onCycle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveSites_edit_group_identity,
      icon: Icons.bookmark_outline,
      expanded: true,
      onToggle: null,
      errorCount: errorCount,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _row(
              context,
              key: 'name',
              label: l10n.diveSites_edit_field_siteName_label,
              controller: nameController,
              suggestions: suggestedSiteNames(allSites, excludeId: excludeId),
              enableFuzzy: true,
              placeholder: l10n.diveSites_edit_field_siteName_hint,
              validator: nameValidator,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: nameController,
                builder: (context, name, _) {
                  return SimilarValueHint(
                    query: name.text,
                    candidates: suggestedSiteNames(
                      allSites,
                      excludeId: excludeId,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        _row(
          context,
          key: 'description',
          label: l10n.diveSites_edit_field_description_label,
          controller: descriptionController,
          placeholder: l10n.diveSites_edit_field_description_hint,
          maxLines: 3,
        ),
        _row(
          context,
          key: 'country',
          label: l10n.diveSites_edit_field_country_label,
          controller: countryController,
          suggestions: suggestedCountries(allSites),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: countryController,
          builder: (context, country, _) => _row(
            context,
            key: 'region',
            label: l10n.diveSites_edit_field_region_label,
            controller: regionController,
            suggestions: suggestedRegions(allSites, country.text),
            enableFuzzy: true,
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: countryController,
          builder: (context, country, _) =>
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: regionController,
                builder: (context, region, _) => _row(
                  context,
                  key: 'city',
                  label: l10n.diveSites_edit_field_city_label,
                  controller: cityController,
                  suggestions: suggestedCities(
                    allSites,
                    country.text,
                    region.text,
                  ),
                  enableFuzzy: true,
                ),
              ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: countryController,
          builder: (context, country, _) => _row(
            context,
            key: 'island',
            label: l10n.diveSites_edit_field_island_label,
            controller: islandController,
            suggestions: suggestedIslands(allSites, country.text),
            enableFuzzy: true,
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: countryController,
          builder: (context, country, _) => _row(
            context,
            key: 'bodyOfWater',
            label: l10n.diveSites_edit_field_bodyOfWater_label,
            controller: bodyOfWaterController,
            suggestions: suggestedBodiesOfWater(allSites, country.text),
            enableFuzzy: true,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Create `location_section.dart`**

Port `_buildAltitudeGroupIndicator` from the page verbatim into this file as a private function `Widget _altitudeGroupIndicator(BuildContext context, AltitudeGroup group)`. Section widget:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/merge_field_extras.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Site group 2: latitude/longitude rows, locate/pick actions, altitude
/// row with the altitude-group indicator.
class LocationSection extends StatelessWidget {
  const LocationSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.isEmpty,
    this.errorCount = 0,
    required this.latitudeController,
    required this.longitudeController,
    required this.altitudeController,
    required this.latValidator,
    required this.lonValidator,
    required this.altitudeValidator,
    required this.isGettingLocation,
    required this.onUseMyLocation,
    required this.onPickFromMap,
    required this.units,
    this.coordinatesExtras,
    this.altitudeExtras,
  });

  final bool expanded;
  final VoidCallback? onToggle;
  final String summary;
  final bool isEmpty;
  final int errorCount;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final TextEditingController altitudeController;
  final String? Function(String?) latValidator;
  final String? Function(String?) lonValidator;
  final String? Function(String?) altitudeValidator;
  final bool isGettingLocation;
  final VoidCallback onUseMyLocation;
  final VoidCallback onPickFromMap;
  final UnitFormatter units;
  final MergeFieldExtras? coordinatesExtras;
  final MergeFieldExtras? altitudeExtras;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveSites_edit_group_location,
      icon: Icons.place_outlined,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      isEmpty: isEmpty,
      emptyInvitation: l10n.diveSites_edit_invite_location,
      errorCount: errorCount,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (coordinatesExtras != null)
              MergeSourceRow(
                sourceLabel: coordinatesExtras!.sourceLabel,
                onCycle: coordinatesExtras!.onCycle,
              ),
            FormRow.text(
              label: l10n.diveSites_edit_gps_latitude_label,
              controller: latitudeController,
              placeholder: l10n.diveSites_edit_gps_latitude_hint,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              validator: latValidator,
            ),
            FormRow.text(
              label: l10n.diveSites_edit_gps_longitude_label,
              controller: longitudeController,
              placeholder: l10n.diveSites_edit_gps_longitude_hint,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              validator: lonValidator,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: isGettingLocation ? null : onUseMyLocation,
                    icon: isGettingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, size: 16),
                    label: Text(
                      isGettingLocation
                          ? l10n.diveSites_edit_gps_gettingLocation
                          : l10n.diveSites_edit_gps_useMyLocation,
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: onPickFromMap,
                    icon: const Icon(Icons.map, size: 16),
                    label: Text(l10n.diveSites_edit_gps_pickFromMap),
                  ),
                ],
              ),
            ),
          ],
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: altitudeController,
          builder: (context, altitude, _) {
            final altitudeInput = double.tryParse(altitude.text);
            final altitudeMeters = altitudeInput != null
                ? units.altitudeToMeters(altitudeInput)
                : null;
            final group = AltitudeGroup.fromAltitude(altitudeMeters);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (altitudeExtras != null)
                  MergeSourceRow(
                    sourceLabel: altitudeExtras!.sourceLabel,
                    onCycle: altitudeExtras!.onCycle,
                  ),
                FormRow.text(
                  label: l10n.diveSites_edit_section_altitude,
                  controller: altitudeController,
                  suffixText: units.altitudeSymbol,
                  placeholder: l10n.diveSites_edit_altitude_hint,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: altitudeValidator,
                ),
                if (group != AltitudeGroup.seaLevel && altitudeMeters != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: _altitudeGroupIndicator(context, group),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
```

Note the altitude label: the old boxed field used `diveSites_edit_altitude_label(symbol)` ("Altitude (m)"); the row shows the unit as `suffixText`, so use the plain `diveSites_edit_section_altitude` label instead.

- [ ] **Step 4: Wire the page**

In `site_edit_page.dart`:

(a) Add the merge-extras builders (near the other merge helpers) and the extracted altitude validator:

```dart
  MergeFieldExtras? _mergeExtras(String key) {
    final candidates = _mergeTextCandidates[key];
    if (!widget.isMerging || candidates == null || candidates.length < 2) {
      return null;
    }
    final index = _mergeFieldIndices[key] ?? 0;
    return MergeFieldExtras(
      sourceLabel: context.l10n.diveSites_edit_merge_fieldSourceLabel(
        candidates[index].siteName,
        index + 1,
        candidates.length,
      ),
      onCycle: () => _cycleTextField(key),
    );
  }

  MergeFieldExtras? _coordinateExtras() {
    if (!widget.isMerging || _coordinateCandidates.length < 2) return null;
    final index = _mergeFieldIndices['coordinates'] ?? 0;
    return MergeFieldExtras(
      sourceLabel: context.l10n.diveSites_edit_merge_fieldSourceLabel(
        _coordinateCandidates[index].siteName,
        index + 1,
        _coordinateCandidates.length,
      ),
      onCycle: _cycleCoordinates,
    );
  }

  String? _altitudeValidatorFn(String? value) {
    if (value != null && value.isNotEmpty) {
      final altitude = double.tryParse(value);
      if (altitude == null || altitude < 0) {
        return context.l10n.diveSites_edit_altitude_validation;
      }
    }
    return null;
  }
```

(b) In `_buildForm`, replace the Identity `FormSection(...)` block (lines ~675-868) with:

```dart
          IdentitySection(
            allSites: allSites,
            excludeId: _originalSite?.id,
            nameController: _nameController,
            descriptionController: _descriptionController,
            countryController: _countryController,
            regionController: _regionController,
            cityController: _cityController,
            islandController: _islandController,
            bodyOfWaterController: _bodyOfWaterController,
            nameValidator: _nameValidatorFn,
            mergeExtras: widget.isMerging ? _mergeExtras : null,
            errorCount: _identityErrorCount(),
          ),
```

and the Location `FormSection(...)` block with:

```dart
          LocationSection(
            expanded: _siteSectionExpanded('location'),
            onToggle: widget.isMerging
                ? null
                : () => _toggleSiteSection('location'),
            summary: _locationSummary(units),
            isEmpty: _locationIsEmpty(),
            errorCount: _locationErrorCount(),
            latitudeController: _latitudeController,
            longitudeController: _longitudeController,
            altitudeController: _altitudeController,
            latValidator: _latValidatorFn,
            lonValidator: _lonValidatorFn,
            altitudeValidator: _altitudeValidatorFn,
            isGettingLocation: _isGettingLocation,
            onUseMyLocation: _useMyLocation,
            onPickFromMap: _pickFromMap,
            units: units,
            coordinatesExtras: _coordinateExtras(),
            altitudeExtras: _mergeExtras('altitude'),
          ),
```

(c) Delete `_buildGpsSection`, `_buildAltitudeSection`, `_buildAltitudeGroupIndicator` from the page; add imports for the two new section files + `merge_field_extras.dart`.

- [ ] **Step 5: Run tests, format, analyze, commit**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_merge_page_test.dart`
Expected: PASS after finder updates (merge cycle buttons still `Icons.sync_alt`; source labels are now captions under rows instead of `helperText`; boxed field label finders become row label finders).

Also grep for any other site-edit page tests and run them: `ls test/features/dive_sites/presentation/pages/`

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(site-edit): Identity and Location sections extracted onto rows"
```

---

### Task 9: Site form — Dive Info, Access & Safety, Life & Notes sections

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/edit_sections/dive_info_section.dart`
- Create: `lib/features/dive_sites/presentation/widgets/edit_sections/access_safety_section.dart`
- Create: `lib/features/dive_sites/presentation/widgets/edit_sections/life_notes_section.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart`
- Test: `test/features/dive_sites/presentation/pages/site_edit_merge_page_test.dart`

**Interfaces:**
- Produces:
  - `DiveInfoSection({required bool expanded, required VoidCallback? onToggle, required String summary, required bool isEmpty, required TextEditingController minDepthController, maxDepthController, required String depthSymbol, required SiteDifficulty? difficulty, required ValueChanged<SiteDifficulty?> onDifficultyChanged, required int rating, required ValueChanged<int> onRatingChanged, required VoidCallback onRatingCleared, MergeFieldExtras? Function(String key)? mergeExtras, MergeFieldExtras? difficultyExtras, MergeFieldExtras? ratingExtras})`.
  - `AccessSafetySection({required bool expanded, required VoidCallback? onToggle, required String summary, required bool isEmpty, required TextEditingController accessNotesController, mooringNumberController, parkingInfoController, hazardsController, MergeFieldExtras? Function(String key)? mergeExtras})`.
  - `LifeNotesSection({required bool expanded, required VoidCallback? onToggle, required String summary, required bool isEmpty, required List<Species> species, required VoidCallback onAddSpecies, required ValueChanged<Species> onRemoveSpecies, required TextEditingController notesController, MergeFieldExtras? Function(String key)? mergeExtras, required bool showShareToggle, required bool isShared, required ValueChanged<bool> onShareChanged})`.
- Consumes: `SuggestionFormRow` (empty suggestions = merge-capable text row), `FormRow.rating` with `onClear` (Task 3), `FormOverline`/`FormEmptyRow` (Task 2), `MergeFieldExtras`/`MergeSourceRow` (Task 8).

- [ ] **Step 1: Create `dive_info_section.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/merge_field_extras.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

/// Site group 3: min/max depth rows, difficulty chips row, rating row.
class DiveInfoSection extends StatelessWidget {
  const DiveInfoSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.isEmpty,
    required this.minDepthController,
    required this.maxDepthController,
    required this.depthSymbol,
    required this.difficulty,
    required this.onDifficultyChanged,
    required this.rating,
    required this.onRatingChanged,
    required this.onRatingCleared,
    this.mergeExtras,
    this.difficultyExtras,
    this.ratingExtras,
  });

  final bool expanded;
  final VoidCallback? onToggle;
  final String summary;
  final bool isEmpty;
  final TextEditingController minDepthController;
  final TextEditingController maxDepthController;
  final String depthSymbol;
  final SiteDifficulty? difficulty;
  final ValueChanged<SiteDifficulty?> onDifficultyChanged;
  final int rating;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onRatingCleared;
  final MergeFieldExtras? Function(String key)? mergeExtras;
  final MergeFieldExtras? difficultyExtras;
  final MergeFieldExtras? ratingExtras;

  Widget _depthRow(
    BuildContext context, {
    required String key,
    required String label,
    required TextEditingController controller,
  }) {
    final extras = mergeExtras?.call(key);
    return SuggestionFormRow(
      label: label,
      controller: controller,
      suggestions: const [],
      placeholder: depthSymbol,
      caption: extras?.sourceLabel,
      trailing: extras == null
          ? null
          : MergeCycleButton(onPressed: extras.onCycle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveSites_edit_group_diveInfo,
      icon: Icons.info_outline,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      isEmpty: isEmpty,
      emptyInvitation: l10n.diveSites_edit_invite_diveInfo,
      children: [
        _depthRow(
          context,
          key: 'minDepth',
          label: l10n.diveSites_edit_depth_minLabel(depthSymbol),
          controller: minDepthController,
        ),
        _depthRow(
          context,
          key: 'maxDepth',
          label: l10n.diveSites_edit_depth_maxLabel(depthSymbol),
          controller: maxDepthController,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (difficultyExtras != null)
              MergeSourceRow(
                sourceLabel: difficultyExtras!.sourceLabel,
                onCycle: difficultyExtras!.onCycle,
              ),
            FormRow.custom(
              label: l10n.diveSites_edit_section_difficultyLevel,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 4,
                children: SiteDifficulty.values.map((value) {
                  final isSelected = difficulty == value;
                  return ChoiceChip(
                    label: Text(value.displayName),
                    selected: isSelected,
                    visualDensity: VisualDensity.compact,
                    onSelected: (selected) =>
                        onDifficultyChanged(selected ? value : null),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ratingExtras != null)
              MergeSourceRow(
                sourceLabel: ratingExtras!.sourceLabel,
                onCycle: ratingExtras!.onCycle,
              ),
            FormRow.rating(
              label: l10n.diveSites_edit_section_rating,
              value: rating,
              onChanged: onRatingChanged,
              onClear: onRatingCleared,
            ),
          ],
        ),
      ],
    );
  }
}
```

Depth label note: `diveSites_edit_depth_minLabel(symbol)` already embeds the unit symbol in the label, so the row needs no suffix. If the rendered label reads awkwardly as a row label, switch both to plain new keys — but prefer reusing the existing keys first.

- [ ] **Step 2: Create `access_safety_section.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/merge_field_extras.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

/// Site group 4: access notes, mooring number, parking, hazards — plain
/// merge-capable rows (inner icon headers and helper texts removed).
class AccessSafetySection extends StatelessWidget {
  const AccessSafetySection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.isEmpty,
    required this.accessNotesController,
    required this.mooringNumberController,
    required this.parkingInfoController,
    required this.hazardsController,
    this.mergeExtras,
  });

  final bool expanded;
  final VoidCallback? onToggle;
  final String summary;
  final bool isEmpty;
  final TextEditingController accessNotesController;
  final TextEditingController mooringNumberController;
  final TextEditingController parkingInfoController;
  final TextEditingController hazardsController;
  final MergeFieldExtras? Function(String key)? mergeExtras;

  Widget _row(
    BuildContext context, {
    required String key,
    required String label,
    required TextEditingController controller,
    String? placeholder,
    int maxLines = 1,
  }) {
    final extras = mergeExtras?.call(key);
    return SuggestionFormRow(
      label: label,
      controller: controller,
      suggestions: const [],
      placeholder: placeholder,
      maxLines: maxLines,
      caption: extras?.sourceLabel,
      trailing: extras == null
          ? null
          : MergeCycleButton(onPressed: extras.onCycle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveSites_edit_group_accessSafety,
      icon: Icons.shield_outlined,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      isEmpty: isEmpty,
      emptyInvitation: l10n.diveSites_edit_invite_accessSafety,
      children: [
        _row(
          context,
          key: 'accessNotes',
          label: l10n.diveSites_edit_access_accessNotes_label,
          controller: accessNotesController,
          placeholder: l10n.diveSites_edit_access_accessNotes_hint,
          maxLines: 3,
        ),
        _row(
          context,
          key: 'mooringNumber',
          label: l10n.diveSites_edit_access_mooringNumber_label,
          controller: mooringNumberController,
          placeholder: l10n.diveSites_edit_access_mooringNumber_hint,
        ),
        _row(
          context,
          key: 'parkingInfo',
          label: l10n.diveSites_edit_access_parkingInfo_label,
          controller: parkingInfoController,
          placeholder: l10n.diveSites_edit_access_parkingInfo_hint,
          maxLines: 2,
        ),
        _row(
          context,
          key: 'hazards',
          label: l10n.diveSites_edit_hazards_label,
          controller: hazardsController,
          placeholder: l10n.diveSites_edit_hazards_hint,
          maxLines: 3,
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Create `life_notes_section.dart`**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/merge_field_extras.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_empty_row.dart';
import 'package:submersion/shared/widgets/forms/form_overline.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

/// Site group 5: expected marine life (overline + chips), notes row,
/// share-with-all-profiles toggle.
class LifeNotesSection extends StatelessWidget {
  const LifeNotesSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.isEmpty,
    required this.species,
    required this.onAddSpecies,
    required this.onRemoveSpecies,
    required this.notesController,
    this.mergeExtras,
    required this.showShareToggle,
    required this.isShared,
    required this.onShareChanged,
  });

  final bool expanded;
  final VoidCallback? onToggle;
  final String summary;
  final bool isEmpty;
  final List<Species> species;
  final VoidCallback onAddSpecies;
  final ValueChanged<Species> onRemoveSpecies;
  final TextEditingController notesController;
  final MergeFieldExtras? Function(String key)? mergeExtras;
  final bool showShareToggle;
  final bool isShared;
  final ValueChanged<bool> onShareChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final notesExtras = mergeExtras?.call('notes');
    return FormSection(
      label: l10n.diveSites_edit_group_lifeNotes,
      icon: Icons.menu_book_outlined,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      isEmpty: isEmpty,
      emptyInvitation: l10n.diveSites_edit_invite_lifeNotes,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormOverline(
              label: l10n.diveSites_edit_section_expectedMarineLife,
              actions: [
                FormOverlineAction(
                  label: l10n.diveSites_edit_marineLife_addButton,
                  icon: Icons.add,
                  onPressed: onAddSpecies,
                ),
              ],
            ),
            if (species.isEmpty)
              FormEmptyRow(label: l10n.diveSites_edit_marineLife_empty)
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: species.map((s) {
                    return Chip(
                      avatar: Icon(
                        MdiIcons.fish,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      label: Text(s.commonName),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => onRemoveSpecies(s),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
        SuggestionFormRow(
          label: l10n.diveSites_edit_field_notes_label,
          controller: notesController,
          suggestions: const [],
          placeholder: l10n.diveSites_edit_field_notes_hint,
          maxLines: 4,
          caption: notesExtras?.sourceLabel,
          trailing: notesExtras == null
              ? null
              : MergeCycleButton(onPressed: notesExtras.onCycle),
        ),
        if (showShareToggle)
          FormRow.toggle(
            label: l10n.common_label_shareWithAllProfiles,
            value: isShared,
            onChanged: onShareChanged,
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Wire the page and delete the old builders**

In `site_edit_page.dart`:

(a) Add the difficulty/rating extras builders next to `_coordinateExtras`:

```dart
  MergeFieldExtras? _difficultyExtras() {
    if (!widget.isMerging || _difficultyCandidates.length < 2) return null;
    final index = _mergeFieldIndices['difficulty'] ?? 0;
    return MergeFieldExtras(
      sourceLabel: context.l10n.diveSites_edit_merge_fieldSourceLabel(
        _difficultyCandidates[index].siteName,
        index + 1,
        _difficultyCandidates.length,
      ),
      onCycle: _cycleDifficulty,
    );
  }

  MergeFieldExtras? _ratingExtras() {
    if (!widget.isMerging || _ratingCandidates.length < 2) return null;
    final index = _mergeFieldIndices['rating'] ?? 0;
    return MergeFieldExtras(
      sourceLabel: context.l10n.diveSites_edit_merge_fieldSourceLabel(
        _ratingCandidates[index].siteName,
        index + 1,
        _ratingCandidates.length,
      ),
      onCycle: _cycleRating,
    );
  }
```

(b) In `_buildForm`, replace the Dive Info / Access & Safety / Life & Notes `FormSection(...)` blocks with:

```dart
          DiveInfoSection(
            expanded: _siteSectionExpanded('diveInfo'),
            onToggle: widget.isMerging
                ? null
                : () => _toggleSiteSection('diveInfo'),
            summary: _diveInfoSummary(),
            isEmpty: _diveInfoSummary().isEmpty,
            minDepthController: _minDepthController,
            maxDepthController: _maxDepthController,
            depthSymbol: units.depthSymbol,
            difficulty: _difficulty,
            onDifficultyChanged: (value) => setState(() {
              _difficulty = value;
              _hasChanges = true;
            }),
            rating: _rating.round(),
            onRatingChanged: (value) => setState(() {
              _rating = value.toDouble();
              _hasChanges = true;
            }),
            onRatingCleared: () => setState(() {
              _rating = 0;
              _hasChanges = true;
            }),
            mergeExtras: widget.isMerging ? _mergeExtras : null,
            difficultyExtras: _difficultyExtras(),
            ratingExtras: _ratingExtras(),
          ),
          AccessSafetySection(
            expanded: _siteSectionExpanded('access'),
            onToggle: widget.isMerging
                ? null
                : () => _toggleSiteSection('access'),
            summary: _accessSummary(),
            isEmpty: _accessSummary().isEmpty,
            accessNotesController: _accessNotesController,
            mooringNumberController: _mooringNumberController,
            parkingInfoController: _parkingInfoController,
            hazardsController: _hazardsController,
            mergeExtras: widget.isMerging ? _mergeExtras : null,
          ),
          LifeNotesSection(
            expanded: _siteSectionExpanded('life'),
            onToggle: widget.isMerging ? null : () => _toggleSiteSection('life'),
            summary: _lifeNotesSummary(),
            isEmpty: _lifeNotesSummary().isEmpty,
            species: _expectedSpecies,
            onAddSpecies: _showSpeciesPicker,
            onRemoveSpecies: (s) => setState(() {
              _expectedSpecies = _expectedSpecies
                  .where((existing) => existing.id != s.id)
                  .toList();
              _hasChanges = true;
            }),
            notesController: _notesController,
            mergeExtras: widget.isMerging ? _mergeExtras : null,
            showShareToggle: ref
                .watch(allDiversProvider)
                .maybeWhen(data: (d) => d.length >= 2, orElse: () => false),
            isShared: _isShared,
            onShareChanged: _onShareToggled,
          ),
```

(c) Delete from the page: `_buildRatingSection`, `_buildDepthSection`, `_buildDifficultySection`, `_buildAccessSection`, `_buildSafetySection`, `_buildExpectedMarineLifeSection`, `_withMergeTextDecoration`, `_buildMergeCycleButton`, `_mergeSectionSourceLabel`. Remove now-unused imports: `stat_strip.dart`, `suggestion_field.dart`, `similar_value_hint.dart`, `site_suggestions.dart`, `mdi_icons.dart`, `altitude_calculator.dart`, `form_section.dart` (the page no longer constructs FormSection directly — verify with grep before removing each import; `form_row.dart` is likely still needed elsewhere in the file).

- [ ] **Step 5: Run tests, format, analyze, commit**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_merge_page_test.dart`
Expected: PASS after finder updates.

Sanity greps (expect no matches):
`grep -n "StatStrip\|SuggestionField(" lib/features/dive_sites/presentation/pages/site_edit_page.dart`

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(site-edit): Dive Info, Access & Safety, Life & Notes sections on rows"
```

---

### Task 10: Retire the hero slot, token cleanup, full verification

**Files:**
- Modify: `lib/shared/widgets/forms/form_section.dart` (remove `hero`)
- Modify: `lib/shared/widgets/forms/form_style.dart` (comment + dead-token cleanup)
- Modify: `test/shared/widgets/forms/form_section_test.dart` (remove hero test)
- Modify: `docs/superpowers/specs/2026-07-17-edit-form-chrome-redesign-design.md` (Deviations section)

- [ ] **Step 1: Verify nothing passes `hero:` anymore**

Run: `grep -rn "hero:" lib/features/ lib/shared/widgets/forms/`
Expected: no matches in edit-form code (StatStrip's own file and trip-story usages do not use a `hero:` argument — if anything else surfaces, fix it first).

- [ ] **Step 2: Remove the slot**

In `form_section.dart`: delete the `hero` field, its constructor entry, its doc comment, and the `if (hero != null)` block in `_buildBody`. In `form_section_test.dart`: delete the "hero renders as first body child" test.

- [ ] **Step 3: Token cleanup in `form_style.dart`**

- Update the header comment to reference `docs/superpowers/specs/assets/2026-07-17-edit-form-chrome-redesign-mockup.html`.
- Run: `grep -rn "FormStyle.labelStyle\|FormStyle.labelGap" lib/` — if the only consumers were the old FormSection chrome, delete `labelStyle` and `labelGap`. Keep `heroPadding`/`heroValueStyle`/`heroUnitStyle`/`heroLabelStyle` (StatStrip still uses them — verify with `grep -n "FormStyle." lib/shared/widgets/forms/stat_strip.dart` before touching).

- [ ] **Step 4: Full verification sweep**

```bash
dart format .
flutter analyze
```

Run every touched suite:

```bash
flutter test \
  test/shared/widgets/forms/form_section_test.dart \
  test/shared/widgets/forms/form_row_test.dart \
  test/shared/widgets/forms/form_overline_test.dart \
  test/shared/widgets/forms/form_append_row_test.dart \
  test/shared/widgets/forms/form_empty_row_test.dart \
  test/shared/widgets/forms/enum_picker_row_test.dart \
  test/shared/widgets/forms/suggestion_form_row_test.dart \
  test/shared/widgets/forms/stat_strip_test.dart \
  test/shared/widgets/forms/edit_form_scaffold_test.dart \
  test/shared/widgets/forms/add_section_row_test.dart
```

```bash
flutter test \
  test/features/dive_log/presentation/widgets/edit_sections/tank_row_test.dart \
  test/features/dive_log/presentation/pages/dive_edit_page_test.dart \
  test/features/dive_log/presentation/pages/dive_edit_page_coverage_test.dart \
  test/features/dive_log/presentation/pages/dive_edit_geofence_suggestion_test.dart \
  test/features/dive_log/presentation/pages/dive_surface_gps_section_test.dart \
  test/features/dive_log/presentation/pages/bulk_dive_edit_form_test.dart \
  test/features/dive_sites/presentation/pages/site_edit_merge_page_test.dart
```

Expected: all PASS.

- [ ] **Step 5: Record deviations in the spec**

Append a `## Deviations` section to `docs/superpowers/specs/2026-07-17-edit-form-chrome-redesign-design.md` recording anything that diverged during implementation (known upfront: site rating star tooltips are dropped by the shared rating row; bulk-form interiors keep their outlined fields, inheriting only the v2 chrome; GPS/hazards/surface-pressure helper texts removed per the quiet design).

- [ ] **Step 6: Manual smoke checklist (run `flutter run -d macos`)**

Verify, in at least the default theme light AND dark (spot-check one more theme):

1. Dive edit: all six sections render as header-in-card; chevron fixed on the header in both states; The Dive has no chevron.
2. Collapse/expand Gas & Gear — only the body animates; summary fades into the header.
3. Tank renders as a two-line row; tap opens the inline editor; Done collapses; gauge mode (dive mode = gauge) hides the tank block.
4. Conditions: temps as rows; visibility/water type open bottom sheets; weather fetch works from the WEATHER overline (site with GPS selected).
5. Dive profile row opens the profile editor.
6. Site edit: Identity suggestions still pop under rows (type a country); Name required error appears under the row and in no-badge form.
7. Site Location: Use my location / Pick from map work; altitude indicator appears for a mountain-lake altitude.
8. Site merge (two sites selected → merge): all sections forced open, per-field source captions + cycle buttons work.
9. Bulk dive edit opens and saves.
10. Empty states are single quiet lines; no stray "+ Add" bars or oversized icons anywhere.

- [ ] **Step 7: Final commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "refactor(forms): retire hero slot and stale chrome tokens"
```

---

## Plan self-review notes (already applied)

- Spec coverage: chrome (T1), row language (T3-T5, T7-T9), tanks (T6), heroes retired (T7 dive, T9 site — site Dive Info hero replaced by depth rows in T9; the T1-T8 interim keeps the old hero rendering via the transitional slot), sub-headers/actions/empty states (T2, T6, T7, T9), icons (T6-T9), l10n (T6, T7), tests (every task), merge/bulk preserved (T8-T9 / T6 note).
- The `Interfaces` blocks give later tasks the exact constructor signatures introduced earlier; if a signature must change mid-implementation, update the consuming task's wiring code in the same commit.
- Entity constructor details in the TankRow test (Step 1) are the one place the implementer must adapt code to reality — the instruction says to port fixtures from existing tank tests rather than invent them.
