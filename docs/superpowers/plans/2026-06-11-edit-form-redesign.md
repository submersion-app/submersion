# Edit Form Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat 18-card dive edit form and the site edit form with a shared, collapsible, stat-forward form system (`lib/shared/widgets/forms/`) per the approved spec `docs/superpowers/specs/2026-06-11-edit-form-redesign-design.md`.

**Architecture:** Seven presentational primitives (FormStyle, FormSection, StatStrip/StatCell, FormRow, UnitField, AddSectionRow, EditFormScaffold) are built TDD-first, then the dive edit page is rebuilt group-by-group (The Dive, Gas & Gear, Conditions, Trip, Buddies, Experience, rare) with each commit leaving the page working, then the site edit page (Identity, Location, Dive info, Access & safety, Life & notes) including merge mode. Pages keep all existing state management (`ConsumerStatefulWidget`, controllers, repositories, picker sheets); the primitives are pure presentation.

**Tech Stack:** Flutter/Dart (SDK ^3.10, Material 3 on in all 5 themes), Riverpod, `flutter gen-l10n` (template `lib/l10n/arb/app_en.arb` + 10 locales: ar, de, es, fr, he, hu, it, nl, pt, zh). **No new pub dependencies.**

**Conventions that bind every task:**

- TDD: write the failing test first, watch it fail, implement, watch it pass.
- After each task: `dart format lib/ test/` must produce no changes (run it before committing).
- Run `flutter analyze` (whole project, never piped through `tail`/`grep`) before each commit.
- Commit messages: conventional commits, **no Co-Authored-By lines**.
- Run specific test files, not broad directories (Bash timeout protection).
- No emojis. Immutability (final fields). All user-visible strings via `context.l10n` (import `package:submersion/l10n/l10n_extension.dart`).
- **Every new l10n key lands in `app_en.arb` (with `@`-metadata) AND all 10 locale arbs in the same task** — no English fallbacks. After arb edits run `flutter gen-l10n`.
- All numeric display/input through `UnitFormatter` (`lib/core/utils/unit_formatter.dart`). Never hard-code units.
- Colors only from `Theme.of(context).colorScheme` / `textTheme` — the app ships 5 theme variants (submersion, deep, tropical, minimalist, console) and the primitives must work in all of them, light and dark.

---

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `lib/shared/widgets/forms/form_style.dart` | Design tokens: radii, paddings, label/hero text styles, group color, max content width |
| `lib/shared/widgets/forms/form_section.dart` | Collapsible group: outside uppercase label, tonal surface, expanded / collapsed-summary / empty-invitation states, error badge |
| `lib/shared/widgets/forms/stat_strip.dart` | Hero stat row: `StatStrip` + `StatCell` (display or tap-to-edit-in-place, optional use-profile-value affordance) |
| `lib/shared/widgets/forms/form_row.dart` | Label/value rows: `.text`, `.picker`, `.display`, `.toggle`, `.rating`, `.custom` |
| `lib/shared/widgets/forms/unit_field.dart` | Boxed numeric `TextFormField` with unit suffix for dense clusters |
| `lib/shared/widgets/forms/add_section_row.dart` | Trailing "+ Add: Course · Custom fields" row for rare sections |
| `lib/shared/widgets/forms/edit_form_scaffold.dart` | Shared page shell: AppBar / embedded header, save/cancel, PopScope discard guard, max-width centering |
| `lib/features/dive_log/presentation/widgets/pickers/site_picker_sheet.dart` | Moved `_SitePickerSheet` + `_SiteWithDistance` (public, behavior unchanged) |
| `lib/features/dive_log/presentation/widgets/pickers/species_picker_sheet.dart` | Moved `_SpeciesPickerSheet` (public) |
| `lib/features/dive_log/presentation/widgets/pickers/edit_sighting_sheet.dart` | Moved `_EditSightingSheet` (public) |
| `lib/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart` | Moved `_EquipmentPickerSheet` (public) |
| `lib/features/dive_log/presentation/widgets/pickers/equipment_set_picker_sheet.dart` | Moved `_EquipmentSetPickerSheet` + `_EquipmentSetTile` (public sheet, private tile) |
| `lib/features/dive_log/presentation/widgets/pickers/computer_source_sheet.dart` | Moved `_ComputerSourceSelectionSheet` (public) |
| `lib/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart` | Group 1: hero (max depth, bottom time, avg depth) + dive number, entry/exit, site, profile rows |
| `lib/features/dive_log/presentation/widgets/edit_sections/tank_card.dart` | Per-tank card: collapsed stat strip (pressure, mix, volume) / expanded inline `TankEditor` |
| `lib/features/dive_log/presentation/widgets/edit_sections/gas_gear_section.dart` | Group 2: mode, CCR/SCR panels, tank cards, equipment, weights |
| `lib/features/dive_log/presentation/widgets/edit_sections/conditions_section.dart` | Group 3: hero (water temp, air temp, visibility) + environment + weather rows |
| `lib/features/dive_log/presentation/widgets/edit_sections/trip_section.dart` | Group 4: trip picker + suggestion, dive center picker |
| `lib/features/dive_log/presentation/widgets/edit_sections/buddies_section.dart` | Group 5: BuddyPicker |
| `lib/features/dive_log/presentation/widgets/edit_sections/experience_section.dart` | Group 6: rating, marine life, notes, tags |
| `lib/features/dive_log/presentation/widgets/edit_sections/rare_sections.dart` | Course + custom fields sections (behind AddSectionRow) |
| `lib/features/dive_sites/presentation/widgets/edit_sections/identity_section.dart` | Site group 1: name, country/region, description |
| `lib/features/dive_sites/presentation/widgets/edit_sections/location_section.dart` | Site group 2: GPS, locate/map actions, altitude |
| `lib/features/dive_sites/presentation/widgets/edit_sections/dive_info_section.dart` | Site group 3: depth hero, difficulty, rating |
| `lib/features/dive_sites/presentation/widgets/edit_sections/access_safety_section.dart` | Site group 4: access, mooring, parking, hazards |
| `lib/features/dive_sites/presentation/widgets/edit_sections/life_notes_section.dart` | Site group 5: species, notes, share toggle |
| `test/shared/widgets/forms/form_section_test.dart` | FormSection states, toggle, badge, semantics |
| `test/shared/widgets/forms/stat_strip_test.dart` | StatCell display/edit swap, profile affordance |
| `test/shared/widgets/forms/form_row_test.dart` | Row variants, inline edit |
| `test/shared/widgets/forms/unit_field_test.dart` | Unit suffix, numeric input |
| `test/shared/widgets/forms/add_section_row_test.dart` | Entries render + tap |
| `test/shared/widgets/forms/edit_form_scaffold_test.dart` | Modes, save/cancel, discard guard |

**Modified:**

| File | Change |
|---|---|
| `lib/features/dive_log/presentation/pages/dive_edit_page.dart` | 4,909 → thin coordinator (<~500 lines): state/controllers/save + expansion defaults + section composition; all `_build*Section` methods and embedded picker classes removed |
| `lib/features/dive_sites/presentation/pages/site_edit_page.dart` | 2,182 → thin coordinator: state/save/merge logic + section composition |
| `lib/l10n/arb/app_en.arb` + 10 locale arbs | New `forms_*`, `diveLog_edit_group_*`/summary, `diveSites_edit_group_*` keys (added incrementally per task, always all 11 files) |
| `test/features/dive_log/presentation/pages/dive_edit_page_test.dart` | Existing 4 bottomTime tests adapted; new expansion-default and error-auto-expand tests |
| `test/features/dive_sites/presentation/pages/site_edit_page_test.dart` | Section-header finders and `find.ancestor(... Card)` updated to new structure |
| `test/features/dive_sites/presentation/pages/site_edit_merge_page_test.dart` | Same finder updates; merge behavior itself unchanged |

**Key existing APIs (read before relevant tasks, do not modify):**

- `UnitFormatter` (`lib/core/utils/unit_formatter.dart`): `convertDepth/depthToMeters/depthSymbol`, `convertTemperature/temperatureToCelsius/temperatureSymbol`, `convertPressure/pressureToBar/pressureSymbol`, `convertWeight/weightToKg/weightSymbol/formatWeight`, `convertAltitude/altitudeToMeters`, `convertWindSpeed/windSpeedToMs/windSpeedSymbol`, `convertVolume/volumeToLiters/volumeSymbol/formatTankVolume`, `formatDate`.
- `TankEditor` (`lib/features/dive_log/presentation/widgets/tank_editor.dart`): `TankEditor({required DiveTank tank, required int tankNumber, required TankChangeCallback onChanged, VoidCallback? onRemove, bool canRemove})`.
- `CcrSettingsPanel` / `ScrSettingsPanel`: keep constructor APIs unchanged; they render inside Gas & Gear when `_diveMode` is ccr/scr (today gated at dive_edit_page.dart:1689-1793).
- `ResponsiveBreakpoints` (`lib/shared/widgets/master_detail/responsive_breakpoints.dart`).
- Dive page state fields and `_saveDive(units)` at dive_edit_page.dart:93-525 and 3439-3751 — reused as-is by the coordinator.

---

### Task 0: Baseline verification

**Files:** none (git + verification only)

- [ ] **Step 0.1: Confirm branch and clean tree**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
git branch --show-current && git status --short
```

Expected: `feat/edit-form-redesign`, no output from status (the committed spec is already on this branch).

- [ ] **Step 0.2: Baseline analyze and page tests**

```bash
flutter analyze
flutter test test/features/dive_log/presentation/pages/dive_edit_page_test.dart test/features/dive_sites/presentation/pages/site_edit_page_test.dart test/features/dive_sites/presentation/pages/site_edit_merge_page_test.dart
```

Expected: analyze clean; all existing tests pass. If anything fails here, STOP and report — do not start on a broken baseline.

---

### Task 1: FormStyle tokens

**Files:**
- Create: `lib/shared/widgets/forms/form_style.dart`

Pure constants/helpers — no dedicated test file (exercised by every widget test from Task 2 on).

- [ ] **Step 1.1: Create the tokens file**

```dart
import 'package:flutter/material.dart';

/// Design tokens for the shared form system. Initial values match the
/// design-freeze mockup (docs/superpowers/specs/assets/
/// 2026-06-11-edit-form-redesign-mockup.html); tune here, never inline.
abstract final class FormStyle {
  /// Corner radius of section groups and collapsed bars.
  static const double groupRadius = 13;

