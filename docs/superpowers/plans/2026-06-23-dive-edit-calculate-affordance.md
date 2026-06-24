# Dive edit: flatten "The Dive" group + restore calculate-from-profile button — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the hero stat-strip from the dive edit form so max/avg depth and bottom time read as ordinary rows (Dive #, Entry, Exit on top), and restore a prominent one-tap "Calculate from dive profile" button on max depth, avg depth, bottom time, and runtime.

**Architecture:** Add a one-tap calculate affordance to the shared `FormRow.text` widget (gated by an optional `ProfileSuggestion`), flatten `TheDiveSection` from a `StatStrip` hero into a flat `FormRow` list, wire the four profile-derivable rows to the existing `_calculate*FromProfile` handlers, then delete the now-dead `StatCell` suggestion glyph.

**Tech Stack:** Flutter / Dart, Material 3, `flutter_test` widget tests, `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-06-23-dive-edit-calculate-affordance-design.md`
**Issue:** [#388](https://github.com/submersion-app/submersion/issues/388)

## Global Constraints

- No emojis in code, comments, or docs.
- `dart format .` must pass with no changes; `flutter analyze` must be clean.
- Units shown must respect the active diver's `UnitFormatter` (unchanged here: the section already receives `depthSymbol` and formats via the page's `units`).
- No new user-facing strings: reuse the existing, already-translated `diveLog_edit_tooltip_calculateFromProfile` ("Calculate from dive profile").
- `FormRow` is a generic shared widget and must stay free of feature-specific l10n: the tooltip text is passed in as a plain string, not looked up inside `FormRow`.
- Each task ends with a commit (per-task commits are pre-authorized for this approved plan on the feature branch / worktree).

---

### Task 1: Add a one-tap calculate affordance to `FormRow.text`

**Files:**
- Modify: `lib/shared/widgets/forms/form_row.dart`
- Test: `test/shared/widgets/forms/form_row_test.dart`

**Interfaces:**
- Produces: `class ProfileSuggestion { const ProfileSuggestion({required String value, required VoidCallback onUse, required String tooltip}); }` exported from `form_row.dart`.
- Produces: new optional parameter on `FormRow.text`: `ProfileSuggestion? profileSuggestion`. When non-null and `profileSuggestion.value != controller.text`, the resting row shows a trailing `Icons.calculate_outlined` button (tooltip = `profileSuggestion.tooltip`) that calls `profileSuggestion.onUse` on a single tap.

- [ ] **Step 1: Write the failing tests**

Add this group to `test/shared/widgets/forms/form_row_test.dart` (inside `main()`, after the existing `FormRow.text` group). `ProfileSuggestion` is imported transitively via the existing `import '.../form_row.dart';`.

```dart
  group('FormRow.text calculate affordance', () {
    testWidgets(
      'shows calculate icon when suggestion differs; tap fires onUse '
      'without entering edit mode',
      (tester) async {
        final controller = TextEditingController(text: '0.0');
        addTearDown(controller.dispose);
        var used = 0;
        await tester.pumpWidget(
          _wrap(
            FormRow.text(
              label: 'Avg depth',
              controller: controller,
              suffixText: 'm',
              profileSuggestion: ProfileSuggestion(
                value: '18.5',
                tooltip: 'Calculate from dive profile',
                onUse: () => used++,
              ),
            ),
          ),
        );
        expect(find.byIcon(Icons.calculate_outlined), findsOneWidget);
        await tester.tap(find.byIcon(Icons.calculate_outlined));
        expect(used, 1);
        expect(find.byType(TextFormField), findsNothing);
      },
    );

    testWidgets('hides calculate icon when value already matches suggestion', (
      tester,
    ) async {
      final controller = TextEditingController(text: '18.5');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          FormRow.text(
            label: 'Avg depth',
            controller: controller,
            profileSuggestion: ProfileSuggestion(
              value: '18.5',
              tooltip: 'Calculate from dive profile',
              onUse: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.calculate_outlined), findsNothing);
    });

    testWidgets('no calculate icon without a suggestion', (tester) async {
      final controller = TextEditingController(text: '0.0');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(FormRow.text(label: 'Avg depth', controller: controller)),
      );
      expect(find.byIcon(Icons.calculate_outlined), findsNothing);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/shared/widgets/forms/form_row_test.dart`