  /// Padding inside a label/value row.
  static const EdgeInsets rowPadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 11);

  /// Padding around a hero stat strip.
  static const EdgeInsets heroPadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 10);

  /// Vertical gap between a section label and its group surface.
  static const double labelGap = 4;

  /// Vertical gap between consecutive sections.
  static const double sectionGap = 14;

  /// Horizontal page padding around the whole form.
  static const EdgeInsets pagePadding = EdgeInsets.all(16);

  /// Forms never stretch wider than this on desktop windows.
  static const double maxContentWidth = 640;

  /// Uppercase section label, rendered outside the group surface.
  static TextStyle labelStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.labelSmall!.copyWith(
      letterSpacing: 0.9,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  /// Tonal background of group surfaces and collapsed bars.
  static Color groupColor(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerLow;

  /// Hairline divider color between rows.
  static Color dividerColor(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  /// Big number in a hero stat cell.
  static TextStyle heroValueStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.titleLarge!.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: theme.colorScheme.onSurface,
    );
  }

  /// Small unit suffix inside a hero value (" m", " min").
  static TextStyle heroUnitStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.labelMedium!.copyWith(
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  /// Uppercase micro-label under a hero value.
  static TextStyle heroLabelStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.labelSmall!.copyWith(
      fontSize: 9,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }
}
```

- [ ] **Step 1.2: Verify and commit**

```bash
dart format lib/shared/widgets/forms/
flutter analyze
git add lib/shared/widgets/forms/form_style.dart
git commit -m "feat(forms): add FormStyle design tokens for shared form system"
```

Expected: analyze clean.

---

### Task 2: FormSection

**Files:**
- Create: `lib/shared/widgets/forms/form_section.dart`
- Test: `test/shared/widgets/forms/form_section_test.dart`
- Modify: `lib/l10n/arb/app_en.arb` + 10 locale arbs (1 new key)

- [ ] **Step 2.1: Add the l10n key (all 11 arbs)**

In `lib/l10n/arb/app_en.arb` add (alphabetical placement near other `forms_` keys — this is the first, place before the first `g`-prefixed key):

```json
"forms_section_issues": "{count, plural, one{1 issue} other{{count} issues}}",
"@forms_section_issues": {
  "description": "Badge on a collapsed form section that contains validation errors",
  "placeholders": {
    "count": {"type": "int"}
  }
},
```

Add the translated key (no `@`-metadata in locale files) to each of `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb` — translate naturally per language (e.g. de: `"{count, plural, one{1 Problem} other{{count} Probleme}}"`), keeping the ICU plural structure intact. Then:

```bash
flutter gen-l10n
```

Expected: regenerates `lib/l10n/arb/app_localizations*.dart` without errors.

- [ ] **Step 2.2: Write the failing tests**

Create `test/shared/widgets/forms/form_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('FormSection expanded', () {
    testWidgets('renders label, hero and children', (tester) async {
      await tester.pumpWidget(_wrap(FormSection(
        label: 'The Dive',
        expanded: true,
        onToggle: () {},
        hero: const Text('HERO'),
        children: const [Text('row one'), Text('row two')],
      )));
      expect(find.text('THE DIVE'), findsOneWidget);
      expect(find.text('HERO'), findsOneWidget);
      expect(find.text('row one'), findsOneWidget);
      expect(find.text('row two'), findsOneWidget);
    });

    testWidgets('always-expanded section (null onToggle) shows no chevron',
        (tester) async {
      await tester.pumpWidget(_wrap(const FormSection(
        label: 'The Dive',
        expanded: true,
        onToggle: null,
        children: [Text('row one')],
      )));
      expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
    });

    testWidgets('collapse chevron calls onToggle', (tester) async {
      var toggled = 0;
      await tester.pumpWidget(_wrap(FormSection(
        label: 'Conditions',
        expanded: true,
        onToggle: () => toggled++,
        children: const [Text('row one')],
      )));
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
      expect(toggled, 1);
    });
  });

  group('FormSection collapsed', () {
    testWidgets('with data shows summary, hides children, tap expands',
        (tester) async {
      var toggled = 0;
      await tester.pumpWidget(_wrap(FormSection(
        label: 'Conditions',
        expanded: false,
        onToggle: () => toggled++,
        summary: 'Salt - 24 C - 15 m vis',
        children: const [Text('row one')],
      )));
      expect(find.text('Salt - 24 C - 15 m vis'), findsOneWidget);
      expect(find.text('row one'), findsNothing);
      await tester.tap(find.text('Salt - 24 C - 15 m vis'));
      expect(toggled, 1);
    });

    testWidgets('empty shows invitation with add affordance', (tester) async {
      await tester.pumpWidget(_wrap(FormSection(
        label: 'Conditions',
        expanded: false,
        onToggle: () {},
        isEmpty: true,
        emptyInvitation: 'Add conditions',
        children: const [Text('row one')],
      )));
      expect(find.text('Add conditions'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('row one'), findsNothing);
    });

    testWidgets('error badge shows localized issue count', (tester) async {
      await tester.pumpWidget(_wrap(FormSection(
        label: 'Gas & Gear',
        expanded: false,
        onToggle: () {},
        summary: '2x AL80',
        errorCount: 2,
        children: const [Text('row one')],
      )));
      expect(find.text('2 issues'), findsOneWidget);
    });

    testWidgets('no badge when errorCount is zero', (tester) async {
      await tester.pumpWidget(_wrap(FormSection(
        label: 'Gas & Gear',
        expanded: false,
        onToggle: () {},
        summary: '2x AL80',
        children: const [Text('row one')],
      )));
      expect(find.textContaining('issue'), findsNothing);
    });
  });
}
```

- [ ] **Step 2.3: Run tests to verify they fail**

```bash
flutter test test/shared/widgets/forms/form_section_test.dart
```

Expected: FAIL — `form_section.dart` does not exist.

- [ ] **Step 2.4: Implement FormSection**

Create `lib/shared/widgets/forms/form_section.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_style.dart';

/// A collapsible form group: uppercase label outside, tonal rounded surface.
///
/// Three resting states:
/// - expanded: [hero] (optional) + [children] with hairline dividers
/// - collapsed with data: single bar showing [summary]
/// - collapsed and empty: muted [emptyInvitation] bar with a + affordance
///
/// Expansion is owned by the page (smart-collapse defaults live there);
/// pass [onToggle] null for sections that are never collapsible.
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.label,
    required this.expanded,
    required this.onToggle,
    required this.children,
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
  final String? summary;
  final String? emptyInvitation;
  final bool isEmpty;
  final int errorCount;
  final Widget? hero;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: FormStyle.labelStyle(context),
                ),
              ),
              if (expanded && onToggle != null)
                InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.keyboard_arrow_up,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: FormStyle.labelGap),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: expanded ? _buildExpanded(context) : _buildCollapsed(context),
        ),
      ],
    );
  }

  Widget _buildExpanded(BuildContext context) {
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: FormStyle.dividerColor(context),
    );
    final rows = <Widget>[];
    if (hero != null) {
      rows.add(hero!);
      if (children.isNotEmpty) rows.add(divider);
    }
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) rows.add(divider);
    }
    return Material(
      color: FormStyle.groupColor(context),
      borderRadius: BorderRadius.circular(FormStyle.groupRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
    );
  }

  Widget _buildCollapsed(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = errorCount > 0;
    final Widget content;
    if (isEmpty) {
      content = Row(
        children: [
          Expanded(
            child: Text(
              emptyInvitation ?? '',
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.add, size: 18, color: theme.colorScheme.primary),
        ],
      );
    } else {
      content = Row(
        children: [
          Expanded(
            child: Text(
              summary ?? '',
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasError) ...[
            const SizedBox(width: 8),
            Icon(Icons.warning_amber_rounded,
                size: 16, color: theme.colorScheme.error),
            const SizedBox(width: 4),
            Text(
              context.l10n.forms_section_issues(errorCount),
              style: theme.textTheme.labelMedium!.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else
            Icon(Icons.chevron_right,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
        ],
      );
    }
    return Material(
      color: FormStyle.groupColor(context),
      borderRadius: BorderRadius.circular(FormStyle.groupRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          decoration: hasError
              ? BoxDecoration(
                  border: Border(
                    left: BorderSide(color: theme.colorScheme.error, width: 3),
                  ),
                )
              : null,
          padding: FormStyle.rowPadding,
          child: Semantics(
            button: true,
            label: label,
            child: content,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2.5: Run tests to verify they pass**

```bash
flutter test test/shared/widgets/forms/form_section_test.dart
```

Expected: all 7 tests PASS.

- [ ] **Step 2.6: Format, analyze, commit**

```bash
dart format lib/ test/
flutter analyze
git add lib/shared/widgets/forms/ test/shared/widgets/forms/ lib/l10n/
git commit -m "feat(forms): add collapsible FormSection with summary, invitation and error states"
```

---

### Task 3: StatStrip and StatCell

**Files:**
- Create: `lib/shared/widgets/forms/stat_strip.dart`
- Test: `test/shared/widgets/forms/stat_strip_test.dart`
- Modify: `lib/l10n/arb/app_en.arb` + 10 locale arbs (1 new key)

- [ ] **Step 3.1: Add the l10n key (all 11 arbs)**

`app_en.arb` (next to `forms_section_issues`):

```json
"forms_statCell_useProfileValue": "Use {value} from profile",
"@forms_statCell_useProfileValue": {
  "description": "Menu action offering to replace a stat with the value computed from the dive profile",
  "placeholders": {
    "value": {"type": "String"}
  }
},
```

Translate into the 10 locale arbs (keep `{value}` placeholder), then `flutter gen-l10n`.

- [ ] **Step 3.2: Write the failing tests**

Create `test/shared/widgets/forms/stat_strip_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/stat_strip.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('StatCell display', () {
    testWidgets('shows value, unit and label', (tester) async {
      final controller = TextEditingController(text: '28.4');
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(StatStrip(cells: [
        StatCell(label: 'Max depth', unit: 'm', controller: controller),
      ])));
      expect(find.text('28.4'), findsOneWidget);
      expect(find.text(' m'), findsOneWidget);
      expect(find.text('MAX DEPTH'), findsOneWidget);
    });

    testWidgets('empty controller shows placeholder dash', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(StatStrip(cells: [
        StatCell(label: 'Avg depth', unit: 'm', controller: controller),
      ])));
      expect(find.text('--'), findsOneWidget);
    });

    testWidgets('display-only cell renders displayValue', (tester) async {
      await tester.pumpWidget(_wrap(const StatStrip(cells: [
        StatCell(label: 'Mix', displayValue: 'EAN32'),
      ])));
      expect(find.text('EAN32'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('StatCell editing', () {
    testWidgets('tap swaps to text field, commit updates display',
        (tester) async {
      final controller = TextEditingController(text: '28.4');
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(StatStrip(cells: [
        StatCell(label: 'Max depth', unit: 'm', controller: controller),
      ])));
      await tester.tap(find.text('28.4'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), '30.1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(controller.text, '30.1');
      expect(find.byType(TextField), findsNothing);
      expect(find.text('30.1'), findsOneWidget);
    });

    testWidgets('display-only cell does not enter edit mode', (tester) async {
      await tester.pumpWidget(_wrap(const StatStrip(cells: [
        StatCell(label: 'Mix', displayValue: 'EAN32'),
      ])));
      await tester.tap(find.text('EAN32'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('StatCell profile affordance', () {
    testWidgets('glyph shown when profileValue differs; menu applies it',
        (tester) async {
      final controller = TextEditingController(text: '28.4');
      addTearDown(controller.dispose);
      String? applied;
      await tester.pumpWidget(_wrap(StatStrip(cells: [
        StatCell(
          label: 'Max depth',
          unit: 'm',
          controller: controller,
          profileValue: '28.6',
          onUseProfileValue: (v) => applied = v,
        ),
      ])));
      expect(find.byIcon(Icons.sync_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.sync_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Use 28.6 from profile'), findsOneWidget);
      await tester.tap(find.text('Use 28.6 from profile'));
      await tester.pumpAndSettle();
      expect(applied, '28.6');
    });

    testWidgets('glyph hidden when value matches profile', (tester) async {
      final controller = TextEditingController(text: '28.6');
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(StatStrip(cells: [
        StatCell(
          label: 'Max depth',
          unit: 'm',
          controller: controller,
          profileValue: '28.6',
          onUseProfileValue: (_) {},
        ),
      ])));
      expect(find.byIcon(Icons.sync_outlined), findsNothing);
    });
  });
}
```

- [ ] **Step 3.3: Run tests to verify they fail**

```bash
flutter test test/shared/widgets/forms/stat_strip_test.dart
```

Expected: FAIL — `stat_strip.dart` does not exist.

- [ ] **Step 3.4: Implement StatStrip and StatCell**

Create `lib/shared/widgets/forms/stat_strip.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_style.dart';

/// Hero numbers row: big values with units and uppercase micro-labels,
/// separated by hairline vertical dividers. Editable cells swap to an
/// in-place numeric field on tap.
class StatStrip extends StatelessWidget {
  const StatStrip({super.key, required this.cells});

  final List<StatCell> cells;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < cells.length; i++) {
      children.add(Expanded(child: cells[i]));
      if (i < cells.length - 1) {
        children.add(VerticalDivider(
          width: 1,
          thickness: 1,
          color: FormStyle.dividerColor(context),
        ));
      }
    }
    return Padding(
      padding: FormStyle.heroPadding,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }
}

/// One cell of a [StatStrip]. Editable when [controller] is provided,
/// display-only when [displayValue] is provided (exactly one is required).
class StatCell extends StatefulWidget {
  const StatCell({
    super.key,
    required this.label,
    this.unit,
    this.controller,
    this.displayValue,
    this.profileValue,
    this.onUseProfileValue,
    this.keyboardType =
        const TextInputType.numberWithOptions(decimal: true),
  }) : assert(
          (controller == null) != (displayValue == null),
          'Provide exactly one of controller or displayValue',
        );

  final String label;
  final String? unit;
  final TextEditingController? controller;
  final String? displayValue;

  /// Value computed from the dive profile; when it differs from the current
  /// text, a sync glyph offers to apply it via [onUseProfileValue].
  final String? profileValue;
  final ValueChanged<String>? onUseProfileValue;
  final TextInputType keyboardType;

  @override
  State<StatCell> createState() => _StatCellState();
}

class _StatCellState extends State<StatCell> {
  bool _editing = false;
  final _focusNode = FocusNode();

  bool get _editable => widget.controller != null;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) {
        setState(() => _editing = false);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    if (!_editable) return;
    setState(() => _editing = true);
    widget.controller!.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.controller!.text.length,
    );
  }

  bool get _showProfileGlyph =>
      widget.profileValue != null &&
      widget.onUseProfileValue != null &&
      widget.profileValue != widget.controller?.text;

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return _buildEditor(context);
    }
    final text = _editable
        ? (widget.controller!.text.isEmpty ? '--' : widget.controller!.text)
        : widget.displayValue!;
    final value = Semantics(
      button: _editable,
      label: widget.label,
      value: '$text ${widget.unit ?? ''}'.trim(),
      child: InkWell(
        onTap: _editable ? _startEditing : null,
        borderRadius: BorderRadius.circular(9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    text,
                    style: FormStyle.heroValueStyle(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.unit != null)
                  Text(' ${widget.unit}',
                      style: FormStyle.heroUnitStyle(context)),
                if (_showProfileGlyph) _buildProfileGlyph(context),
              ],
            ),
            const SizedBox(height: 2),
            Text(widget.label.toUpperCase(),
                style: FormStyle.heroLabelStyle(context)),
          ],
        ),
      ),
    );
    // Rebuild the resting view whenever the controller changes externally
    // (load, use-profile-value, calculate buttons).
    if (_editable) {
      return AnimatedBuilder(
        animation: widget.controller!,
        builder: (_, __) => value,
      );
    }
    return value;
  }

  Widget _buildProfileGlyph(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: context.l10n
          .forms_statCell_useProfileValue(widget.profileValue!),
      padding: EdgeInsets.zero,
      icon: Icon(Icons.sync_outlined,
          size: 14, color: Theme.of(context).colorScheme.primary),
      onSelected: widget.onUseProfileValue,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: widget.profileValue!,
          child: Text(context.l10n
              .forms_statCell_useProfileValue(widget.profileValue!)),
        ),
      ],
    );
  }

  Widget _buildEditor(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        border: Border.all(color: theme.colorScheme.primary, width: 1.5),
        borderRadius: BorderRadius.circular(9),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            autofocus: true,
            textAlign: TextAlign.center,
            keyboardType: widget.keyboardType,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.,:-]')),
            ],
            style: FormStyle.heroValueStyle(context),
            decoration: const InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              filled: false,
            ),
            onSubmitted: (_) => setState(() => _editing = false),
          ),
          const SizedBox(height: 2),
          Text(
            widget.unit == null
                ? widget.label.toUpperCase()
                : '${widget.label.toUpperCase()} (${widget.unit})',
            style: FormStyle.heroLabelStyle(context),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3.5: Run tests to verify they pass**

```bash
flutter test test/shared/widgets/forms/stat_strip_test.dart
```

Expected: all 7 tests PASS.

- [ ] **Step 3.6: Format, analyze, commit**

```bash
dart format lib/ test/
flutter analyze
git add lib/shared/widgets/forms/ test/shared/widgets/forms/ lib/l10n/
git commit -m "feat(forms): add StatStrip hero stats with in-place editing and profile affordance"
```

---

### Task 4: FormRow variants

**Files:**
- Create: `lib/shared/widgets/forms/form_row.dart`
- Test: `test/shared/widgets/forms/form_row_test.dart`

- [ ] **Step 4.1: Write the failing tests**

Create `test/shared/widgets/forms/form_row_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Material(child: child)));

void main() {
  group('FormRow.text', () {
    testWidgets('resting shows label and value; tap enters inline edit',
        (tester) async {
      final controller = TextEditingController(text: 'Blue Hole');
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(FormRow.text(
        label: 'Name',
        controller: controller,
      )));
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Blue Hole'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      await tester.tap(find.text('Blue Hole'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'Great Blue Hole');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(controller.text, 'Great Blue Hole');
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Great Blue Hole'), findsOneWidget);
    });

    testWidgets('empty value shows placeholder', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(FormRow.text(
        label: 'Name',
        controller: controller,
        placeholder: 'Add name',
      )));
      expect(find.text('Add name'), findsOneWidget);
    });

    testWidgets('alwaysEditing renders persistent field', (tester) async {
      final controller = TextEditingController(text: 'x');
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(FormRow.text(
        label: 'Name',
        controller: controller,
        alwaysEditing: true,
      )));
      expect(find.byType(TextFormField), findsOneWidget);
    });
  });

  group('FormRow.picker', () {
    testWidgets('shows value, chevron, and fires onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(FormRow.picker(
        label: 'Site',
        value: 'Blue Hole',
        onTap: () => taps++,
      )));
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      await tester.tap(find.text('Blue Hole'));
      expect(taps, 1);
    });

    testWidgets('null value shows placeholder', (tester) async {
      await tester.pumpWidget(_wrap(FormRow.picker(
        label: 'Site',
        value: null,
        placeholder: 'Add site',
        onTap: () {},
      )));
      expect(find.text('Add site'), findsOneWidget);
    });
  });

  group('other variants', () {
    testWidgets('display row is not tappable', (tester) async {
      await tester.pumpWidget(_wrap(FormRow.display(
        label: 'Surface interval',
        value: '1:42',
      )));
      expect(find.text('1:42'), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('toggle row flips switch', (tester) async {
      var on = false;
      await tester.pumpWidget(_wrap(StatefulBuilder(
        builder: (context, setState) => FormRow.toggle(
          label: 'Shared',
          value: on,
          onChanged: (v) => setState(() => on = v),
        ),
      )));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(on, isTrue);
    });

    testWidgets('rating row reports tapped star', (tester) async {
      int? rated;
      await tester.pumpWidget(_wrap(FormRow.rating(
        label: 'Rating',
        value: 2,
        onChanged: (v) => rated = v,
      )));
      expect(find.byIcon(Icons.star), findsNWidgets(2));
      expect(find.byIcon(Icons.star_border), findsNWidgets(3));
      await tester.tap(find.byIcon(Icons.star_border).last);
      expect(rated, 5);
    });

    testWidgets('custom row hosts arbitrary child', (tester) async {
      await tester.pumpWidget(_wrap(FormRow.custom(
        label: 'Mode',
        child: const Text('SEGMENTED'),
      )));
      expect(find.text('Mode'), findsOneWidget);
      expect(find.text('SEGMENTED'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 4.2: Run tests to verify they fail**

```bash
flutter test test/shared/widgets/forms/form_row_test.dart
```

Expected: FAIL — `form_row.dart` does not exist.

- [ ] **Step 4.3: Implement FormRow**

Create `lib/shared/widgets/forms/form_row.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/forms/form_style.dart';

enum _RowKind { text, picker, display, toggle, rating, custom }

/// Label-left / value-right row used inside [FormSection] groups.
///
/// Variants:
/// - [FormRow.text]: tap expands inline into a real TextFormField
///   (styled by the app InputDecorationTheme); commits on done/unfocus.
/// - [FormRow.picker]: formatted value + chevron, opens a picker sheet.
/// - [FormRow.display]: muted, non-tappable (auto-computed values).
/// - [FormRow.toggle], [FormRow.rating], [FormRow.custom].
class FormRow extends StatefulWidget {
  const FormRow.text({
    super.key,
    required this.label,
    required this.controller,
    this.placeholder,
    this.suffixText,
    this.keyboardType,
    this.maxLines = 1,
    this.alwaysEditing = false,
    this.validator,
    this.onChanged,
  })  : kind = _RowKind.text,
        value = null,
        onTap = null,
        boolValue = null,
        onBoolChanged = null,
        intValue = null,
        onIntChanged = null,
        child = null;

  const FormRow.picker({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder,
  })  : kind = _RowKind.picker,
        controller = null,
        suffixText = null,
        keyboardType = null,
        maxLines = 1,
        alwaysEditing = false,
        validator = null,
        onChanged = null,
        boolValue = null,
        onBoolChanged = null,
        intValue = null,
        onIntChanged = null,
        child = null;

  const FormRow.display({
    super.key,
    required this.label,
    required this.value,
  })  : kind = _RowKind.display,
        controller = null,
        placeholder = null,
        suffixText = null,
        keyboardType = null,
        maxLines = 1,
        alwaysEditing = false,
        validator = null,
        onChanged = null,
        onTap = null,
        boolValue = null,
        onBoolChanged = null,
        intValue = null,
        onIntChanged = null,
        child = null;

  const FormRow.toggle({
    super.key,
    required this.label,
    required bool value,
    required ValueChanged<bool> onChanged,
  })  : kind = _RowKind.toggle,
        boolValue = value,
        onBoolChanged = onChanged,
        controller = null,
        value = null,
        placeholder = null,
        suffixText = null,
        keyboardType = null,
        maxLines = 1,
        alwaysEditing = false,
        validator = null,
        this.onChanged = null,
        onTap = null,
        intValue = null,
        onIntChanged = null,
        child = null;

  const FormRow.rating({
    super.key,
    required this.label,
    required int value,
    required ValueChanged<int> onChanged,
  })  : kind = _RowKind.rating,
        intValue = value,
        onIntChanged = onChanged,
        controller = null,
        value = null,
        placeholder = null,
        suffixText = null,
        keyboardType = null,
        maxLines = 1,
        alwaysEditing = false,
        validator = null,
        this.onChanged = null,
        onTap = null,
        boolValue = null,
        onBoolChanged = null,
        child = null;

  const FormRow.custom({
    super.key,
    required this.label,
    required this.child,
  })  : kind = _RowKind.custom,
        controller = null,
        value = null,
        placeholder = null,
        suffixText = null,
        keyboardType = null,
        maxLines = 1,
        alwaysEditing = false,
        validator = null,
        onChanged = null,
        onTap = null,
        boolValue = null,
        onBoolChanged = null,
        intValue = null,
        onIntChanged = null;

  final _RowKind kind;
  final String label;
  final TextEditingController? controller;
  final String? value;
  final String? placeholder;
  final String? suffixText;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool alwaysEditing;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool? boolValue;
  final ValueChanged<bool>? onBoolChanged;
  final int? intValue;
  final ValueChanged<int>? onIntChanged;
  final Widget? child;

  @override
  State<FormRow> createState() => _FormRowState();
}

class _FormRowState extends State<FormRow> {
  bool _editing = false;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) {
        setState(() => _editing = false);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  TextStyle _labelTextStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!;

  TextStyle _valueTextStyle(BuildContext context, {required bool muted}) {
    final theme = Theme.of(context);
    return theme.textTheme.bodyMedium!.copyWith(
      color: muted
          ? theme.colorScheme.onSurfaceVariant
          : theme.colorScheme.onSurface,
    );
  }

  Widget _shell(BuildContext context,
      {required Widget trailing, VoidCallback? onTap}) {
    final row = Padding(
      padding: FormStyle.rowPadding,
      child: Row(
        children: [
          Text(widget.label, style: _labelTextStyle(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (widget.kind) {
      case _RowKind.text:
        if (widget.alwaysEditing || _editing) {
          return Padding(
            padding: FormStyle.rowPadding,
            child: TextFormField(
              controller: widget.controller,
              focusNode: widget.alwaysEditing ? null : _focusNode,
              autofocus: !widget.alwaysEditing,
              maxLines: widget.maxLines,
              keyboardType: widget.keyboardType,
              validator: widget.validator,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                labelText: widget.label,
                suffixText: widget.suffixText,
              ),
              onFieldSubmitted: widget.alwaysEditing
                  ? null
                  : (_) => setState(() => _editing = false),
            ),
          );
        }
        return AnimatedBuilder(
          animation: widget.controller!,
          builder: (context, _) {
            final text = widget.controller!.text;
            final empty = text.isEmpty;
            final shown = empty
                ? (widget.placeholder ?? '')
                : (widget.suffixText == null
                    ? text
                    : '$text ${widget.suffixText}');
            return _shell(
              context,
              onTap: () => setState(() => _editing = true),
              trailing: Text(
                shown,
                style: _valueTextStyle(context, muted: empty),
                maxLines: widget.maxLines > 1 ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            );
          },
        );

      case _RowKind.picker:
        final empty = widget.value == null || widget.value!.isEmpty;
        return _shell(
          context,
          onTap: widget.onTap,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  empty ? (widget.placeholder ?? '') : widget.value!,
                  style: _valueTextStyle(context, muted: empty),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        );

      case _RowKind.display:
        return _shell(
          context,
          trailing: Text(
            widget.value ?? '',
            style: _valueTextStyle(context, muted: true),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );

      case _RowKind.toggle:
        return _shell(
          context,
          trailing: Switch(
            value: widget.boolValue!,
            onChanged: widget.onBoolChanged,
          ),
        );

      case _RowKind.rating:
        return _shell(
          context,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
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
          ),
        );

      case _RowKind.custom:
        return _shell(context, trailing: widget.child!);
    }
  }
}
```

- [ ] **Step 4.4: Run tests to verify they pass**

```bash
flutter test test/shared/widgets/forms/form_row_test.dart
```

Expected: all 9 tests PASS.

- [ ] **Step 4.5: Format, analyze, commit**

```bash
dart format lib/ test/
flutter analyze
git add lib/shared/widgets/forms/ test/shared/widgets/forms/
git commit -m "feat(forms): add FormRow label/value variants with inline text editing"
```

---

### Task 5: UnitField

**Files:**
- Create: `lib/shared/widgets/forms/unit_field.dart`
- Test: `test/shared/widgets/forms/unit_field_test.dart`

- [ ] **Step 5.1: Write the failing tests**

Create `test/shared/widgets/forms/unit_field_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/forms/unit_field.dart';

void main() {
  testWidgets('renders label, unit suffix, accepts numeric text',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UnitField(
          controller: controller,
          label: 'Start pressure',
          unitSymbol: 'bar',
        ),
      ),
    ));
    expect(find.text('Start pressure'), findsOneWidget);
    expect(find.text('bar'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '200');
    expect(controller.text, '200');
  });

  testWidgets('runs validator inside a Form', (tester) async {
    final controller = TextEditingController(text: '');
    addTearDown(controller.dispose);
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Form(
          key: formKey,
          child: UnitField(
            controller: controller,
            label: 'Volume',
            unitSymbol: 'L',
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
        ),
      ),
    ));
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsOneWidget);
  });
}
```

- [ ] **Step 5.2: Run tests to verify they fail**

```bash
flutter test test/shared/widgets/forms/unit_field_test.dart
```

Expected: FAIL — `unit_field.dart` does not exist.

- [ ] **Step 5.3: Implement UnitField**

Create `lib/shared/widgets/forms/unit_field.dart`:

```dart
import 'package:flutter/material.dart';

/// Boxed numeric input with a unit suffix, for dense clusters inside
/// expanded editors (tank pressures, weights). Unit symbols always come
/// from UnitFormatter at the call site - never hard-code them.
class UnitField extends StatelessWidget {
  const UnitField({
    super.key,
    required this.controller,
    required this.label,
    required this.unitSymbol,
    this.validator,
    this.onChanged,
    this.allowDecimal = true,
    this.helperText,
  });

  final TextEditingController controller;
  final String label;
  final String unitSymbol;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool allowDecimal;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        suffixText: unitSymbol,
        helperText: helperText,
        isDense: true,
      ),
    );
  }
}
```

- [ ] **Step 5.4: Run tests, format, analyze, commit**

```bash
flutter test test/shared/widgets/forms/unit_field_test.dart
dart format lib/ test/
flutter analyze
git add lib/shared/widgets/forms/ test/shared/widgets/forms/
git commit -m "feat(forms): add UnitField numeric input with unit suffix"
```

Expected: both tests PASS, analyze clean.

---

### Task 6: AddSectionRow

**Files:**
- Create: `lib/shared/widgets/forms/add_section_row.dart`
- Test: `test/shared/widgets/forms/add_section_row_test.dart`
- Modify: `lib/l10n/arb/app_en.arb` + 10 locale arbs (1 new key)

- [ ] **Step 6.1: Add the l10n key (all 11 arbs)**

`app_en.arb`:

```json
"forms_addSection_prefix": "Add:",
"@forms_addSection_prefix": {
  "description": "Prefix of the trailing row listing unused optional form sections, e.g. '+ Add: Course / Custom fields'"
},
```

Translate into the 10 locale arbs, then `flutter gen-l10n`.

- [ ] **Step 6.2: Write the failing tests**

Create `test/shared/widgets/forms/add_section_row_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/add_section_row.dart';

void main() {
  testWidgets('renders entries and fires their callbacks', (tester) async {
    String? tapped;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AddSectionRow(entries: [
          AddSectionEntry(label: 'Course', onTap: () => tapped = 'course'),
          AddSectionEntry(
              label: 'Custom fields', onTap: () => tapped = 'custom'),
        ]),
      ),
    ));
    expect(find.textContaining('Add:'), findsOneWidget);
    await tester.tap(find.text('Course'));
    expect(tapped, 'course');
    await tester.tap(find.text('Custom fields'));
    expect(tapped, 'custom');
  });

  testWidgets('renders nothing when all entries used', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: AddSectionRow(entries: [])),
    ));
    expect(find.textContaining('Add:'), findsNothing);
  });
}
```

- [ ] **Step 6.3: Run tests to verify they fail**

```bash
flutter test test/shared/widgets/forms/add_section_row_test.dart
```

Expected: FAIL — `add_section_row.dart` does not exist.

- [ ] **Step 6.4: Implement AddSectionRow**

Create `lib/shared/widgets/forms/add_section_row.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

class AddSectionEntry {
  const AddSectionEntry({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;
}

/// Trailing muted row listing rare sections not yet in use:
/// "+ Add: Course / Custom fields". Tapping a label expands that section.
class AddSectionRow extends StatelessWidget {
  const AddSectionRow({super.key, required this.entries});

  final List<AddSectionEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium!
        .copyWith(color: theme.colorScheme.onSurfaceVariant);
    final link = theme.textTheme.bodyMedium!.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    final children = <Widget>[
      Text('+ ${context.l10n.forms_addSection_prefix} ', style: muted),
    ];
    for (var i = 0; i < entries.length; i++) {
      children.add(InkWell(
        onTap: entries[i].onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Text(entries[i].label, style: link),
        ),
      ));
      if (i < entries.length - 1) {
        children.add(Text(' - ', style: muted));
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}
```

- [ ] **Step 6.5: Run tests, format, analyze, commit**

```bash
flutter test test/shared/widgets/forms/add_section_row_test.dart
dart format lib/ test/
flutter analyze
git add lib/shared/widgets/forms/ test/shared/widgets/forms/ lib/l10n/
git commit -m "feat(forms): add AddSectionRow for rare form sections"
```

Expected: both tests PASS, analyze clean.

---

### Task 7: EditFormScaffold

**Files:**
- Create: `lib/shared/widgets/forms/edit_form_scaffold.dart`
- Test: `test/shared/widgets/forms/edit_form_scaffold_test.dart`
- Modify: `lib/l10n/arb/app_en.arb` + 10 locale arbs (6 new keys)

- [ ] **Step 7.1: Add the l10n keys (all 11 arbs)**

`app_en.arb`:

```json
"forms_save": "Save",
"@forms_save": {"description": "Save action on shared edit form scaffold"},
"forms_cancel": "Cancel",
"@forms_cancel": {"description": "Cancel action on shared edit form scaffold"},
"forms_discard_title": "Discard changes?",
"@forms_discard_title": {"description": "Title of the unsaved-changes dialog"},
"forms_discard_body": "You have unsaved changes. If you leave now they will be lost.",
"@forms_discard_body": {"description": "Body of the unsaved-changes dialog"},
"forms_discard_keepEditing": "Keep editing",
"@forms_discard_keepEditing": {"description": "Stay on the form"},
"forms_discard_discard": "Discard",
"@forms_discard_discard": {"description": "Leave the form, losing changes"},
```

Translate into the 10 locale arbs, then `flutter gen-l10n`.

- [ ] **Step 7.2: Write the failing tests**

Create `test/shared/widgets/forms/edit_form_scaffold_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/edit_form_scaffold.dart';

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  testWidgets('full-page mode: AppBar title and save action', (tester) async {
    var saved = 0;
    await tester.pumpWidget(_app(EditFormScaffold(
      title: 'Edit Dive',
      embedded: false,
      isSaving: false,
      hasUnsavedChanges: false,
      onSave: () => saved++,
      child: const Text('BODY'),
    )));
    expect(find.text('Edit Dive'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    await tester.tap(find.text('Save'));
    expect(saved, 1);
  });

  testWidgets('embedded mode: compact header with cancel + save',
      (tester) async {
    var cancelled = 0;
    await tester.pumpWidget(_app(Scaffold(
      body: EditFormScaffold(
        title: 'New Dive',
        embedded: true,
        isSaving: false,
        hasUnsavedChanges: false,
        onSave: () {},
        onCancel: () => cancelled++,
        child: const Text('BODY'),
      ),
    )));
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('New Dive'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    expect(cancelled, 1);
  });

  testWidgets('saving state shows spinner instead of save button',
      (tester) async {
    await tester.pumpWidget(_app(EditFormScaffold(
      title: 'Edit Dive',
      embedded: false,
      isSaving: true,
      hasUnsavedChanges: false,
      onSave: () {},
      child: const Text('BODY'),
    )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('back with unsaved changes shows discard dialog; discard pops',
      (tester) async {
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => EditFormScaffold(
                title: 'Edit Dive',
                embedded: false,
                isSaving: false,
                hasUnsavedChanges: true,
                onSave: () {},
                child: const Text('BODY'),
              ),
            )),
            child: const Text('open'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // System back attempt.
    final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
    await widgetsAppState.didPopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('BODY'), findsOneWidget);

    await widgetsAppState.didPopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('BODY'), findsNothing);
  });

  testWidgets('content is width-constrained', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(EditFormScaffold(
      title: 'Edit Dive',
      embedded: false,
      isSaving: false,
      hasUnsavedChanges: false,
      onSave: () {},
      child: const SizedBox(height: 10, width: double.infinity),
    )));
    final constrained = tester.widget<ConstrainedBox>(
      find.byKey(const Key('editFormMaxWidth')),
    );
    expect(constrained.constraints.maxWidth, 640);
  });
}
```

- [ ] **Step 7.3: Run tests to verify they fail**

```bash
flutter test test/shared/widgets/forms/edit_form_scaffold_test.dart
```

Expected: FAIL — `edit_form_scaffold.dart` does not exist.

- [ ] **Step 7.4: Implement EditFormScaffold**

Create `lib/shared/widgets/forms/edit_form_scaffold.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_style.dart';

/// Shared shell for every edit form.
///
/// Full-page mode: Scaffold + AppBar with a Save action.
/// Embedded mode (master-detail): compact header with icon, title,
/// Cancel and Save - replaces the per-page hand-rolled headers.
/// Both modes: PopScope unsaved-changes guard and max-width centering.
class EditFormScaffold extends StatelessWidget {
  const EditFormScaffold({
    super.key,
    required this.title,
    required this.embedded,
    required this.isSaving,
    required this.hasUnsavedChanges,
    required this.onSave,
    required this.child,
    this.onCancel,
    this.headerIcon,
  });

  final String title;
  final bool embedded;
  final bool isSaving;
  final bool hasUnsavedChanges;
  final VoidCallback onSave;
  final VoidCallback? onCancel;
  final Widget child;
  final IconData? headerIcon;

  Future<void> _handlePop(BuildContext context, bool didPop) async {
    if (didPop) return;
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.forms_discard_title),
        content: Text(l10n.forms_discard_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.forms_discard_keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.forms_discard_discard),
          ),
        ],
      ),
    );
    if (discard == true) navigator.pop();
  }

  Widget _saveButton(BuildContext context, {required bool filled}) {
    if (isSaving) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final label = Text(context.l10n.forms_save);
    return filled
        ? FilledButton(onPressed: onSave, child: label)
        : TextButton(onPressed: onSave, child: label);
  }

  Widget _constrained(Widget body) => Center(
        child: ConstrainedBox(
          key: const Key('editFormMaxWidth'),
          constraints:
              const BoxConstraints(maxWidth: FormStyle.maxContentWidth),
          child: body,
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (embedded) {
      final colorScheme = Theme.of(context).colorScheme;
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom:
                    BorderSide(color: colorScheme.outlineVariant, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(headerIcon ?? Icons.edit, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (onCancel != null)
                  TextButton(
                    onPressed: onCancel,
                    child: Text(context.l10n.forms_cancel),
                  ),
                const SizedBox(width: 8),
                _saveButton(context, filled: true),
              ],
            ),
          ),
          Expanded(child: _constrained(child)),
        ],
      );
    }

    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) => _handlePop(context, didPop),
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [_saveButton(context, filled: false)],
        ),
        body: _constrained(child),
      ),
    );
  }
}
```

Note: embedded mode has no PopScope (it is not a route of its own — cancel goes through `onCancel`, matching today's behavior at dive_edit_page.dart:630-680).

- [ ] **Step 7.5: Run tests to verify they pass**

```bash
flutter test test/shared/widgets/forms/edit_form_scaffold_test.dart
```

Expected: all 5 tests PASS.

- [ ] **Step 7.6: Format, analyze, commit**

```bash
dart format lib/ test/
flutter analyze
git add lib/shared/widgets/forms/ test/shared/widgets/forms/ lib/l10n/
git commit -m "feat(forms): add EditFormScaffold with discard guard and embedded header"
```

---

### Task 8: Extract picker sheets from dive_edit_page.dart

Pure mechanical relocation — zero behavior change. The six private classes at the bottom of `dive_edit_page.dart` become public widgets in their own files. This removes ~1,100 lines from the page before any redesign work touches it.

**Files:**
- Create: the six files under `lib/features/dive_log/presentation/widgets/pickers/` (see File Structure)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`

**Move map (current line ranges in dive_edit_page.dart):**

| Class (rename `_X` → `X`) | Lines | New file | Call sites to update |
|---|---|---|---|
| `_SitePickerSheet` + `_SiteWithDistance` (keep `_SiteWithDistance` private in new file) | 3793-4080 | `pickers/site_picker_sheet.dart` | `_showSitePicker` (1140-1175) |
| `_SpeciesPickerSheet` | 4083-4386 | `pickers/species_picker_sheet.dart` | `_showSpeciesPicker` (3277-3308) |
| `_EditSightingSheet` | 4388-4541 | `pickers/edit_sighting_sheet.dart` | `_editSighting` (3309-3331) |
| `_EquipmentPickerSheet` | 4544-4694 | `pickers/equipment_picker_sheet.dart` | `_showEquipmentPicker` (2194-2218) |
| `_EquipmentSetPickerSheet` + `_EquipmentSetTile` (tile stays private) | 4696-4852 | `pickers/equipment_set_picker_sheet.dart` | `_showEquipmentSetPicker` (2220-2245) |
| `_ComputerSourceSelectionSheet` | 4857-4909 | `pickers/computer_source_sheet.dart` | `_openProfileEditor` (1562-1601) |

- [ ] **Step 8.1: Move the classes**

For each row of the move map, in order:
1. Create the new file. First line is the class code cut verbatim from the page, with the leading underscore removed from the public class name (e.g. `class SitePickerSheet extends ConsumerStatefulWidget` and its `State` class renamed `_SitePickerSheetState` → keep private state classes private).
2. Add the imports the moved code needs — start by copying the full import block from `dive_edit_page.dart`, then delete the ones `flutter analyze` flags as unused in the new file.
3. In `dive_edit_page.dart`: delete the moved class, add `import 'package:submersion/features/dive_log/presentation/widgets/pickers/<file>.dart';`, and update the constructor references at the listed call sites (`_SitePickerSheet(` → `SitePickerSheet(`, etc.).

- [ ] **Step 8.2: Verify zero behavior change**

```bash
flutter analyze
flutter test test/features/dive_log/presentation/pages/dive_edit_page_test.dart
wc -l lib/features/dive_log/presentation/pages/dive_edit_page.dart
```

Expected: analyze clean, all 4 tests pass, page now ~3,800 lines.

- [ ] **Step 8.3: Format and commit**

```bash
dart format lib/ test/
git add lib/features/dive_log/
git commit -m "refactor(dive-log): extract picker sheets from dive edit page"
```

---

### Task 9: TheDiveSection + first page integration

The first redesigned group replaces six old sections (`_buildDiveNumberField`, `_buildDateTimeSection`, `_buildSurfaceIntervalDisplay`, `_buildSiteSection`, `_buildDepthDurationSection`, `_buildProfileSection`) in the page's ListView. The page keeps a mixed old/new look until Task 14 — every commit still builds and runs.

**Complex legacy interiors move in as slot widgets** (this pattern repeats in later tasks): the section provides the new chrome (label, tonal group, hero, rows); page-owned blocks that are already rich (profile buttons + outlier suggestions, GPS photo banner, surface-interval provider logic) are passed in as prebuilt `Widget` slots with their `Card` wrapper and `Text(...sectionTitle)` header stripped.

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- Modify: `lib/l10n/arb/app_en.arb` + 10 locale arbs
- Test: extend `test/features/dive_log/presentation/pages/dive_edit_page_test.dart`

- [ ] **Step 9.1: Add l10n keys (all 11 arbs)**

`app_en.arb` (the `diveLog_edit_label_*` keys for max depth, avg depth, bottom time, runtime, dive number already exist — reuse them):

```json
"diveLog_edit_group_theDive": "The Dive",
"@diveLog_edit_group_theDive": {"description": "Form group: core dive facts"},
"diveLog_edit_row_entry": "Entry",
"@diveLog_edit_row_entry": {"description": "Row label: entry date and time"},
"diveLog_edit_row_exit": "Exit",
"@diveLog_edit_row_exit": {"description": "Row label: exit date and time"},
"diveLog_edit_row_site": "Site",
"@diveLog_edit_row_site": {"description": "Row label: dive site picker"},
"diveLog_edit_row_addSite": "Add site",
"@diveLog_edit_row_addSite": {"description": "Placeholder when no site selected"},
"diveLog_edit_row_notSet": "Not set",
"@diveLog_edit_row_notSet": {"description": "Placeholder for unset picker rows"},
```

Translate into the 10 locale arbs, then `flutter gen-l10n`.

- [ ] **Step 9.2: Implement TheDiveSection**

Create `lib/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';
import 'package:submersion/shared/widgets/forms/stat_strip.dart';

/// A profile-derived value offered on a hero stat cell.
class ProfileSuggestion {
  const ProfileSuggestion({required this.value, required this.onUse});

  /// Already formatted in the diver's units (e.g. "28.6").
  final String value;
  final VoidCallback onUse;
}

/// Group 1 of the dive form: always expanded, owns the core facts.
/// Hero: max depth / bottom time / avg depth. Rows: dive number, entry,
/// exit (+ surface interval), site, profile.
class TheDiveSection extends StatelessWidget {
  const TheDiveSection({
    super.key,
    required this.depthSymbol,
    required this.maxDepthController,
    required this.avgDepthController,
    required this.bottomTimeController,
    required this.runtimeController,
    required this.diveNumberController,
    required this.entryText,
    required this.onEditEntry,
    required this.exitText,
    required this.onEditExit,
    required this.siteName,
    required this.onPickSite,
    this.maxDepthSuggestion,
    this.avgDepthSuggestion,
    this.bottomTimeSuggestion,
    this.runtimeSuggestion,
    this.surfaceIntervalText,
    this.siteBanner,
    this.profileChild,
  });

  final String depthSymbol;
  final TextEditingController maxDepthController;
  final TextEditingController avgDepthController;
  final TextEditingController bottomTimeController;
  final TextEditingController runtimeController;
  final TextEditingController diveNumberController;
  final String entryText;
  final VoidCallback onEditEntry;
  final String? exitText;
  final VoidCallback onEditExit;
  final String? siteName;
  final VoidCallback onPickSite;
  final ProfileSuggestion? maxDepthSuggestion;
  final ProfileSuggestion? avgDepthSuggestion;
  final ProfileSuggestion? bottomTimeSuggestion;
  final ProfileSuggestion? runtimeSuggestion;
  final String? surfaceIntervalText;

  /// Existing photo-GPS suggestion banner from the old site section, if any.
  final Widget? siteBanner;

  /// Existing profile block (edit/draw buttons, outlier suggestions),
  /// stripped of its Card wrapper.
  final Widget? profileChild;

  StatCell _cell(
    BuildContext context,
    String label,
    String? unit,
    TextEditingController controller,
    ProfileSuggestion? suggestion,
  ) {
    return StatCell(
      label: label,
      unit: unit,
      controller: controller,
      profileValue: suggestion?.value,
      onUseProfileValue:
          suggestion == null ? null : (_) => suggestion.onUse(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveLog_edit_group_theDive,
      expanded: true,
      onToggle: null,
      hero: StatStrip(cells: [
        _cell(context, l10n.diveLog_edit_label_maxDepth, depthSymbol,
            maxDepthController, maxDepthSuggestion),
        _cell(context, l10n.diveLog_edit_label_bottomTime, 'min',
            bottomTimeController, bottomTimeSuggestion),
        _cell(context, l10n.diveLog_edit_label_avgDepth, depthSymbol,
            avgDepthController, avgDepthSuggestion),
      ]),
      children: [
        FormRow.text(
          label: l10n.diveLog_edit_label_diveNumber,
          controller: diveNumberController,
          keyboardType: TextInputType.number,
          placeholder: l10n.diveLog_edit_row_notSet,
        ),
        FormRow.picker(
          label: l10n.diveLog_edit_row_entry,
          value: entryText,
          onTap: onEditEntry,
        ),
        FormRow.picker(
          label: l10n.diveLog_edit_row_exit,
          value: exitText,
          placeholder: l10n.diveLog_edit_row_notSet,
          onTap: onEditExit,
        ),
        if (surfaceIntervalText != null)
          FormRow.display(
            label: l10n.diveLog_edit_surfaceInterval_label,
            value: surfaceIntervalText,
          ),
        FormRow.text(
          label: l10n.diveLog_edit_label_runtime,
          controller: runtimeController,
          suffixText: 'min',
          keyboardType: TextInputType.number,
          placeholder: l10n.diveLog_edit_row_notSet,
        ),
        FormRow.picker(
          label: l10n.diveLog_edit_row_site,
          value: siteName,
          placeholder: l10n.diveLog_edit_row_addSite,
          onTap: onPickSite,
        ),
        if (siteBanner != null) siteBanner!,
        if (profileChild != null) profileChild!,
      ],
    );
  }
}
```

Note: `diveLog_edit_surfaceInterval_label` — check `app_en.arb` for the exact existing surface-interval label key (the page uses `diveLog_edit_surfaceInterval_*` keys at lines 935-983); reuse the existing label key rather than the literal above if its name differs.

- [ ] **Step 9.3: Integrate into the page**

In `dive_edit_page.dart`:

1. Add imports for `the_dive_section.dart`.
2. Add page helpers (near the `_calculate*` methods, reusing their computation — extract the pure computation out of `_calculateMaxDepthFromProfile` etc. so both paths share it):

```dart
String _formatEntryText(UnitFormatter units) {
  final time = _entryTime.format(context);
  return '${units.formatDate(_entryDate)}, $time';
}

String? _formatExitText(UnitFormatter units) {
  if (_exitDate == null || _exitTime == null) return null;
  return '${units.formatDate(_exitDate!)}, ${_exitTime!.format(context)}';
}

Future<void> _editEntry() async {
  await _selectEntryDate();
  if (!mounted) return;
  await _selectEntryTime();
}

Future<void> _editExit() async {
  await _selectExitDate();
  if (!mounted) return;
  await _selectExitTime();
}
```

3. Build `ProfileSuggestion`s only when `_existingDive?.profile.isNotEmpty == true`, wiring `onUse` to the existing `_calculateMaxDepthFromProfile(units)` / `_calculateAvgDepthFromProfile(units)` / `_calculateBottomTimeFromProfile()` / `_calculateRuntimeFromProfile()` methods, and `value` to the shared extracted computation formatted with `units`.
4. In the `build` ListView children (currently lines 549-587), replace the six entries
   `_buildDiveNumberField()`, `_buildDateTimeSection()`, `_buildSiteSection()`, `_buildDepthDurationSection(units)`, `_buildProfileSection()` (and the `SizedBox` separators between them) with:

```dart
TheDiveSection(
  depthSymbol: units.depthSymbol,
  maxDepthController: _maxDepthController,
  avgDepthController: _avgDepthController,
  bottomTimeController: _durationController,
  runtimeController: _runtimeController,
  diveNumberController: _diveNumberController,
  entryText: _formatEntryText(units),
  onEditEntry: _editEntry,
  exitText: _formatExitText(units),
  onEditExit: _editExit,
  siteName: _selectedSite?.name,
  onPickSite: _showSitePicker,
  maxDepthSuggestion: /* per step 3 */,
  avgDepthSuggestion: /* per step 3 */,
  bottomTimeSuggestion: /* per step 3 */,
  runtimeSuggestion: /* per step 3 */,
  surfaceIntervalText: /* string produced by existing surface-interval logic; null for new dives */,
  siteBanner: /* photo GPS banner extracted from _buildSiteSection if the suggestion state is active, else null */,
  profileChild: /* existing _buildProfileSection content minus Card+title, only when editing */,
),
const SizedBox(height: FormStyle.sectionGap),
```

   The surface-interval slot: today `_buildSurfaceIntervalDisplay()` (935-983) renders provider-derived text. Convert it to return the plain text string (`String? _surfaceIntervalText()`) and delete its widget chrome; pass the string.
5. Delete the now-unused methods: `_buildDiveNumberField`, `_buildDateTimeSection`, `_buildSurfaceIntervalDisplay` (replaced by text helper), `_buildSiteSection` (its photo-GPS banner sub-widget survives as `siteBanner`), `_buildDepthDurationSection`, `_buildProfileSection` (its interior survives as `profileChild` builder method `_profileChild()`).

- [ ] **Step 9.4: Update and extend the page test**

The 4 existing bottomTime tests assert against `TextFormField` text. Bottom time now rests in a `StatCell` (a `Text`, not a `TextFormField`). Update assertions to `find.text('45')` style (cell text) instead of reading `TextFormField` controllers, and add:

```dart
testWidgets('The Dive hero shows max depth, bottom time, avg depth',
    (tester) async {
  // build harness exactly as the existing tests do, with a dive that has
  // maxDepth: 28.4, bottomTime: 52 min, avgDepth: 14.2
  // ...
  expect(find.text('MAX DEPTH'), findsOneWidget);
  expect(find.text('BOTTOM TIME'), findsOneWidget);
  expect(find.text('AVG DEPTH'), findsOneWidget);
  expect(find.text('28.4'), findsOneWidget);
  expect(find.text('52'), findsOneWidget);
});
```

- [ ] **Step 9.5: Verify, format, analyze, commit**

```bash
flutter test test/features/dive_log/presentation/pages/dive_edit_page_test.dart
dart format lib/ test/
flutter analyze
git add lib/features/dive_log/ test/features/dive_log/ lib/l10n/
git commit -m "feat(dive-log): rebuild The Dive group on shared form primitives"
```

Expected: page tests pass; mixed old/new page renders (verify by running `flutter run -d macos`, open any dive, confirm The Dive group looks like the mockup and saving still works).

---

### Task 10: TankCard

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/edit_sections/tank_card.dart`
- Test: `test/shared/widgets/forms/tank_card_test.dart` is NOT the right home — create `test/features/dive_log/presentation/widgets/tank_card_test.dart`
- Modify: `lib/l10n/arb/app_en.arb` + 10 locale arbs

- [ ] **Step 10.1: Add l10n keys (all 11 arbs)**

```json
"diveLog_edit_tankCard_pressure": "Pressure",
"@diveLog_edit_tankCard_pressure": {"description": "Hero label on tank card: start to end pressure"},
"diveLog_edit_tankCard_mix": "Mix",
"@diveLog_edit_tankCard_mix": {"description": "Hero label on tank card: gas mix"},
"diveLog_edit_tankCard_volume": "Volume",
"@diveLog_edit_tankCard_volume": {"description": "Hero label on tank card: tank volume"},
"diveLog_edit_tankCard_title": "Tank {number}",
"@diveLog_edit_tankCard_title": {"description": "Caption on a tank card", "placeholders": {"number": {"type": "int"}}},
"diveLog_edit_tankCard_edit": "Edit",
"@diveLog_edit_tankCard_edit": {"description": "Expand a tank card into the full editor"},
"diveLog_edit_tankCard_done": "Done",
"@diveLog_edit_tankCard_done": {"description": "Collapse the tank editor back to the card"},
```

Translate into the 10 locale arbs, then `flutter gen-l10n`.

- [ ] **Step 10.2: Write the failing tests**

Create `test/features/dive_log/presentation/widgets/tank_card_test.dart`. Use the existing dive test harness pattern for entities; a `DiveTank` with `startPressure: 200`, `endPressure: 50`, `volume: 11.1`, gas `EAN32` (construct via the same constructors the page uses — see `_tanks` initialization in dive_edit_page.dart initState):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/tank_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// Construct settings/UnitFormatter the same way mock_providers.dart does.

void main() {
  testWidgets('collapsed card shows pressure, mix, volume and caption',
      (tester) async {
    // pump TankCard(tank: testTank, tankNumber: 1, units: metricUnits,
    //   onChanged: (_) {}, onRemove: null, canRemove: false)
    // wrapped in MaterialApp with AppLocalizations delegates.
    expect(find.textContaining('200'), findsOneWidget);
    expect(find.text('EAN32'), findsOneWidget);
    expect(find.text('Tank 1'), findsOneWidget);
    expect(find.byType(TankEditor), findsNothing);
  });

  testWidgets('Edit expands inline TankEditor; Done collapses',
      (tester) async {
    // same pump
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.byType(TankEditor), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(TankEditor), findsNothing);
  });
}
```

(Fill the pump helpers from the existing harness; the assertions above are the contract.)

- [ ] **Step 10.3: Run tests to verify they fail, then implement**

```bash
flutter test test/features/dive_log/presentation/widgets/tank_card_test.dart
```

Create `lib/features/dive_log/presentation/widgets/edit_sections/tank_card.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_style.dart';
import 'package:submersion/shared/widgets/forms/stat_strip.dart';

/// One tank inside the Gas & Gear group. Rests as a stat card
/// (pressure start->end, mix, volume); "Edit" expands the full
/// TankEditor inline; "Done" collapses back. No sheets, no navigation.
class TankCard extends StatefulWidget {
  const TankCard({
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
  State<TankCard> createState() => _TankCardState();
}

class _TankCardState extends State<TankCard> {
  late bool _expanded = widget.initiallyExpanded;

  String _pressureText() {
    final units = widget.units;
    final start = widget.tank.startPressure;
    final end = widget.tank.endPressure;
    String fmt(double? bar) =>
        bar == null ? '--' : units.convertPressure(bar).round().toString();
    return '${fmt(start)}→${fmt(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (_expanded) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.primary, width: 1),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: FormStyle.dividerColor(context)),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          StatStrip(cells: [
            StatCell(
              label: l10n.diveLog_edit_tankCard_pressure,
              unit: widget.units.pressureSymbol,
              displayValue: _pressureText(),
            ),
            StatCell(
              label: l10n.diveLog_edit_tankCard_mix,
              displayValue: widget.tank.gasMix.displayName,
            ),
            StatCell(
              label: l10n.diveLog_edit_tankCard_volume,
              displayValue: widget.units
                  .formatTankVolume(widget.tank.volume, null, null),
            ),
          ]),
          Container(
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                Text(
                  l10n.diveLog_edit_tankCard_title(widget.tankNumber),
                  style: theme.textTheme.labelSmall!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => setState(() => _expanded = true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    child: Text(
                      l10n.diveLog_edit_tankCard_edit,
                      style: theme.textTheme.labelSmall!.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

Adjust the three `displayValue` expressions to the actual `DiveTank` field/extension names (`gasMix.displayName`, `volume`, `startPressure`, `endPressure`) — verify against the entity used by `TankEditor` and fix names if they differ; the contract is: pressure cell "200→50 bar", mix cell "EAN32", volume cell via `formatTankVolume`. A brand-new tank with no pressures shows "--→--".

- [ ] **Step 10.4: Run tests, format, analyze, commit**

```bash
flutter test test/features/dive_log/presentation/widgets/tank_card_test.dart
dart format lib/ test/
flutter analyze
git add lib/features/dive_log/ test/features/dive_log/ lib/l10n/
git commit -m "feat(dive-log): add TankCard with inline expanding tank editor"
```

---

### Task 11: GasGearSection + page integration

Replaces `_buildDiveModeSection` (1689-1793), `_buildTankSection` (1795-1839), `_buildEquipmentSection` (2032-2151), `_buildWeightSection` (2951-3004) with one collapsible group. The CCR/SCR panels and the equipment/weight interiors move in as slots, unchanged.

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/edit_sections/gas_gear_section.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- Modify: `lib/l10n/arb/app_en.arb` + 10 locale arbs

- [ ] **Step 11.1: Add l10n keys (all 11 arbs)**

```json
"diveLog_edit_group_gasGear": "Gas & Gear",
"@diveLog_edit_group_gasGear": {"description": "Form group: mode, tanks, equipment, weight"},
"diveLog_edit_invite_gasGear": "Add gas & gear - mode, tanks, equipment, weight",
"@diveLog_edit_invite_gasGear": {"description": "Empty-state invitation for the Gas & Gear group"},
"diveLog_edit_row_mode": "Mode",
"@diveLog_edit_row_mode": {"description": "Row label: OC/CCR/SCR dive mode"},
"diveLog_edit_row_equipment": "Equipment",
"@diveLog_edit_row_equipment": {"description": "Row label: equipment summary"},
"diveLog_edit_row_weight": "Weight",
"@diveLog_edit_row_weight": {"description": "Row label: weight summary"},
"diveLog_edit_summary_tanks": "{count, plural, one{1 tank} other{{count} tanks}}",
"@diveLog_edit_summary_tanks": {"description": "Collapsed summary fragment", "placeholders": {"count": {"type": "int"}}},
"diveLog_edit_summary_items": "{count, plural, one{1 item} other{{count} items}}",
"@diveLog_edit_summary_items": {"description": "Collapsed summary fragment for equipment", "placeholders": {"count": {"type": "int"}}},
```

Translate into the 10 locale arbs, then `flutter gen-l10n`.

- [ ] **Step 11.2: Implement GasGearSection**

Create `lib/features/dive_log/presentation/widgets/edit_sections/gas_gear_section.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Group 2 of the dive form: dive mode, tank cards, CCR/SCR panels,
/// equipment and weights. Interiors are page-provided slots; this widget
/// owns only the group chrome and row composition.
class GasGearSection extends StatelessWidget {
  const GasGearSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.modeSelector,
    required this.tankCards,
    required this.onAddTank,
    required this.addTankLabel,
    required this.equipmentChild,
    required this.weightChild,
    this.rebreatherPanel,
    this.errorCount = 0,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String summary;
  final Widget modeSelector;
  final List<Widget> tankCards;
  final VoidCallback onAddTank;
  final String addTankLabel;
  final Widget equipmentChild;
  final Widget weightChild;

  /// CcrSettingsPanel / ScrSettingsPanel when the mode requires one.
  final Widget? rebreatherPanel;
  final int errorCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return FormSection(
      label: l10n.diveLog_edit_group_gasGear,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      emptyInvitation: l10n.diveLog_edit_invite_gasGear,
      errorCount: errorCount,
      children: [
        FormRow.custom(
            label: l10n.diveLog_edit_row_mode, child: modeSelector),
        if (rebreatherPanel != null) rebreatherPanel!,
        Column(children: tankCards),
        InkWell(
          onTap: onAddTank,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                '+ $addTankLabel',
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        equipmentChild,
        weightChild,
      ],
    );
  }
}
```

- [ ] **Step 11.3: Integrate into the page**

In `dive_edit_page.dart`:

1. Add expansion state and summary helpers to the state class (this is the start of the smart-collapse machinery; later tasks extend `_expanded`):

```dart
static const _kGasGear = 'gasGear';
final Map<String, bool> _expanded = {};

bool _isExpanded(String key, {required bool defaultValue}) =>
    _expanded[key] ?? defaultValue;

void _toggle(String key, {required bool defaultValue}) {
  setState(() =>
      _expanded[key] = !_isExpanded(key, defaultValue: defaultValue));
}

String _gasGearSummary(UnitFormatter units) {
  final l10n = context.l10n;
  final mix = _tanks.isNotEmpty ? _tanks.first.gasMix.displayName : null;
  return [
    l10n.diveLog_edit_summary_tanks(_tanks.length),
    if (mix != null) mix,
    if (_selectedEquipment.isNotEmpty)
      l10n.diveLog_edit_summary_items(_selectedEquipment.length),
  ].join(' · ');
}
```

   (Use the same `gasMix.displayName` accessor as TankCard; fix if the entity exposes a different formatter.)
2. Default expansion (spec rule): editing an existing dive → collapsed; new dive → expanded. Compute `defaultValue: !widget.isEditing` at the call site.
3. Convert the old interiors to slot builders: `Widget _equipmentChild()` = body of `_buildEquipmentSection` minus `Card`/`Padding(16)`/title `Text`; `Widget _weightChild()` = same for `_buildWeightSection`; the mode selector row child = the `DiveModeSelector` widget from `_buildDiveModeSection`, and the CCR/SCR panel construction (the `if (_diveMode == DiveMode.ccr) CcrSettingsPanel(...)` blocks) becomes `Widget? _rebreatherPanel()`.
4. Replace the `_buildDiveModeSection()`, `_buildTankSection()`, `_buildEquipmentSection()`, `_buildWeightSection()` ListView entries (and their separators) with:

```dart
GasGearSection(
  expanded: _isExpanded(_kGasGear, defaultValue: !widget.isEditing),
  onToggle: () => _toggle(_kGasGear, defaultValue: !widget.isEditing),
  summary: _gasGearSummary(units),
  modeSelector: /* DiveModeSelector from _buildDiveModeSection */,
  rebreatherPanel: _rebreatherPanel(),
  tankCards: [
    for (var i = 0; i < _tanks.length; i++)
      TankCard(
        key: ValueKey(_tanks[i].id),
        tank: _tanks[i],
        tankNumber: i + 1,
        units: units,
        onChanged: (updated) => setState(() {
          _tanks[i] = updated;
          _tanksDirty = true;
        }),
        onRemove: _tanks.length > 1 ? () => _removeTank(i) : null,
        canRemove: _tanks.length > 1,
        initiallyExpanded: !widget.isEditing && _tanks.length == 1,
      ),
  ],
  onAddTank: _addTank,
  addTankLabel: context.l10n.diveLog_edit_addTank,
  equipmentChild: _equipmentChild(),
  weightChild: _weightChild(),
),
const SizedBox(height: FormStyle.sectionGap),
```

   Match `onChanged`/`_removeTank`/`_addTank` signatures to the existing `_buildTankSection` wiring (1795-1839) — reuse exactly what it passes to `TankEditor` today. Reuse the existing add-tank label key from that section (`diveLog_edit_addTank` or as actually named — check arb).
5. Delete the four replaced `_build*` methods.

- [ ] **Step 11.4: Verify, format, analyze, commit**

```bash
flutter test test/features/dive_log/presentation/pages/dive_edit_page_test.dart
dart format lib/ test/
flutter analyze
git add lib/features/dive_log/ test/features/dive_log/ lib/l10n/
git commit -m "feat(dive-log): rebuild Gas & Gear group with tank cards and smart collapse"
```

Manual check (`flutter run -d macos`): existing dive shows collapsed "Gas & Gear — 2 tanks · EAN32 · ..." bar; tap expands; mode switch to CCR shows the panel; add/edit/remove tank works; save round-trips.

---

### Task 12: ConditionsSection + page integration

Replaces `_buildEnvironmentSection` (2358-2668) and its `_buildWeatherFields` (2669-2825). Hero owns water temp and air temp (remove those two fields from the moved interiors so each controller has one editing surface); visibility shows as a display cell mirroring the dropdown below.

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/edit_sections/conditions_section.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- Modify: `lib/l10n/arb/app_en.arb` + 10 locale arbs

- [ ] **Step 12.1: Add l10n keys (all 11 arbs)**

```json
"diveLog_edit_group_conditions": "Conditions",
"@diveLog_edit_group_conditions": {"description": "Form group: water, environment and weather"},
"diveLog_edit_invite_conditions": "Add conditions - water, visibility, weather",
"@diveLog_edit_invite_conditions": {"description": "Empty-state invitation for the Conditions group"},
```

Reuse the existing `diveLog_edit_label_airTemp` key and the existing water-temp/visibility label keys (check `app_en.arb` for exact names used today by the environment section) for hero cell labels. Translate the two new keys into the 10 locale arbs, then `flutter gen-l10n`.

- [ ] **Step 12.2: Implement ConditionsSection**

Create `lib/features/dive_log/presentation/widgets/edit_sections/conditions_section.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';
import 'package:submersion/shared/widgets/forms/stat_strip.dart';

/// Group 3 of the dive form. Hero: water temp (edit) / visibility (display)
/// / air temp (edit). The dropdown cluster (dive type, water type,
/// entry/exit, current, swell, altitude, surface pressure) and the weather
/// block (fetch button, wind, humidity, cloud, precipitation, description)
/// move in as page-provided slots.
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
    required this.waterTempLabel,
    required this.airTempLabel,
    required this.visibilityLabel,
    required this.visibilityValue,
    required this.environmentChild,
    required this.weatherChild,
    this.errorCount = 0,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String summary;
  final bool isEmpty;
  final String temperatureSymbol;
  final TextEditingController waterTempController;
  final TextEditingController airTempController;
  final String waterTempLabel;
  final String airTempLabel;
  final String visibilityLabel;
  final String visibilityValue;
  final Widget environmentChild;
  final Widget weatherChild;
  final int errorCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveLog_edit_group_conditions,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      isEmpty: isEmpty,
      emptyInvitation: l10n.diveLog_edit_invite_conditions,
      errorCount: errorCount,
      hero: StatStrip(cells: [
        StatCell(
          label: waterTempLabel,
          unit: temperatureSymbol,
          controller: waterTempController,
        ),
        StatCell(label: visibilityLabel, displayValue: visibilityValue),
        StatCell(
          label: airTempLabel,
          unit: temperatureSymbol,
          controller: airTempController,
        ),
      ]),
      children: [environmentChild, weatherChild],
    );
  }
}
```

- [ ] **Step 12.3: Integrate into the page**

1. Slot builders: `Widget _environmentChild()` = interior of `_buildEnvironmentSection` minus Card/title **and minus the water-temp and air-temp `TextFormField`s** (now hero-owned); `Widget _weatherChild()` = `_buildWeatherFields` content minus the air-temp field, keeping the fetch-weather button and `_isFetchingWeather` wiring.
2. Summary + emptiness helpers:

```dart
String _conditionsSummary(UnitFormatter units) {
  return [
    if (_waterType != null) _waterTypeLabel(_waterType!),
    if (_waterTempController.text.isNotEmpty)
      '${_waterTempController.text} ${units.temperatureSymbol}',
    if (_selectedVisibility != Visibility.unknown)
      _visibilityLabel(_selectedVisibility),
  ].join(' · ');
}

bool _conditionsIsEmpty() => _conditionsSummary(UnitFormatter(
      ref.read(settingsProvider),
    )).isEmpty;
```

   `_waterTypeLabel` / `_visibilityLabel`: reuse exactly the label expressions the existing dropdowns render for these enums (find them in `_buildEnvironmentSection`; if `Visibility` has no `unknown` case, treat null/default as empty). The summary must reuse those expressions, not invent new ones.
3. Replace the `_buildEnvironmentSection(units)` ListView entry with `ConditionsSection(...)` wiring all params (`expanded: _isExpanded('conditions', defaultValue: false)`, visibility display cell text = same label expression), plus `const SizedBox(height: FormStyle.sectionGap)`.
4. Delete `_buildEnvironmentSection` and `_buildWeatherFields` (their interiors now live in the two slot builders).

- [ ] **Step 12.4: Verify, format, analyze, commit**

```bash
flutter test test/features/dive_log/presentation/pages/dive_edit_page_test.dart
dart format lib/ test/
flutter analyze
git add lib/features/dive_log/ lib/l10n/
git commit -m "feat(dive-log): rebuild Conditions group with temperature hero"
```

Manual check: collapsed bar reads like "Salt · 24 °C · Good"; weather fetch still works; editing water temp in the hero round-trips to the saved dive.

---

### Task 13: TripSection and BuddiesSection + page integration

Replaces `_buildTripSection` (1176-1245), `_buildDiveCenterSection` (1329-1382), `_buildBuddySection` (3077-3090). Trip and dive center share one group (user decision); buddies stand alone.

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/edit_sections/trip_section.dart`
- Create: `lib/features/dive_log/presentation/widgets/edit_sections/buddies_section.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- Modify: `lib/l10n/arb/app_en.arb` + 10 locale arbs

- [ ] **Step 13.1: Add l10n keys (all 11 arbs)**

```json
"diveLog_edit_group_trip": "Trip",
"@diveLog_edit_group_trip": {"description": "Form group: trip and dive center"},
"diveLog_edit_invite_trip": "Add trip or dive center",
"@diveLog_edit_invite_trip": {"description": "Empty-state invitation for the Trip group"},
"diveLog_edit_group_buddies": "Buddies",
"@diveLog_edit_group_buddies": {"description": "Form group: dive buddies"},
"diveLog_edit_invite_buddies": "Add buddies",
"@diveLog_edit_invite_buddies": {"description": "Empty-state invitation for the Buddies group"},
"diveLog_edit_row_trip": "Trip",
"@diveLog_edit_row_trip": {"description": "Row label: trip picker"},
"diveLog_edit_row_diveCenter": "Dive center",
"@diveLog_edit_row_diveCenter": {"description": "Row label: dive center picker"},
```

Translate into the 10 locale arbs, then `flutter gen-l10n`.

- [ ] **Step 13.2: Implement both sections**

`trip_section.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Group 4: trip (with the existing date-range suggestion banner) and
/// dive center.
class TripSection extends StatelessWidget {
  const TripSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.isEmpty,
    required this.tripName,
    required this.onPickTrip,
    required this.diveCenterName,
    required this.onPickDiveCenter,
    this.tripSuggestion,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String summary;
  final bool isEmpty;
  final String? tripName;
  final VoidCallback onPickTrip;
  final String? diveCenterName;
  final VoidCallback onPickDiveCenter;

  /// Existing suggestion banner from _buildTripSuggestion, when active.
  final Widget? tripSuggestion;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveLog_edit_group_trip,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      isEmpty: isEmpty,
      emptyInvitation: l10n.diveLog_edit_invite_trip,
      children: [
        FormRow.picker(
          label: l10n.diveLog_edit_row_trip,
          value: tripName,
          placeholder: l10n.diveLog_edit_row_notSet,
          onTap: onPickTrip,
        ),
        if (tripSuggestion != null) tripSuggestion!,
        FormRow.picker(
          label: l10n.diveLog_edit_row_diveCenter,
          value: diveCenterName,
          placeholder: l10n.diveLog_edit_row_notSet,
          onTap: onPickDiveCenter,
        ),
      ],
    );
  }
}
```

`buddies_section.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Group 5: the existing BuddyPicker, hosted in the new chrome.
class BuddiesSection extends StatelessWidget {
  const BuddiesSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.isEmpty,
    required this.buddyPicker,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String summary;
  final bool isEmpty;
  final Widget buddyPicker;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveLog_edit_group_buddies,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      isEmpty: isEmpty,
      emptyInvitation: l10n.diveLog_edit_invite_buddies,
      children: [buddyPicker],
    );
  }
}
```

- [ ] **Step 13.3: Integrate into the page**

1. Summaries:

```dart
String _tripSummary() => [
      if (_selectedTrip != null) _selectedTrip!.name,
      if (_selectedDiveCenter != null) _selectedDiveCenter!.name,
    ].join(' · ');

String _buddiesSummary() {
  if (_selectedBuddies.isEmpty) return '';
  final first = _selectedBuddies.first.buddy.name;
  final extra = _selectedBuddies.length - 1;
  return extra == 0 ? first : '$first +$extra';
}
```

   (Adjust `.buddy.name` to the real `BuddyWithRole` accessor — check the type where `_selectedBuddies` is declared at dive_edit_page.dart:123.)
2. Replace the `_buildTripSection()`, `_buildDiveCenterSection()`, `_buildBuddySection()` ListView entries with the two new sections (trip group placed after Conditions, buddies after trip — final order lands in Task 14), wiring `onPickTrip: _showTripPicker`, `onPickDiveCenter: _showDiveCenterPicker`, `tripSuggestion:` the existing `_buildTripSuggestion(diveDateTime)` output (null when inactive), `buddyPicker:` the existing `BuddyPicker(...)` construction from `_buildBuddySection`, expansion keys `'trip'` / `'buddies'` with `defaultValue: false`, `isEmpty: _tripSummary().isEmpty` / `_selectedBuddies.isEmpty`.
3. Delete `_buildTripSection`, `_buildDiveCenterSection`, `_buildBuddySection` (keep `_buildTripSuggestion`, `_showTripPicker`, `_showDiveCenterPicker`).

- [ ] **Step 13.4: Verify, format, analyze, commit**

```bash
flutter test test/features/dive_log/presentation/pages/dive_edit_page_test.dart
dart format lib/ test/
flutter analyze
git add lib/features/dive_log/ lib/l10n/
git commit -m "feat(dive-log): rebuild Trip and Buddies groups"
```

---

### Task 14: ExperienceSection, rare sections, final group order

Replaces `_buildRatingSection` (3092-3125), `_buildSightingsSection` (3127-3251), `_buildNotesSection` (3332-3356), `_buildTagsSection` (683-705), `_buildCourseSection` (1418-1448), `_buildCustomFieldsSection` (707-786), and locks the final ListView order.

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/edit_sections/experience_section.dart`
- Create: `lib/features/dive_log/presentation/widgets/edit_sections/rare_sections.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- Modify: `lib/l10n/arb/app_en.arb` + 10 locale arbs

- [ ] **Step 14.1: Add l10n keys (all 11 arbs)**

```json
"diveLog_edit_group_experience": "Experience",
"@diveLog_edit_group_experience": {"description": "Form group: rating, marine life, notes, tags"},
"diveLog_edit_invite_experience": "Add rating, sightings, notes or tags",
"@diveLog_edit_invite_experience": {"description": "Empty-state invitation for the Experience group"},
"diveLog_edit_group_course": "Training course",
"@diveLog_edit_group_course": {"description": "Form group: linked training course (rare)"},
"diveLog_edit_group_customFields": "Custom fields",
"@diveLog_edit_group_customFields": {"description": "Form group: custom key/value fields (rare)"},
"diveLog_edit_row_rating": "Rating",
"@diveLog_edit_row_rating": {"description": "Row label: star rating"},
"diveLog_edit_row_notes": "Notes",
"@diveLog_edit_row_notes": {"description": "Row label: dive notes"},
"diveLog_edit_summary_species": "{count, plural, one{1 species} other{{count} species}}",
"@diveLog_edit_summary_species": {"description": "Collapsed summary fragment for sightings", "placeholders": {"count": {"type": "int"}}},
"diveLog_edit_summary_notes": "notes",
"@diveLog_edit_summary_notes": {"description": "Collapsed summary fragment indicating notes exist"},
```

Translate into the 10 locale arbs, then `flutter gen-l10n`.

- [ ] **Step 14.2: Implement ExperienceSection and rare sections**

`experience_section.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Group 6: rating, marine life (existing list as slot), notes, tags
/// (existing TagInputWidget as slot).
class ExperienceSection extends StatelessWidget {
  const ExperienceSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.isEmpty,
    required this.rating,
    required this.onRatingChanged,
    required this.notesController,
    required this.notesPlaceholder,
    required this.sightingsChild,
    required this.tagsChild,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String summary;
  final bool isEmpty;
  final int rating;
  final ValueChanged<int> onRatingChanged;
  final TextEditingController notesController;
  final String notesPlaceholder;
  final Widget sightingsChild;
  final Widget tagsChild;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveLog_edit_group_experience,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      isEmpty: isEmpty,
      emptyInvitation: l10n.diveLog_edit_invite_experience,
      children: [
        FormRow.rating(
          label: l10n.diveLog_edit_row_rating,
          value: rating,
          onChanged: onRatingChanged,
        ),
        sightingsChild,
        FormRow.text(
          label: l10n.diveLog_edit_row_notes,
          controller: notesController,
          placeholder: notesPlaceholder,
          maxLines: 5,
        ),
        tagsChild,
      ],
    );
  }
}
```

`rare_sections.dart` — two thin wrappers in one file:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Rare group: linked training course. Hidden behind AddSectionRow until
/// expanded or populated.
class CourseSection extends StatelessWidget {
  const CourseSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.courseName,
    required this.onPickCourse,
    required this.rowLabel,
    required this.placeholder,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String? courseName;
  final VoidCallback onPickCourse;
  final String rowLabel;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      label: context.l10n.diveLog_edit_group_course,
      expanded: expanded,
      onToggle: onToggle,
      summary: courseName ?? '',
      isEmpty: courseName == null,
      emptyInvitation: placeholder,
      children: [
        FormRow.picker(
          label: rowLabel,
          value: courseName,
          placeholder: placeholder,
          onTap: onPickCourse,
        ),
      ],
    );
  }
}

/// Rare group: custom key/value fields (existing reorderable list as slot).
class CustomFieldsSection extends StatelessWidget {
  const CustomFieldsSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.isEmpty,
    required this.emptyInvitation,
    required this.child,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String summary;
  final bool isEmpty;
  final String emptyInvitation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      label: context.l10n.diveLog_edit_group_customFields,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      isEmpty: isEmpty,
      emptyInvitation: emptyInvitation,
      children: [child],
    );
  }
}
```

- [ ] **Step 14.3: Integrate and lock the final order**

1. Slot builders: `_sightingsChild()` (interior of `_buildSightingsSection` minus Card/title), `_tagsChild()` (the `TagInputWidget` construction), `_customFieldsChild()` (interior of `_buildCustomFieldsSection`).
2. Experience summary:

```dart
String _experienceSummary() {
  final l10n = context.l10n;
  return [
    if (_rating > 0) '${'★' * _rating}${'☆' * (5 - _rating)}',
    if (_sightings.isNotEmpty)
      l10n.diveLog_edit_summary_species(_sightings.length),
    if (_notesController.text.trim().isNotEmpty)
      l10n.diveLog_edit_summary_notes,
    if (_selectedTags.isNotEmpty) '#${_selectedTags.length}',
  ].join(' · ');
}
```

3. Rare-section visibility rule: a rare section renders only when `_expanded[key] == true` **or** it has data (`_selectedCourse != null` / `_customFields.isNotEmpty`); otherwise it appears as an `AddSectionEntry`. Tapping an entry sets `_expanded[key] = true`.
4. The final `build` ListView children (replacing the whole old list at the current equivalent of lines 549-587):

```dart
children: [
  TheDiveSection(/* Task 9 wiring */),
  const SizedBox(height: FormStyle.sectionGap),
  GasGearSection(/* Task 11 wiring */),
  const SizedBox(height: FormStyle.sectionGap),
  ConditionsSection(/* Task 12 wiring */),
  const SizedBox(height: FormStyle.sectionGap),
  TripSection(/* Task 13 wiring */),
  const SizedBox(height: FormStyle.sectionGap),
  BuddiesSection(/* Task 13 wiring */),
  const SizedBox(height: FormStyle.sectionGap),
  ExperienceSection(
    expanded: _isExpanded('experience', defaultValue: false),
    onToggle: () => _toggle('experience', defaultValue: false),
    summary: _experienceSummary(),
    isEmpty: _experienceSummary().isEmpty,
    rating: _rating,
    onRatingChanged: (v) => setState(() => _rating = v),
    notesController: _notesController,
    notesPlaceholder: context.l10n.diveLog_edit_notesHint,
    sightingsChild: _sightingsChild(),
    tagsChild: _tagsChild(),
  ),
  const SizedBox(height: FormStyle.sectionGap),
  if (_showCourseSection)
    CourseSection(
      expanded: _isExpanded('course', defaultValue: _selectedCourse != null),
      onToggle: () => _toggle('course',
          defaultValue: _selectedCourse != null),
      courseName: _selectedCourse?.name,
      onPickCourse: /* existing course picker call from _buildCourseSection */,
      rowLabel: context.l10n.diveLog_edit_section_course,
      placeholder: context.l10n.diveLog_edit_row_notSet,
    ),
  if (_showCustomFieldsSection)
    CustomFieldsSection(
      expanded: _isExpanded('customFields',
          defaultValue: _customFields.isNotEmpty),
      onToggle: () => _toggle('customFields',
          defaultValue: _customFields.isNotEmpty),
      summary: '${_customFields.length}',
      isEmpty: _customFields.isEmpty,
      emptyInvitation: context.l10n.diveLog_edit_addCustomField,
      child: _customFieldsChild(),
    ),
  AddSectionRow(entries: [
    if (!_showCourseSection)
      AddSectionEntry(
        label: context.l10n.diveLog_edit_group_course,
        onTap: () => setState(() => _expanded['course'] = true),
      ),
    if (!_showCustomFieldsSection)
      AddSectionEntry(
        label: context.l10n.diveLog_edit_group_customFields,
        onTap: () => setState(() => _expanded['customFields'] = true),
      ),
  ]),
  const SizedBox(height: 32),
],
```

   with `bool get _showCourseSection => _selectedCourse != null || _expanded['course'] == true;` and the same shape for `_showCustomFieldsSection`. Reuse the existing notes hint and course-section keys (`diveLog_edit_notesHint` / `diveLog_edit_section_course` — verify exact names in `app_en.arb`, the page used them at lines 1418-1448 and 3332-3356).
5. Delete the six replaced `_build*` methods.

- [ ] **Step 14.4: Verify, format, analyze, commit**

```bash
flutter test test/features/dive_log/presentation/pages/dive_edit_page_test.dart
dart format lib/ test/
flutter analyze
git add lib/features/dive_log/ lib/l10n/
git commit -m "feat(dive-log): rebuild Experience and rare groups, lock group order"
```

Manual check: full new-look page; dive with a course shows the course group; one without shows "+ Add: Training course · Custom fields"; tapping expands.

---

### Task 15: Dive coordinator finish — scaffold, dirty tracking, error expand, tests

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- Modify: `test/features/dive_log/presentation/pages/dive_edit_page_test.dart`
- Modify: `docs/superpowers/specs/2026-06-11-edit-form-redesign-design.md` (one correction)

- [ ] **Step 15.1: Adopt EditFormScaffold**

Replace the page's `build` Scaffold/AppBar (lines equivalent to 601-627) and the embedded branch + `_buildEmbeddedHeader` (591-680) with:

```dart
return EditFormScaffold(
  title: widget.isEditing
      ? context.l10n.diveLog_edit_appBarEdit
      : context.l10n.diveLog_edit_appBarNew,
  embedded: widget.embedded,
  isSaving: _isSaving,
  hasUnsavedChanges: _hasUnsavedChanges,
  onSave: () => _saveDive(units),
  onCancel: widget.onCancel,
  headerIcon: widget.isEditing ? Icons.edit : Icons.add_circle_outline,
  child: formBody,
);
```

Delete `_buildEmbeddedHeader`. Keep the `_isLoading` early-return branch as-is.

- [ ] **Step 15.2: Add dirty tracking (the page has no unsaved-changes guard today)**

```dart
bool _hasUnsavedChanges = false;

void _markDirty() {
  if (!_hasUnsavedChanges && !_isLoading) {
    setState(() => _hasUnsavedChanges = true);
  }
}
```

In `initState`, after the controllers are created, attach `_markDirty` as a listener to all TextEditingControllers (the 10 disposed at lines 506-522 plus any added since); remove listeners in `dispose`. Call `_markDirty()` in every user-driven `setState` mutation (site/trip/center/course selection, rating, sightings, equipment, tanks `onChanged`, weights, tags, custom fields, mode, enum dropdowns, date/time pickers). Set `_hasUnsavedChanges = false` at the end of `_loadExistingDive` and immediately before navigation in `_saveDive`'s success path.

- [ ] **Step 15.3: Error auto-expand on failed save**

At the top of `_saveDive`, replace the bare validate with:

```dart
if (!_formKey.currentState!.validate()) {
  setState(() {
    for (final key in const [
      'gasGear', 'conditions', 'trip', 'buddies', 'experience',
      'course', 'customFields',
    ]) {
      _expanded[key] = true;
    }
  });
  return;
}
```

(The dive form has almost no field validators today, so per-group error counts stay 0 here; the site page wires real counts in Task 18. Hidden-validator safety: a collapsed `FormSection` removes its children from the tree, so expanding everything before the next validate pass is what guarantees nothing invalid hides.)

Note: because collapsed sections un-mount their fields, `validate()` only sees visible fields. To keep this airtight, run the expansion FIRST when any group is collapsed, then validate on the next frame:

```dart
final anyCollapsed = const [
  'gasGear', 'conditions', 'trip', 'buddies', 'experience',
].any((k) => !_isExpanded(k, defaultValue: !widget.isEditing && k == 'gasGear'));
if (anyCollapsed) {
  setState(() { /* expand all as above */ });
  await Future<void>.delayed(Duration.zero);
}
if (!_formKey.currentState!.validate()) return;
```

Implement this expand-then-validate form (the second snippet supersedes the first).

- [ ] **Step 15.4: Delete dead code and measure**

Remove any now-unused helpers and imports flagged by analyze.

```bash
wc -l lib/features/dive_log/presentation/pages/dive_edit_page.dart
```

Expected: roughly 2,000-2,300 lines (state + save + pickers wiring + slot builders). **This deviates from the spec's "<~500 lines" coordinator target** — the complex legacy interiors (equipment, weather, sightings, custom fields, profile) deliberately stayed in the page as slot builders to keep every commit behavior-safe. Moving them into the section files is mechanical follow-up work, not a blocker.

- [ ] **Step 15.5: Record the spec corrections**

Two accepted deviations to record in `docs/superpowers/specs/2026-06-11-edit-form-redesign-design.md`:

1. In the Interaction rules section, amend the validation sentence to: "On failed save: auto-expand groups containing errors (inline errors become visible; explicit scroll-to-first-error is deferred — the validated fields sit in the top two groups on both pages)."
2. In the Code organization section, amend the coordinator line to:

```
  pages/dive_edit_page.dart          # coordinator: state, controllers,
                                     # load/save, expansion defaults, and
                                     # slot builders for complex legacy
                                     # interiors (~2,200 lines after Phase 2;
                                     # interior relocation into section files
                                     # is recorded follow-up work)
```

- [ ] **Step 15.6: Page tests for the new behavior**

Extend `test/features/dive_log/presentation/pages/dive_edit_page_test.dart` (reuse the existing harness):

```dart
group('smart collapse', () {
  testWidgets('editing an existing dive: The Dive expanded, others collapsed',
      (tester) async {
    // pump with an existing dive that has tanks + conditions data
    expect(find.text('THE DIVE'), findsOneWidget);
    expect(find.text('GAS & GEAR'), findsOneWidget);
    // collapsed group shows summary bar, not its rows:
    expect(find.text('Mode'), findsNothing);
    // tap the Gas & Gear summary bar to expand:
    await tester.tap(find.text('GAS & GEAR'));
    await tester.pumpAndSettle();
    expect(find.text('Mode'), findsOneWidget);
  });

  testWidgets('new dive: Gas & Gear expanded, Conditions shows invitation',
      (tester) async {
    // pump with diveId: null
    expect(find.text('Mode'), findsOneWidget);
    expect(
      find.text('Add conditions - water, visibility, weather'),
      findsOneWidget,
    );
  });
});
```

(Adjust tap targets if the summary text is easier to hit than the label; the contract is the expand/collapse defaults.)

- [ ] **Step 15.7: Full verify, format, analyze, commit**

```bash
flutter test test/features/dive_log/presentation/pages/dive_edit_page_test.dart
flutter test test/shared/widgets/forms/edit_form_scaffold_test.dart
dart format lib/ test/ docs/ 2>/dev/null || dart format lib/ test/
flutter analyze
git add lib/features/dive_log/ test/features/dive_log/ docs/superpowers/specs/
git commit -m "feat(dive-log): adopt EditFormScaffold, dirty guard and error auto-expand"
```

Manual checklist before moving to the site page (run `flutter run -d macos`):
- [ ] New dive: The Dive + Gas & Gear open, invitations for the rest; create and save a dive.
- [ ] Existing dive: collapsed summaries read correctly; expand/collapse everything.
- [ ] Edit hero stats in place; use-profile-value glyph on a downloaded dive.
- [ ] CCR mode shows panel; tanks add/edit/remove; equipment and weights intact.
- [ ] Cancel with edits prompts discard dialog (full-page mode); embedded mode in the master-detail layout still saves via header.
- [ ] Switch theme (deep + console) and dark mode: groups use tonal surfaces everywhere.

---

### Task 16: FormRow validation hardening + site Identity & Location sections

Two things: (1) a small but important FormRow rule — **a row with a validator always renders its boxed field** (a resting row unmounts its `TextFormField`, which would hide it from `Form.validate()`); (2) the first two site groups.

**Files:**
- Modify: `lib/shared/widgets/forms/form_row.dart`
- Modify: `test/shared/widgets/forms/form_row_test.dart`
- Create: `lib/features/dive_sites/presentation/widgets/edit_sections/identity_section.dart`
- Create: `lib/features/dive_sites/presentation/widgets/edit_sections/location_section.dart`
- Modify: `lib/l10n/arb/app_en.arb` + 10 locale arbs

- [ ] **Step 16.1: Failing test for the validator rule and decoration override**

Add to `test/shared/widgets/forms/form_row_test.dart`:

```dart
testWidgets('row with validator renders persistent field and validates',
    (tester) async {
  final controller = TextEditingController();
  addTearDown(controller.dispose);
  final formKey = GlobalKey<FormState>();
  await tester.pumpWidget(_wrap(Form(
    key: formKey,
    child: FormRow.text(
      label: 'Name',
      controller: controller,
      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
    ),
  )));
  expect(find.byType(TextFormField), findsOneWidget);
  expect(formKey.currentState!.validate(), isFalse);
  await tester.pumpAndSettle();
  expect(find.text('Required'), findsOneWidget);
});

testWidgets('decoration override is honored', (tester) async {
  final controller = TextEditingController(text: 'x');
  addTearDown(controller.dispose);
  await tester.pumpWidget(_wrap(FormRow.text(
    label: 'Country',
    controller: controller,
    alwaysEditing: true,
    decoration: const InputDecoration(
      labelText: 'Country',
      helperText: 'From Site A (1/2)',
    ),
  )));
  expect(find.text('From Site A (1/2)'), findsOneWidget);
});
```

Run `flutter test test/shared/widgets/forms/form_row_test.dart` — expected: the first new test FAILS (no persistent field), the second fails to compile (no `decoration` param).

- [ ] **Step 16.2: Implement in form_row.dart**

In `FormRow.text` add `this.decoration` (`final InputDecoration? decoration;` — add `decoration = null` to every other named constructor's initializer list). In `_FormRowState`, define:

```dart
bool get _persistent =>
    widget.alwaysEditing || widget.validator != null;
```

Use `_persistent` everywhere `widget.alwaysEditing` was checked in the text case, and build the editing field's decoration as:

```dart
decoration: widget.decoration ??
    InputDecoration(
      labelText: widget.label,
      suffixText: widget.suffixText,
    ),
```

Run the form_row tests — all pass. Commit:

```bash
dart format lib/ test/ && flutter analyze
git add lib/shared/widgets/forms/ test/shared/widgets/forms/
git commit -m "feat(forms): persistent fields for validated rows, decoration override"
```

- [ ] **Step 16.3: Add site l10n keys (all 11 arbs)**

```json
"diveSites_edit_group_identity": "Identity",
"@diveSites_edit_group_identity": {"description": "Site form group: name, country, description"},
"diveSites_edit_group_location": "Location",
"@diveSites_edit_group_location": {"description": "Site form group: GPS and altitude"},
"diveSites_edit_group_diveInfo": "Dive info",
"@diveSites_edit_group_diveInfo": {"description": "Site form group: depth, difficulty, rating"},
"diveSites_edit_group_accessSafety": "Access & safety",
"@diveSites_edit_group_accessSafety": {"description": "Site form group: access, mooring, parking, hazards"},
"diveSites_edit_group_lifeNotes": "Life & notes",
"@diveSites_edit_group_lifeNotes": {"description": "Site form group: species, notes, sharing"},
"diveSites_edit_invite_location": "Add GPS position or altitude",
"@diveSites_edit_invite_location": {"description": "Empty-state invitation for the Location group"},
"diveSites_edit_invite_accessSafety": "Add access, parking, mooring or hazards",
"@diveSites_edit_invite_accessSafety": {"description": "Empty-state invitation for the Access & safety group"},
"diveSites_edit_invite_lifeNotes": "Add marine life, notes or sharing",
"@diveSites_edit_invite_lifeNotes": {"description": "Empty-state invitation for the Life & notes group"},
```

Translate into the 10 locale arbs, then `flutter gen-l10n`.

- [ ] **Step 16.4: Implement IdentitySection**

Field order inside the group is deliberately **name, description, country, region** — it preserves the positional `find.byType(TextFormField).at(n)` indices the merge tests rely on (name 0, description 1, country 2).

Create `lib/features/dive_sites/presentation/widgets/edit_sections/identity_section.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Site group 1. Always expanded. The name row carries the required
/// validator (and therefore always renders boxed). In merge mode every
/// row is boxed and decorated by the page's merge decorator.
class IdentitySection extends StatelessWidget {
  const IdentitySection({
    super.key,
    required this.nameController,
    required this.nameValidator,
    required this.descriptionController,
    required this.countryController,
    required this.regionController,
    this.mergeMode = false,
    this.decorationFor,
    this.errorCount = 0,
  });

  final TextEditingController nameController;
  final String? Function(String?) nameValidator;
  final TextEditingController descriptionController;
  final TextEditingController countryController;
  final TextEditingController regionController;
  final bool mergeMode;

  /// Page-provided merge decorator: builds the full InputDecoration for a
  /// field key (wrapping _withMergeTextDecoration). Null outside merge mode.
  final InputDecoration? Function(String fieldKey, String label)?
      decorationFor;
  final int errorCount;

  FormRow _mergeableRow(
    BuildContext context, {
    required String fieldKey,
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return FormRow.text(
      label: label,
      controller: controller,
      maxLines: maxLines,
      alwaysEditing: mergeMode,
      decoration: decorationFor?.call(fieldKey, label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveSites_edit_group_identity,
      expanded: true,
      onToggle: null,
      errorCount: errorCount,
      children: [
        FormRow.text(
          label: l10n.diveSites_edit_field_siteName_label,
          controller: nameController,
          validator: nameValidator,
          decoration: decorationFor?.call(
              'name', l10n.diveSites_edit_field_siteName_label),
        ),
        _mergeableRow(context,
            fieldKey: 'description',
            label: l10n.diveSites_edit_field_description_label,
            controller: descriptionController,
            maxLines: 4),
        _mergeableRow(context,
            fieldKey: 'country',
            label: l10n.diveSites_edit_field_country_label,
            controller: countryController),
        _mergeableRow(context,
            fieldKey: 'region',
            label: l10n.diveSites_edit_field_region_label,
            controller: regionController),
      ],
    );
  }
}
```

(The merge field keys `'name'`, `'description'`, `'country'`, `'region'` must match the keys `_mergeTextCandidates` already uses — check `_cycleTextField` call sites in site_edit_page.dart and use those exact strings.)

- [ ] **Step 16.5: Implement LocationSection**

The GPS interior (Use-My-Location / Pick-from-Map buttons, lat/long validated fields with merge cycling, snackbars) and the altitude interior (field + AltitudeGroup indicator) move in as slots — their logic is page-owned (LocationService etc., lines 1320-1427 and 1562-1702).

Create `lib/features/dive_sites/presentation/widgets/edit_sections/location_section.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Site group 2: GPS coordinates and altitude, as page-provided slots.
class LocationSection extends StatelessWidget {
  const LocationSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.isEmpty,
    required this.gpsChild,
    required this.altitudeChild,
    this.errorCount = 0,
  });

  final bool expanded;
  final VoidCallback? onToggle;
  final String summary;
  final bool isEmpty;
  final Widget gpsChild;
  final Widget altitudeChild;
  final int errorCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveSites_edit_group_location,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      isEmpty: isEmpty,
      emptyInvitation: l10n.diveSites_edit_invite_location,
      errorCount: errorCount,
      children: [gpsChild, altitudeChild],
    );
  }
}
```

- [ ] **Step 16.6: Format, analyze, commit**

```bash
dart format lib/ test/
flutter analyze
git add lib/features/dive_sites/ lib/shared/ test/shared/ lib/l10n/
git commit -m "feat(dive-sites): add Identity and Location form sections"
```

(The sections aren't wired into the page yet — that happens in Task 18 in one pass so the site page flips over atomically; analyze tolerates unused public widgets.)

---

### Task 17: Site DiveInfo, AccessSafety and LifeNotes sections

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/edit_sections/dive_info_section.dart`
- Create: `lib/features/dive_sites/presentation/widgets/edit_sections/access_safety_section.dart`
- Create: `lib/features/dive_sites/presentation/widgets/edit_sections/life_notes_section.dart`

- [ ] **Step 17.1: Implement DiveInfoSection**

Min/max depth become hero cells in normal mode; in merge mode the existing boxed depth fields (with merge cycling) render instead, and the difficulty/rating interiors (which already contain their merge cycle buttons) move in verbatim as slots — this is what keeps the merge tests' `Icons.sync_alt` / `ChoiceChip` / star finders alive.

Create `lib/features/dive_sites/presentation/widgets/edit_sections/dive_info_section.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';
import 'package:submersion/shared/widgets/forms/stat_strip.dart';

/// Site group 3: depth range hero (min/max), difficulty chips, rating.
class DiveInfoSection extends StatelessWidget {
  const DiveInfoSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.isEmpty,
    required this.depthSymbol,
    required this.minDepthController,
    required this.maxDepthController,
    required this.minDepthLabel,
    required this.maxDepthLabel,
    required this.difficultyChild,
    required this.ratingChild,
    this.mergeMode = false,
    this.mergeDepthChild,
  });

  final bool expanded;
  final VoidCallback? onToggle;
  final String summary;
  final bool isEmpty;
  final String depthSymbol;
  final TextEditingController minDepthController;
  final TextEditingController maxDepthController;
  final String minDepthLabel;
  final String maxDepthLabel;

  /// Existing difficulty ChoiceChips row (with merge cycling) verbatim.
  final Widget difficultyChild;

  /// Existing star rating row (with clear + merge cycling) verbatim.
  final Widget ratingChild;
  final bool mergeMode;

  /// Existing boxed depth fields with merge cycling, used instead of the
  /// hero in merge mode.
  final Widget? mergeDepthChild;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveSites_edit_group_diveInfo,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      isEmpty: isEmpty,
      hero: mergeMode
          ? null
          : StatStrip(cells: [
              StatCell(
                label: minDepthLabel,
                unit: depthSymbol,
                controller: minDepthController,
              ),
              StatCell(
                label: maxDepthLabel,
                unit: depthSymbol,
                controller: maxDepthController,
              ),
            ]),
      children: [
        if (mergeMode && mergeDepthChild != null) mergeDepthChild!,
        difficultyChild,
        ratingChild,
      ],
    );
  }
}
```

(`minDepthLabel` / `maxDepthLabel`: pass the existing `diveSites_edit_depth_minLabel` / `diveSites_edit_depth_maxLabel` strings from the page.)

- [ ] **Step 17.2: Implement AccessSafetySection**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Site group 4: access notes, mooring, parking, hazards.
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
    required this.accessLabel,
    required this.mooringLabel,
    required this.parkingLabel,
    required this.hazardsLabel,
    this.mergeMode = false,
    this.decorationFor,
  });

  final bool expanded;
  final VoidCallback? onToggle;
  final String summary;
  final bool isEmpty;
  final TextEditingController accessNotesController;
  final TextEditingController mooringNumberController;
  final TextEditingController parkingInfoController;
  final TextEditingController hazardsController;
  final String accessLabel;
  final String mooringLabel;
  final String parkingLabel;
  final String hazardsLabel;
  final bool mergeMode;
  final InputDecoration? Function(String fieldKey, String label)?
      decorationFor;

  FormRow _row(String key, String label, TextEditingController controller,
      {int maxLines = 1}) {
    return FormRow.text(
      label: label,
      controller: controller,
      maxLines: maxLines,
      alwaysEditing: mergeMode,
      decoration: decorationFor?.call(key, label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveSites_edit_group_accessSafety,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      isEmpty: isEmpty,
      emptyInvitation: l10n.diveSites_edit_invite_accessSafety,
      children: [
        _row('accessNotes', accessLabel, accessNotesController, maxLines: 3),
        _row('mooringNumber', mooringLabel, mooringNumberController),
        _row('parkingInfo', parkingLabel, parkingInfoController, maxLines: 3),
        _row('hazards', hazardsLabel, hazardsController, maxLines: 3),
      ],
    );
  }
}
```

(Merge field keys must match `_mergeTextCandidates` keys — verify in site_edit_page.dart and adjust the four strings.)

- [ ] **Step 17.3: Implement LifeNotesSection**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Site group 5: expected species (slot), notes, share toggle.
class LifeNotesSection extends StatelessWidget {
  const LifeNotesSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.isEmpty,
    required this.speciesChild,
    required this.notesController,
    required this.notesLabel,
    required this.showShareToggle,
    required this.shareLabel,
    required this.isShared,
    required this.onSharedChanged,
    this.mergeMode = false,
    this.decorationFor,
  });

  final bool expanded;
  final VoidCallback? onToggle;
  final String summary;
  final bool isEmpty;
  final Widget speciesChild;
  final TextEditingController notesController;
  final String notesLabel;
  final bool showShareToggle;
  final String shareLabel;
  final bool isShared;
  final ValueChanged<bool> onSharedChanged;
  final bool mergeMode;
  final InputDecoration? Function(String fieldKey, String label)?
      decorationFor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveSites_edit_group_lifeNotes,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      isEmpty: isEmpty,
      emptyInvitation: l10n.diveSites_edit_invite_lifeNotes,
      children: [
        speciesChild,
        FormRow.text(
          label: notesLabel,
          controller: notesController,
          maxLines: 4,
          alwaysEditing: mergeMode,
          decoration: decorationFor?.call('notes', notesLabel),
        ),
        if (showShareToggle)
          FormRow.toggle(
            label: shareLabel,
            value: isShared,
            onChanged: onSharedChanged,
          ),
      ],
    );
  }
}
```

(`onSharedChanged` is the page's existing handler including the unshare-confirmation dialog, lines 651-660 + 859-882.)

- [ ] **Step 17.4: Format, analyze, commit**

```bash
dart format lib/
flutter analyze
git add lib/features/dive_sites/
git commit -m "feat(dive-sites): add DiveInfo, AccessSafety and LifeNotes sections"
```

---

### Task 18: Site coordinator flip + merge mode + test updates

The site page switches to the new sections in one atomic pass (it is much smaller than the dive page, and merge mode makes incremental flipping riskier than a single cut-over).

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart`
- Modify: `test/features/dive_sites/presentation/pages/site_edit_page_test.dart`
- Modify: `test/features/dive_sites/presentation/pages/site_edit_merge_page_test.dart`

- [ ] **Step 18.1: Rebuild the form body**

Replace the main form body (lines 480-689) with the five sections in order Identity, Location, Dive info, Access & safety, Life & notes, separated by `SizedBox(height: FormStyle.sectionGap)`, inside the existing `Form`. Wiring:

- Slot builders from existing interiors: `_gpsChild()` (GPS section minus Card/title, 1429-1560), `_altitudeChild()` (1562-1702), `_difficultyChild()` (chips row + merge cycle, 1262-1316), `_ratingChild()` (stars + clear + merge cycle, 1120-1186), `_speciesChild()` (1821-1897), and in merge mode `_mergeDepthChild()` (depth fields with cycling, 1188-1260).
- Merge decorator passed to sections:

```dart
InputDecoration? _decorationFor(String fieldKey, String label) {
  if (!widget.isMerging) return null;
  return _withMergeTextDecoration(
    fieldKey,
    InputDecoration(labelText: label),
  );
}
```

  (Match `_withMergeTextDecoration`'s actual signature at lines 985-1009.)
- Expansion state map (same pattern as the dive page):

```dart
final Map<String, bool> _expanded = {};

bool _sectionExpanded(String key) {
  if (widget.isMerging) return true; // merge mode: everything open
  final defaults = widget.isEditing
      ? {'location': false, 'diveInfo': false, 'access': false, 'life': false}
      : {'location': false, 'diveInfo': true, 'access': false, 'life': false};
  return _expanded[key] ?? defaults[key]!;
}
```

  (Spec rule: new site → Identity + Dive info expanded; existing → Identity only; Identity itself is always expanded via `onToggle: null`. In merge mode pass `onToggle: null` to every section so nothing can collapse.)
- Summaries:

```dart
String _locationSummary() => [
      if (_latitudeController.text.isNotEmpty &&
          _longitudeController.text.isNotEmpty)
        '${_latitudeController.text}, ${_longitudeController.text}',
      if (_altitudeController.text.isNotEmpty)
        '${_altitudeController.text} ${UnitFormatter(ref.read(settingsProvider)).altitudeSymbol}',
    ].join(' · ');

String _diveInfoSummary() => [
      if (_minDepthController.text.isNotEmpty ||
          _maxDepthController.text.isNotEmpty)
        '${_minDepthController.text}-${_maxDepthController.text}',
      if (_difficulty != null) _difficultyLabel(_difficulty!),
      if (_rating > 0) '★' * _rating.round(),
    ].join(' · ');

String _accessSummary() => [
      if (_accessNotesController.text.isNotEmpty) accessLabelShort,
      if (_mooringNumberController.text.isNotEmpty) mooringLabelShort,
      if (_parkingInfoController.text.isNotEmpty) parkingLabelShort,
      if (_hazardsController.text.isNotEmpty) hazardsLabelShort,
    ].join(' · ');

String _lifeNotesSummary() => [
      if (_expectedSpecies.isNotEmpty)
        l10nSpeciesCount(_expectedSpecies.length),
      if (_notesController.text.trim().isNotEmpty) notesFragment,
      if (_isShared) sharedFragment,
    ].join(' · ');
```

  Use existing label keys for the short fragments (the section labels themselves are fine: e.g. reuse `diveSites_edit_access_accessNotes_label`); for species count reuse `diveLog_edit_summary_species`; for notes reuse `diveLog_edit_summary_notes`; for "shared" reuse `common_label_shareWithAllProfiles` truncated is wrong — instead reuse the existing word from `common_action_unshare`'s positive counterpart if one exists, else add one new key `diveSites_edit_summary_shared: "shared"` (+ metadata + 10 translations). Check the arb first; only add if missing. If `UnitFormatter` has no `altitudeSymbol` getter, use `depthSymbol` (altitude shares the depth unit) — verify in unit_formatter.dart.
- Per-group error counts (real validators exist here):

```dart
int _identityErrorCount() =>
    _nameValidator(_nameController.text) == null ? 0 : 1;

int _locationErrorCount() {
  var count = 0;
  if (_latValidator(_latitudeController.text) != null) count++;
  if (_lonValidator(_longitudeController.text) != null) count++;
  return count;
}
```

  (`_nameValidator`/`_latValidator`/`_lonValidator`: extract the existing inline validator lambdas from the name and GPS fields into named methods so both the fields and the counts share them.) Recompute on every build; they feed `errorCount:` on Identity/Location.
- Save flow: keep `_saveSite` exactly as-is, but apply the same expand-then-validate pattern as Task 15 step 15.3 (expand all site groups, `await Future<void>.delayed(Duration.zero)`, then validate).

- [ ] **Step 18.2: Adopt EditFormScaffold**

Replace both PopScope branches (692-761) and the embedded header (764-837) with `EditFormScaffold(title: <existing appBar title logic incl. merge title>, embedded: widget.embedded, isSaving: _isLoading, hasUnsavedChanges: _hasChanges, onSave: _saveSite, onCancel: widget.onCancel, headerIcon: widget.isEditing ? Icons.edit : Icons.add_location, child: formBody)`. Keep the existing delete action: pass the AppBar delete IconButton through by ADDING an optional `actions: List<Widget>?` parameter to `EditFormScaffold` (insert before the save button in both modes; default null) — update `edit_form_scaffold_test.dart` with one test that a provided action renders. Delete the page's own discard dialog methods (839-857) — the scaffold owns that now.

- [ ] **Step 18.3: Update the site tests**

Finder migration table (apply mechanically in both site test files):

| Old finder | New finder |
|---|---|
| `find.text('Depth Range')` | `find.text('DIVE INFO')` |
| `find.text('Difficulty Level')` | (chips remain) `find.byType(ChoiceChip)` / `find.widgetWithText(ChoiceChip, 'Beginner')` unchanged |
| `find.text('Rating')` | `find.text('DIVE INFO')` group label; star finders unchanged |
| `find.text('GPS Coordinates')` | `find.text('LOCATION')` |
| `find.text('Access & Logistics')` | `find.text('ACCESS & SAFETY')` |
| `find.byWidgetPredicate(... SwitchListTile ...)` | `find.byType(Switch)` |
| `find.ancestor(of: X, matching: find.byType(Card))` | drop the ancestor constraint or use `find.byType(FormSection)` ancestors |
| AppBar `Save` TextButton | unchanged (`forms_save` renders "Save") |
| Discard dialog `'Discard'` strings | the scaffold's `forms_discard_*` strings ("Discard changes?", "Keep editing", "Discard") |

Behavior-preserving additions: in non-merge tests that interact with collapsed groups (rating stars, GPS fields, share toggle on a NEW site), first expand the group: `await tester.tap(find.text('DIVE INFO')); await tester.pumpAndSettle();` (Dive info is already expanded for new sites — only Location/Access/Life need the expand tap). Merge tests need no expand taps (everything is open in merge mode) and their positional `TextFormField` indices hold (Identity preserves name/description/country/region order; depth fields render boxed via `mergeDepthChild`).

- [ ] **Step 18.4: Verify, format, analyze, commit**

```bash
flutter test test/features/dive_sites/presentation/pages/site_edit_page_test.dart
flutter test test/features/dive_sites/presentation/pages/site_edit_merge_page_test.dart
flutter test test/shared/widgets/forms/edit_form_scaffold_test.dart
dart format lib/ test/
flutter analyze
git add lib/features/dive_sites/ lib/shared/ test/
git commit -m "feat(dive-sites): rebuild site edit on shared form sections incl. merge mode"
```

Manual check (`flutter run -d macos`): new site (Identity + Dive info open, invitations below), existing site (summaries), merge of 2-3 sites (all open, cycling works, merge saves), delete action still present, embedded master-detail mode.

---

### Task 19: Final sweep

**Files:** none new

- [ ] **Step 19.1: Full verification battery**

```bash
dart format lib/ test/
flutter analyze
flutter test test/shared/widgets/forms/form_section_test.dart test/shared/widgets/forms/stat_strip_test.dart test/shared/widgets/forms/form_row_test.dart test/shared/widgets/forms/unit_field_test.dart test/shared/widgets/forms/add_section_row_test.dart test/shared/widgets/forms/edit_form_scaffold_test.dart
flutter test test/features/dive_log/presentation/pages/dive_edit_page_test.dart test/features/dive_log/presentation/widgets/tank_card_test.dart
flutter test test/features/dive_sites/presentation/pages/site_edit_page_test.dart test/features/dive_sites/presentation/pages/site_edit_merge_page_test.dart
```

Expected: format makes no changes; analyze clean; all listed suites green.

- [ ] **Step 19.2: l10n parity check**

```bash
for f in lib/l10n/arb/app_*.arb; do echo "$f: $(grep -c '"forms_\|"diveLog_edit_group_\|"diveLog_edit_invite_\|"diveLog_edit_row_\|"diveLog_edit_summary_\|"diveLog_edit_tankCard_\|"diveSites_edit_group_\|"diveSites_edit_invite_' "$f")"; done
```

Expected: identical counts across all 11 files (en counts each key twice if the grep catches `@`-entries — compare like with like; the point is no locale is missing keys). Fix any gaps, rerun `flutter gen-l10n`.

- [ ] **Step 19.3: Full manual pass on macOS**

`flutter run -d macos`, then walk: new dive end-to-end save; edit downloaded dive (profile affordances); CCR dive; multi-tank; new site; edit site; merge three sites; both pages in master-detail embedded mode; resize window narrow/wide (640dp max-width centering); themes submersion/deep/console in light + dark. Anything off: fix, re-run the affected test file, amend or follow-up commit.

- [ ] **Step 19.4: Close out**

```bash
git log --oneline main..HEAD
git push -u origin feat/edit-form-redesign
```

Then hand back for PR creation (`docs/superpowers/specs/2026-06-11-edit-form-redesign-design.md` is the PR description's source material). Remaining follow-up recorded in the spec: migrate the other ~18 edit pages onto the primitives; relocate dive-page slot builders into their section files.