Expected: FAIL — `ProfileSuggestion` undefined / `profileSuggestion` is not a parameter of `FormRow.text`.

- [ ] **Step 3: Add the `ProfileSuggestion` class**

In `lib/shared/widgets/forms/form_row.dart`, after the imports and before `enum _RowKind`, add:

```dart
/// A value derived from the dive profile, offered as a one-tap fill on a
/// [FormRow.text] row. When [value] differs from the row's current text, the
/// resting row shows a calculate icon (tooltip [tooltip]) that calls [onUse].
class ProfileSuggestion {
  const ProfileSuggestion({
    required this.value,
    required this.onUse,
    required this.tooltip,
  });

  /// Already formatted in the diver's units (e.g. "18.5").
  final String value;
  final VoidCallback onUse;
  final String tooltip;
}
```

- [ ] **Step 4: Add the parameter and field**

In the `FormRow.text` constructor parameter list, add `this.profileSuggestion,` (after `this.decoration,`). In every OTHER constructor's initializer list (`FormRow.picker`, `FormRow.display`, `FormRow.toggle`, `FormRow.rating`, `FormRow.custom`), add `profileSuggestion = null,`. Then add the field declaration next to the other finals (after `final Widget? child;`):

```dart
  final ProfileSuggestion? profileSuggestion;
```

- [ ] **Step 5: Render the trailing calculate icon in the resting text row**

In `_FormRowState.build`, replace the `case _RowKind.text:` resting-state `return AnimatedBuilder(...)` block (the one after `if (_persistent || _editing)`) with:

```dart
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
            final valueText = Text(
              shown,
              style: _valueTextStyle(context, muted: empty),
              maxLines: widget.maxLines > 1 ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            );
            final suggestion = widget.profileSuggestion;
            final showCalc = suggestion != null && suggestion.value != text;
            return _shell(
              context,
              onTap: () => setState(() => _editing = true),
              trailing: showCalc
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: valueText),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: suggestion.tooltip,
                          child: InkWell(
                            onTap: suggestion.onUse,
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.calculate_outlined,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : valueText,
            );
          },
        );
```

(`theme` is already defined at the top of `build` as `final theme = Theme.of(context);`.)

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/shared/widgets/forms/form_row_test.dart`
Expected: PASS (all groups, including the new one).

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format lib/shared/widgets/forms/form_row.dart test/shared/widgets/forms/form_row_test.dart
flutter analyze lib/shared/widgets/forms/form_row.dart
git add lib/shared/widgets/forms/form_row.dart test/shared/widgets/forms/form_row_test.dart
git commit -m "feat(forms): one-tap calculate affordance on FormRow.text (#388)"
```

---

### Task 2: Flatten "The Dive" section into rows and wire the four calculate buttons

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (add `tooltip:` to two suggestion builders)
- Test: `test/features/dive_log/presentation/widgets/edit_sections/the_dive_section_test.dart` (new)

**Interfaces:**
- Consumes: `ProfileSuggestion` and `FormRow.text(profileSuggestion: ...)` from Task 1.
- `TheDiveSection`'s public constructor is unchanged: it keeps `maxDepthSuggestion` / `avgDepthSuggestion` / `bottomTimeSuggestion` / `runtimeSuggestion` (now the relocated `ProfileSuggestion`), and renders them on the corresponding rows.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/dive_log/presentation/widgets/edit_sections/the_dive_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/stat_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets(
    'renders metric fields as flat rows (no hero) with Dive #, Entry, Exit on '
    'top and a one-tap avg-depth calculate button',
    (tester) async {
      final maxC = TextEditingController(text: '0.0');
      final avgC = TextEditingController(text: '0.0');
      final botC = TextEditingController(text: '0');
      final runC = TextEditingController(text: '0');
      final numC = TextEditingController(text: '142');
      for (final c in [maxC, avgC, botC, runC, numC]) {
        addTearDown(c.dispose);
      }
      var avgUsed = 0;

      await tester.pumpWidget(
        _wrap(
          TheDiveSection(
            depthSymbol: 'm',
            maxDepthController: maxC,
            avgDepthController: avgC,
            bottomTimeController: botC,
            runtimeController: runC,
            diveNumberController: numC,
            entryText: 'ENTRY_TS',
            onEditEntry: () {},
            exitText: 'EXIT_TS',
            onEditExit: () {},
            siteName: 'Blue Hole',
            onPickSite: () {},
            avgDepthSuggestion: ProfileSuggestion(
              value: '18.5',
              tooltip: 'Calculate from dive profile',
              onUse: () => avgUsed++,
            ),
          ),
        ),
      );

      // Hero strip is gone.
      expect(find.byType(StatStrip), findsNothing);

      // Top three rows in order: Dive #, Entry, Exit.
      double top(Finder f) => tester.getTopLeft(f).dy;
      expect(top(find.text('142')), lessThan(top(find.text('ENTRY_TS'))));
      expect(top(find.text('ENTRY_TS')), lessThan(top(find.text('EXIT_TS'))));

      // Avg depth shows the single one-tap calculate button and it fires onUse.
      expect(find.byIcon(Icons.calculate_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.calculate_outlined));
      expect(avgUsed, 1);
    },
  );
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/edit_sections/the_dive_section_test.dart`
Expected: FAIL — `StatStrip` is still present (`findsNothing` fails) and/or no `calculate_outlined` icon.

- [ ] **Step 3: Rewrite `the_dive_section.dart`**

Replace the entire file with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Group 1 of the dive form: always expanded, owns the core facts.
/// Rows: dive number, entry, exit, surface interval, max depth, avg depth,
/// bottom time, runtime, site, then site extras and the profile block.
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
    this.onClearSite,
    this.maxDepthSuggestion,
    this.avgDepthSuggestion,
    this.bottomTimeSuggestion,
    this.runtimeSuggestion,
    this.surfaceIntervalRow,
    this.siteExtras,
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
  final VoidCallback? onClearSite;
  final ProfileSuggestion? maxDepthSuggestion;
  final ProfileSuggestion? avgDepthSuggestion;
  final ProfileSuggestion? bottomTimeSuggestion;
  final ProfileSuggestion? runtimeSuggestion;

  /// Surface interval display row (provider-backed), when editing.
  final Widget? surfaceIntervalRow;

  /// Location status, selected-site caption and photo-GPS banner.
  final Widget? siteExtras;

  /// Existing profile block (points count, outlier chip, edit/draw buttons).
  final Widget? profileChild;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveLog_edit_group_theDive,
      expanded: true,
      onToggle: null,
      children: [
        FormRow.text(
          label: l10n.diveLog_edit_label_diveNumber,
          controller: diveNumberController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
        ?surfaceIntervalRow,
        FormRow.text(
          label: l10n.diveLog_edit_label_maxDepth,
          controller: maxDepthController,
          suffixText: depthSymbol,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          profileSuggestion: maxDepthSuggestion,
        ),
        FormRow.text(
          label: l10n.diveLog_edit_label_avgDepth,
          controller: avgDepthController,
          suffixText: depthSymbol,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          profileSuggestion: avgDepthSuggestion,
        ),
        FormRow.text(
          label: l10n.diveLog_edit_label_bottomTime,
          controller: bottomTimeController,
          suffixText: 'min',
          keyboardType: TextInputType.number,
          profileSuggestion: bottomTimeSuggestion,
        ),
        FormRow.text(
          label: l10n.diveLog_edit_label_runtime,
          controller: runtimeController,
          suffixText: 'min',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          placeholder: l10n.diveLog_edit_row_notSet,
          profileSuggestion: runtimeSuggestion,
        ),
        FormRow.picker(
          label: l10n.diveLog_edit_row_site,
          value: siteName,
          placeholder: l10n.diveLog_edit_row_addSite,
          onTap: onPickSite,
          onClear: siteName == null ? null : onClearSite,
        ),
        ?siteExtras,
        ?profileChild,
      ],
    );
  }
}
```

- [ ] **Step 4: Add the tooltip to the page's suggestion builders**

In `lib/features/dive_log/presentation/pages/dive_edit_page.dart`, update `_depthSuggestion` and `_minutesSuggestion` to set the tooltip from the revived (already-translated) l10n string. `form_row.dart` is already imported (line 69).

`_depthSuggestion` becomes:

```dart
  ProfileSuggestion? _depthSuggestion(
    UnitFormatter units,
    double? meters,
    VoidCallback onUse,
  ) {
    if (meters == null) return null;
    return ProfileSuggestion(
      value: units.convertDepth(meters).toStringAsFixed(1),
      onUse: onUse,
      tooltip: context.l10n.diveLog_edit_tooltip_calculateFromProfile,
    );
  }
```

`_minutesSuggestion` becomes:

```dart
  ProfileSuggestion? _minutesSuggestion(Duration? duration, VoidCallback onUse) {
    if (duration == null) return null;
    return ProfileSuggestion(
      value: duration.inMinutes.toString(),
      onUse: onUse,
      tooltip: context.l10n.diveLog_edit_tooltip_calculateFromProfile,
    );
  }
```

(The `_buildTheDiveSection` method itself is unchanged — it already passes the four suggestions to `TheDiveSection`.)

- [ ] **Step 5: Run the new test and the page test suite to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/edit_sections/the_dive_section_test.dart test/features/dive_log/presentation/pages/dive_edit_page_test.dart`
Expected: PASS. If a `dive_edit_page` test asserted the old hero/`StatStrip`, update it to the row layout (interactions are by field label/value, which are unchanged).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/presentation/widgets/edit_sections/the_dive_section_test.dart
flutter analyze lib/features/dive_log lib/shared/widgets/forms
git add lib/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/presentation/widgets/edit_sections/the_dive_section_test.dart
git commit -m "feat(dive-edit): flatten The Dive group to rows + restore calculate buttons (#388)"
```

---

### Task 3: Remove the now-dead `StatCell` suggestion glyph

**Files:**
- Modify: `lib/shared/widgets/forms/stat_strip.dart`
- Test: `test/shared/widgets/forms/stat_strip_test.dart`

**Interfaces:**
- After Task 2, `the_dive_section` is the only place that ever set `StatCell.profileValue`; nothing does now, so the glyph code is unreachable. Removing it changes no live behavior.

- [ ] **Step 1: Delete the glyph's test group**

In `test/shared/widgets/forms/stat_strip_test.dart`, delete the entire `group('StatCell profile affordance', () { ... })` block (the two tests asserting `Icons.sync_outlined` and the "Use ... from profile" menu).

- [ ] **Step 2: Remove the glyph code from `StatCell`**

In `lib/shared/widgets/forms/stat_strip.dart`:
- Remove constructor params `this.profileValue,` and `this.onUseProfileValue,`.
- Remove the doc comment and fields:
  ```dart
  /// Value computed from the dive profile; when it differs from the current
  /// text, a sync glyph offers to apply it via [onUseProfileValue].
  final String? profileValue;
  final ValueChanged<String>? onUseProfileValue;
  ```
- Remove the `_showProfileGlyph` getter:
  ```dart
  bool get _showProfileGlyph =>
      widget.profileValue != null &&
      widget.onUseProfileValue != null &&
      widget.profileValue != widget.controller?.text;
  ```
- Remove the conditional child `if (_showProfileGlyph) _buildProfileGlyph(context),` from the resting-row `Row`.
- Remove the entire `_buildProfileGlyph` method (the `PopupMenuButton` with `Icons.sync_outlined` and the two `forms_statCell_useProfileValue` references).

- [ ] **Step 3: Run the forms tests to verify they pass**

Run: `flutter test test/shared/widgets/forms/`
Expected: PASS — remaining `StatCell` tests (value/unit/label, placeholder, display-only, edit mode) and all `FormRow` tests green; no references to the removed glyph.

- [ ] **Step 4: Format, analyze, commit**

```bash
dart format lib/shared/widgets/forms/stat_strip.dart test/shared/widgets/forms/stat_strip_test.dart
flutter analyze lib/shared/widgets/forms
git add lib/shared/widgets/forms/stat_strip.dart test/shared/widgets/forms/stat_strip_test.dart
git commit -m "refactor(forms): drop unused StatCell profile glyph (#388)"
```

---

### Task 4 (optional cleanup): Remove the orphaned `forms_statCell_useProfileValue` string

The glyph removed in Task 3 was the only user of this string. Leaving it is harmless (gen-l10n does not error on unused keys); do this task only if you want the ARBs tidy. Skipping it does not affect #388.

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (remove the key and its `@forms_statCell_useProfileValue` metadata)
- Modify: the 10 other locale ARBs in `lib/l10n/arb/` (remove the `forms_statCell_useProfileValue` key)
- Regenerate: `lib/l10n/arb/app_localizations*.dart` via `flutter gen-l10n`

- [ ] **Step 1: Confirm the string is orphaned**

Run: `grep -rn "forms_statCell_useProfileValue" lib --include="*.dart" | grep -v app_localizations | grep -v "/arb/"`
Expected: no output (no remaining code references).

- [ ] **Step 2: Remove the key from every ARB**

Remove the `"forms_statCell_useProfileValue": ...` line from each `lib/l10n/arb/app_*.arb`, and additionally remove the `"@forms_statCell_useProfileValue": { ... }` metadata block from the template `app_en.arb`.

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: regenerates `lib/l10n/arb/app_localizations*.dart` with the getter gone.

- [ ] **Step 4: Analyze to confirm nothing referenced it**

Run: `flutter analyze`
Expected: clean (no "getter isn't defined" errors).

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/arb/
git commit -m "chore(l10n): remove orphaned forms_statCell_useProfileValue (#388)"
```

---

## Final verification (after all tasks)

- [ ] Run the affected suites together:
  `flutter test test/shared/widgets/forms/ test/features/dive_log/presentation/widgets/edit_sections/ test/features/dive_log/presentation/pages/dive_edit_page_test.dart`
- [ ] `dart format --set-exit-if-changed lib/ test/`
- [ ] `flutter analyze` (whole project) — clean.
- [ ] Manual macOS pass: open a downloaded dive with a profile, confirm Dive #/Entry/Exit are the top three rows, and the calculate icon fills max/avg depth, bottom time, and runtime.

## Self-Review

**1. Spec coverage:**
- Spec §1 (remove hero, new order, Dive #/Entry/Exit on top) → Task 2 (rewrite + order test). ✓
- Spec §2 (calculate affordance on `FormRow.text`, show-condition, one-tap, isolated tap) → Task 1. ✓
- Spec §3 (wire max/avg/bottom/runtime) → Task 2 (four `FormRow.text` rows + page tooltip). ✓
- Spec §4 cleanup: delete `ProfileSuggestion` (relocated to `form_row.dart` in Task 1), delete `StatCell` glyph (Task 3), remove `forms_statCell_useProfileValue` (Task 4), revive `diveLog_edit_tooltip_calculateFromProfile` (Task 2). ✓
- Spec testing section → per-task TDD + final verification. ✓

**2. Placeholder scan:** No TBD/TODO; every code step shows complete code; commands have expected output. The one conditional ("update a `dive_edit_page` test if it asserted the hero") is guarded by a grep finding (only `stat_strip_test` referenced the glyph), so it is a contingency, not a gap.

**3. Type consistency:** `ProfileSuggestion` has exactly `{value, onUse, tooltip}` everywhere (defined Task 1; built in Task 2's page builders; consumed by `FormRow.text.profileSuggestion`). `TheDiveSection`'s four `*Suggestion` params stay `ProfileSuggestion?` and map 1:1 to the four `FormRow.text` rows. Icon is `Icons.calculate_outlined` in both impl and tests.

## Execution note (worktree)

Per CLAUDE.md, implement in a dedicated worktree. After creating it, run `git submodule update --init --recursive`, `flutter pub get`, and `dart run build_runner build --delete-conflicting-outputs` (DB-touching tests need the generated `database.g.dart`) before Task 1.
