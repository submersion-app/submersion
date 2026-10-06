# Naming a Saved Dive Plan Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prompt the diver for a plan name the first time a dive plan is saved, pre-filled with a generated site + depth + date default, and make renaming discoverable from both the plan canvas and the saved-plans list.

**Architecture:** Presentation layer only. `dive_plans.name` already exists as a non-null synced column, so there is no migration, no sync work, and no repository change. A pure name generator lives in the planner's domain services; a reusable dialog widget lives in the planner's presentation widgets; the plan canvas gates its first save on that dialog; the saved-plans sheet gains a Rename menu entry.

**Tech Stack:** Flutter, Riverpod (`StateNotifier`), Drift (unchanged), `intl` `DateFormat`, `flutter_test` / `flutter gen-l10n`.

## Global Constraints

- Working directory is the worktree `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/name-saved-dive-plan` on branch `worktree-name-saved-dive-plan`. Do not `cd` to the main checkout.
- Run `dart format .` (whole project, not just changed files) before every commit. CI fails on `dart format --set-exit-if-changed`.
- Run `flutter analyze` over the whole project with no `| tail`, `| head`, or other pipe. Infos are fatal in CI.
- No emojis in code, comments, or documentation.
- Immutability: never mutate entities in place; use `copyWith`.
- Any user-visible string must come from `context.l10n`, never a hardcoded literal. The one exception preserved by this plan is the pre-existing in-memory placeholder `'New Dive Plan'`.
- New ARB keys must be added to `lib/l10n/arb/app_en.arb` **and** all ten non-English locales (`ar`, `de`, `es`, `fr`, `he`, `hu`, `it`, `nl`, `pt`, `zh`), then regenerated with `flutter gen-l10n`.
- Anything displaying a depth must respect the active diver's unit settings via `UnitFormatter`.
- Files stay 200-400 lines typical, 800 max.
- Do not bump `DatabaseService.currentSchemaVersion`. This feature requires no migration.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/features/planner/domain/services/plan_name_generator.dart` (create) | Pure composition of a default plan name from site, depth label, date, and fallback. No Flutter or Riverpod imports. |
| `lib/features/planner/presentation/widgets/plan_name_dialog.dart` (create) | Reusable name-entry dialog. Owns and disposes its `TextEditingController`. Returns trimmed text or `null`. |
| `lib/features/planner/presentation/pages/plan_canvas_page.dart` (modify) | Uses the dialog for rename, adds the edit affordance to the title, gates first save on the dialog. |
| `lib/features/dive_planner/presentation/providers/dive_planner_providers.dart` (modify) | Exposes `isPersisted` so the page can tell a first save from a re-save. |
| `lib/features/planner/presentation/widgets/saved_plans_sheet.dart` (modify) | Adds Rename to the per-plan overflow menu. |
| `lib/l10n/arb/app_*.arb` (modify, 11 files) | Two new keys. |
| `test/features/planner/plan_name_generator_test.dart` (create) | Unit tests for the generator. |
| `test/features/planner/plan_name_dialog_test.dart` (create) | Widget tests for the dialog contract. |
| `test/features/planner/plan_canvas_first_save_test.dart` (create) | Widget tests for the first-save gate. |
| `test/features/planner/saved_plans_sheet_test.dart` (modify) | Adds a rename test to the existing suite. |

---

### Task 1: Default plan name generator

**Files:**
- Create: `lib/features/planner/domain/services/plan_name_generator.dart`
- Test: `test/features/planner/plan_name_generator_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `String generateDefaultPlanName({String? siteName, String? depthLabel, required DateTime date, required String fallbackLabel})` — used by Task 4.

- [ ] **Step 1: Write the failing test**

Create `test/features/planner/plan_name_generator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/services/plan_name_generator.dart';

void main() {
  final date = DateTime(2026, 7, 25);

  group('generateDefaultPlanName', () {
    test('combines site, depth, and date', () {
      expect(
        generateDefaultPlanName(
          siteName: 'Blue Hole',
          depthLabel: '40m',
          date: date,
          fallbackLabel: 'Dive Plan',
        ),
        'Blue Hole 40m - Jul 25',
      );
    });

    test('omits the depth when no depth label is supplied', () {
      expect(
        generateDefaultPlanName(
          siteName: 'Blue Hole',
          depthLabel: null,
          date: date,
          fallbackLabel: 'Dive Plan',
        ),
        'Blue Hole - Jul 25',
      );
    });

    test('omits the site when no site name is supplied', () {
      expect(
        generateDefaultPlanName(
          siteName: null,
          depthLabel: '40m',
          date: date,
          fallbackLabel: 'Dive Plan',
        ),
        '40m - Jul 25',
      );
    });

    test('falls back to the supplied label when site and depth are absent', () {
      expect(
        generateDefaultPlanName(
          siteName: null,
          depthLabel: null,
          date: date,
          fallbackLabel: 'Dive Plan',
        ),
        'Dive Plan - Jul 25',
      );
    });

    test('treats a blank site name as absent', () {
      expect(
        generateDefaultPlanName(
          siteName: '   ',
          depthLabel: null,
          date: date,
          fallbackLabel: 'Dive Plan',
        ),
        'Dive Plan - Jul 25',
      );
    });

    test('trims surrounding whitespace on the site name', () {
      expect(
        generateDefaultPlanName(
          siteName: '  Blue Hole  ',
          depthLabel: '40m',
          date: date,
          fallbackLabel: 'Dive Plan',
        ),
        'Blue Hole 40m - Jul 25',
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/planner/plan_name_generator_test.dart`

Expected: FAIL at compile time with `Target of URI doesn't exist: 'package:submersion/features/planner/domain/services/plan_name_generator.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/features/planner/domain/services/plan_name_generator.dart`:

```dart
import 'package:intl/intl.dart';

/// Builds the default name offered when a dive plan is saved for the first
/// time.
///
/// Kept free of Flutter and Riverpod so it can be unit tested without a
/// [ProviderContainer]. Unit conversion happens in the caller: [depthLabel] is
/// already formatted in the diver's depth unit (for example `40m` or `130ft`),
/// which means the generated name freezes that unit into the stored string.
/// That is intentional. The name is a user-editable label, so regenerating it
/// after a unit switch would overwrite names the diver typed deliberately.
///
/// [fallbackLabel] is the localized word for a plan (for example `Dive Plan`)
/// and is used only when neither a site nor a depth is available.
String generateDefaultPlanName({
  String? siteName,
  String? depthLabel,
  required DateTime date,
  required String fallbackLabel,
}) {
  final site = siteName?.trim();
  final depth = depthLabel?.trim();

  final parts = <String>[
    if (site != null && site.isNotEmpty) site,
    if (depth != null && depth.isNotEmpty) depth,
  ];
  if (parts.isEmpty) parts.add(fallbackLabel);

  return '${parts.join(' ')} - ${DateFormat.MMMd().format(date)}';
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/planner/plan_name_generator_test.dart`

Expected: PASS, 6 tests.

- [ ] **Step 5: Format and analyze**

Run: `dart format . && flutter analyze`

Expected: `dart format` reports 0 changed files on a second run; `flutter analyze` reports `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add lib/features/planner/domain/services/plan_name_generator.dart test/features/planner/plan_name_generator_test.dart
git commit -m "feat(planner): add default plan name generator"
```

---

### Task 2: Reusable name dialog, and wire the canvas rename to it

**Files:**
- Create: `lib/features/planner/presentation/widgets/plan_name_dialog.dart`
- Modify: `lib/features/planner/presentation/pages/plan_canvas_page.dart` (title `InkWell` at `:106-110`; `_showRenameDialog` at `:717-749`)
- Test: `test/features/planner/plan_name_dialog_test.dart`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `Future<String?> showPlanNameDialog(BuildContext context, {required String initialName, required String title})` — used by Task 4 and Task 5. Returns the trimmed entered name, or `null` when the user cancels or dismisses.

This task also fixes a real leak: the existing `_showRenameDialog` creates a `TextEditingController` inside the `showDialog` builder closure and never disposes it, so every rename leaks one controller. Extracting the dialog into a `StatefulWidget` gives it a `dispose()`.

- [ ] **Step 1: Write the failing test**

Create `test/features/planner/plan_name_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_name_dialog.dart';

import '../../helpers/test_app.dart';

void main() {
  // Opens the dialog from a button and records what it returned.
  Future<void> openDialog(
    WidgetTester tester,
    String initialName,
    void Function(String?) onResult,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final result = await showPlanNameDialog(
                    context,
                    initialName: initialName,
                    title: 'Name your plan',
                  );
                  onResult(result);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('pre-fills the field with the initial name', (tester) async {
    await openDialog(tester, 'Blue Hole 40m - Jul 25', (_) {});

    expect(find.text('Name your plan'), findsOneWidget);
    expect(find.text('Blue Hole 40m - Jul 25'), findsOneWidget);
  });

  testWidgets('cancel returns null', (tester) async {
    String? result;
    var called = false;
    await openDialog(tester, 'Blue Hole', (value) {
      result = value;
      called = true;
    });

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(result, isNull);
  });

  testWidgets('confirm returns the trimmed text', (tester) async {
    String? result;
    await openDialog(tester, 'Blue Hole', (value) => result = value);

    await tester.enterText(find.byType(TextField), '  Wreck of the Zenobia  ');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, 'Wreck of the Zenobia');
  });

  testWidgets('an all-whitespace field disables confirm', (tester) async {
    await openDialog(tester, 'Blue Hole', (_) {});

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();

    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(confirm.onPressed, isNull);
  });

  testWidgets('confirm is enabled again once text is restored', (
    tester,
  ) async {
    await openDialog(tester, 'Blue Hole', (_) {});

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Zenobia');
    await tester.pump();

    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(confirm.onPressed, isNotNull);
  });
}
```

Note: `Cancel` and `Save` are the English values of `common_action_cancel` and `common_action_save`, which is why the harness pins `locale: const Locale('en')`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/planner/plan_name_dialog_test.dart`

Expected: FAIL at compile time with `Target of URI doesn't exist: 'package:submersion/features/planner/presentation/widgets/plan_name_dialog.dart'`.

- [ ] **Step 3: Write the dialog**

Create `lib/features/planner/presentation/widgets/plan_name_dialog.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Prompt for a dive plan name, seeded with [initialName].
///
/// Resolves to the trimmed entered name, or `null` when the diver cancels or
/// dismisses the dialog. Confirm stays disabled while the trimmed field is
/// empty, so an empty name can never be returned.
Future<String?> showPlanNameDialog(
  BuildContext context, {
  required String initialName,
  required String title,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PlanNameDialog(initialName: initialName, title: title),
  );
}

class _PlanNameDialog extends StatefulWidget {
  const _PlanNameDialog({required this.initialName, required this.title});

  final String initialName;
  final String title;

  @override
  State<_PlanNameDialog> createState() => _PlanNameDialogState();
}

class _PlanNameDialogState extends State<_PlanNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: context.l10n.divePlanner_field_planName,
        ),
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _confirm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty ? null : _confirm,
          child: Text(context.l10n.common_action_save),
        ),
      ],
    );
  }

  void _confirm() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/planner/plan_name_dialog_test.dart`

Expected: PASS, 5 tests.

- [ ] **Step 5: Replace the canvas rename dialog**

In `lib/features/planner/presentation/pages/plan_canvas_page.dart`, delete the entire `_showRenameDialog` method (currently at `:717-749`) and replace it with:

```dart
  Future<void> _showRenameDialog(BuildContext context) async {
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    final entered = await showPlanNameDialog(
      context,
      initialName: ref.read(divePlanNotifierProvider).name,
      title: context.l10n.divePlanner_action_renamePlan,
    );
    if (entered == null) return;
    notifier.updateName(entered);
  }
```

Add the import alongside the other `planner/presentation/widgets` imports:

```dart
import 'package:submersion/features/planner/presentation/widgets/plan_name_dialog.dart';
```

- [ ] **Step 6: Add the edit affordance to the title**

In the same file, replace the title `InkWell` (currently at `:106-110`):

```dart
            Flexible(
              child: InkWell(
                onTap: () => _showRenameDialog(context),
                child: Text(planState.name),
              ),
            ),
```

with:

```dart
            Flexible(
              child: InkWell(
                onTap: () => _showRenameDialog(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(planState.name, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
```

The inner `Flexible` on the `Text` is what keeps a long plan name ellipsizing instead of overflowing the AppBar once the icon takes fixed width.

- [ ] **Step 7: Run the existing canvas tests to check for regressions**

Run: `flutter test test/features/planner/plan_canvas_page_test.dart test/features/planner/plan_canvas_delete_test.dart test/features/planner/plan_canvas_delete_gate_test.dart`

Expected: PASS. If a test matched the title with `find.text('New Dive Plan')`, it still passes: the plan name is still rendered by a `Text` widget, now nested one level deeper.

- [ ] **Step 8: Format, analyze, and commit**

```bash
dart format .
flutter analyze
git add lib/features/planner/presentation/widgets/plan_name_dialog.dart lib/features/planner/presentation/pages/plan_canvas_page.dart test/features/planner/plan_name_dialog_test.dart
git commit -m "feat(planner): extract plan name dialog and mark the title editable"
```

Expected: `flutter analyze` reports `No issues found!` before committing.

---

### Task 3: Localization keys

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`, `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`

**Interfaces:**
- Consumes: nothing.
- Produces: `context.l10n.plannerCanvas_name_dialogTitle` and `context.l10n.plannerCanvas_name_defaultFallback` — used by Task 4 and Task 5.

The ARB files are not strictly alphabetically sorted, so insert both keys immediately after the existing `plannerCanvas_saved_title` entry in each file. Neither key takes placeholders, so no `@`-prefixed metadata block is needed.

- [ ] **Step 1: Add the English keys**

In `lib/l10n/arb/app_en.arb`, after the `"plannerCanvas_saved_title"` line (currently `:7115`), add:

```json
  "plannerCanvas_name_dialogTitle": "Name your plan",
  "plannerCanvas_name_defaultFallback": "Dive Plan",
```

- [ ] **Step 2: Add the translated keys**

Insert the matching pair after `"plannerCanvas_saved_title"` in each locale file:

`app_ar.arb`:
```json
  "plannerCanvas_name_dialogTitle": "سمِّ خطتك",
  "plannerCanvas_name_defaultFallback": "خطة غوص",
```

`app_de.arb`:
```json
  "plannerCanvas_name_dialogTitle": "Plan benennen",
  "plannerCanvas_name_defaultFallback": "Tauchplan",
```

`app_es.arb`:
```json
  "plannerCanvas_name_dialogTitle": "Nombra tu plan",
  "plannerCanvas_name_defaultFallback": "Plan de buceo",
```

`app_fr.arb`:
```json
  "plannerCanvas_name_dialogTitle": "Nommez votre plan",
  "plannerCanvas_name_defaultFallback": "Plan de plongée",
```

`app_he.arb`:
```json
  "plannerCanvas_name_dialogTitle": "תן שם לתוכנית",
  "plannerCanvas_name_defaultFallback": "תוכנית צלילה",
```

`app_hu.arb`:
```json
  "plannerCanvas_name_dialogTitle": "Nevezze el a tervet",
  "plannerCanvas_name_defaultFallback": "Merülési terv",
```

`app_it.arb`:
```json
  "plannerCanvas_name_dialogTitle": "Dai un nome al piano",
  "plannerCanvas_name_defaultFallback": "Piano di immersione",
```

`app_nl.arb`:
```json
  "plannerCanvas_name_dialogTitle": "Geef je plan een naam",
  "plannerCanvas_name_defaultFallback": "Duikplan",
```

`app_pt.arb`:
```json
  "plannerCanvas_name_dialogTitle": "Dê um nome ao seu plano",
  "plannerCanvas_name_defaultFallback": "Plano de mergulho",
```

`app_zh.arb`:
```json
  "plannerCanvas_name_dialogTitle": "为计划命名",
  "plannerCanvas_name_defaultFallback": "潜水计划",
```

- [ ] **Step 3: Regenerate the localizations**

Run: `flutter gen-l10n`

Expected: exit 0, and `git status` shows all eleven `lib/l10n/arb/app_localizations*.dart` files modified.

- [ ] **Step 4: Verify the getters exist**

Run: `grep -c "plannerCanvas_name_dialogTitle" lib/l10n/arb/app_localizations_de.dart lib/l10n/arb/app_localizations_zh.dart lib/l10n/arb/app_localizations.dart`

Expected: a non-zero count for each of the three files.

- [ ] **Step 5: Format, analyze, and commit**

```bash
dart format .
flutter analyze
git add lib/l10n/
git commit -m "i18n(planner): add plan name dialog title and fallback label"
```

Expected: `flutter analyze` reports `No issues found!`.

---

### Task 4: First-save name gate

**Files:**
- Modify: `lib/features/dive_planner/presentation/providers/dive_planner_providers.dart` (near `_loaded` at `:55` and `save()` at `:499`)
- Modify: `lib/features/planner/presentation/pages/plan_canvas_page.dart` (`_savePlan` at `:532-547`)
- Test: `test/features/planner/plan_canvas_first_save_test.dart`

**Interfaces:**
- Consumes: `generateDefaultPlanName(...)` from Task 1, `showPlanNameDialog(...)` from Task 2, `plannerCanvas_name_dialogTitle` and `plannerCanvas_name_defaultFallback` from Task 3.
- Produces: `bool get isPersisted` on `DivePlanNotifier`.

- [ ] **Step 1: Write the failing test**

Create `test/features/planner/plan_canvas_first_save_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late DivePlanRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DivePlanRepository();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  Widget harness() => testApp(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    locale: const Locale('en'),
    child: const PlanCanvasPage(),
  );

  Future<void> setSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(PlanCanvasPage)));

  DivePlanNotifier notifierOf(WidgetTester tester) =>
      containerOf(tester).read(divePlanNotifierProvider.notifier);

  // The save IconButton renders Icons.save while the plan is dirty and
  // Icons.save_outlined (disabled) once it is clean, so a tap must always
  // target Icons.save.
  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
  }

  Future<void> seedAndSave(WidgetTester tester) async {
    notifierOf(tester).addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    await tester.pumpAndSettle();
    await tapSave(tester);
  }

  testWidgets('first save opens the name dialog with a generated default', (
    tester,
  ) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(harness());
    await seedAndSave(tester);

    expect(find.text('Name your plan'), findsOneWidget);
    // No site is set on a bare plan, so the name is depth plus date.
    expect(find.textContaining('30.0m - '), findsOneWidget);
  });

  testWidgets('cancelling the first save persists nothing', (tester) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(harness());
    await seedAndSave(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await repository.getAllPlanSummaries(), isEmpty);
    // Read the state through the container: StateNotifier.state is @protected,
    // and reading it directly is an analyzer error that CI treats as fatal.
    expect(containerOf(tester).read(divePlanNotifierProvider).isDirty, isTrue);
  });

  testWidgets('confirming the first save persists under the entered name', (
    tester,
  ) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(harness());
    await seedAndSave(tester);

    await tester.enterText(find.byType(TextField), 'Zenobia');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final summaries = await repository.getAllPlanSummaries();
    expect(summaries, hasLength(1));
    expect(summaries.single.name, 'Zenobia');
  });

  testWidgets('a second save does not re-open the dialog', (tester) async {
    await setSize(tester, const Size(420, 900));
    await tester.pumpWidget(harness());
    await seedAndSave(tester);

    await tester.enterText(find.byType(TextField), 'Zenobia');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // A successful save clears isDirty, which disables the save button. Dirty
    // the plan again so there is something to re-save.
    notifierOf(tester).updateMode(PlanMode.ccr);
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(find.text('Name your plan'), findsNothing);
    final summaries = await repository.getAllPlanSummaries();
    expect(summaries, hasLength(1));
    expect(summaries.single.name, 'Zenobia');
  });
}
```

`PlanMode` comes from `package:submersion/features/planner/domain/entities/dive_plan.dart`;
add that import to the test file.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/planner/plan_canvas_first_save_test.dart`

Expected: FAIL. The first test fails with `Expected: exactly one matching candidate / Actual: _TextFinder:<zero widgets with text "Name your plan">`, because save is still silent.

- [ ] **Step 3: Expose the persisted flag on the notifier**

In `lib/features/dive_planner/presentation/providers/dive_planner_providers.dart`, immediately below the `domain.DivePlan? _loaded;` field declaration at `:55`, add:

```dart
  /// Whether this plan already exists in the database.
  ///
  /// `_loaded` is set by [save] and [loadPlanById] and cleared by [newPlan], so
  /// this is an accurate "has been persisted" signal. The plan canvas uses it
  /// to prompt for a name on the first save only.
  ///
  /// Note that [loadPlan] deliberately does not set `_loaded` and therefore
  /// reports `false`. That method has no production call sites today; a future
  /// production caller must set `_loaded` as [loadPlanById] does.
  bool get isPersisted => _loaded != null;
```

- [ ] **Step 4: Gate the save on the dialog**

In `lib/features/planner/presentation/pages/plan_canvas_page.dart`, replace `_savePlan` (currently at `:532-547`) with:

```dart
  Future<void> _savePlan() async {
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    final outcome = ref.read(planOutcomeProvider);
    final summary = PlanSummaryData(
      maxDepth: outcome.maxDepth,
      runtimeSeconds: outcome.runtimeSeconds,
      ttsSeconds: outcome.ttsAtBottom,
    );

    // Prompt for a name the first time a plan is persisted, so the saved-plans
    // list is not a wall of identically-named rows. Re-saves stay silent.
    if (!notifier.isPersisted) {
      final l10n = context.l10n;
      final state = ref.read(divePlanNotifierProvider);
      final units = UnitFormatter(ref.read(settingsProvider));
      final siteId = state.siteId;
      final site = siteId == null
          ? null
          : await ref.read(siteProvider(siteId).future);
      if (!mounted) return;

      final entered = await showPlanNameDialog(
        context,
        initialName: generateDefaultPlanName(
          siteName: site?.name,
          depthLabel: outcome.maxDepth > 0
              ? units.formatDepth(outcome.maxDepth)
              : null,
          date: state.startDateTime ?? DateTime.now(),
          fallbackLabel: l10n.plannerCanvas_name_defaultFallback,
        ),
        title: l10n.plannerCanvas_name_dialogTitle,
      );
      // Cancel aborts the save entirely: nothing is written and the plan stays
      // dirty, so the diver is never surprised by a name they rejected.
      if (entered == null) return;
      notifier.updateName(entered);
    }

    await notifier.save(summary: summary);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.divePlanner_message_planSaved)),
    );
  }
```

Add these imports if not already present:

```dart
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/planner/domain/services/plan_name_generator.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
```

`_savePlan` is a method rather than part of `build`, so it constructs its own `UnitFormatter` from `ref.read(settingsProvider)` the way `_sharePlanSlate` already does at `:518`, instead of reaching for the `units` local built in `build` at `:86`. `PlanOutcome.maxDepth` is a non-null `double`, so `> 0` is the only guard needed. `context.l10n` and the settings read are captured before the `await` on `siteProvider`, and `mounted` is checked after it, matching the async-gap pattern used by `_confirmAndDeletePlan` in `saved_plans_sheet.dart:293`.

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/planner/plan_canvas_first_save_test.dart`

Expected: PASS, 4 tests.

- [ ] **Step 6: Run the full planner suites for regressions**

Run: `flutter test test/features/planner/ test/features/dive_planner/`

Expected: PASS. `test/features/planner/convert_to_dive_test.dart` in particular must still pass unchanged, because Convert-to-Dive calls `notifier.save()` directly and is deliberately not gated.

- [ ] **Step 7: Format, analyze, and commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_planner/presentation/providers/dive_planner_providers.dart lib/features/planner/presentation/pages/plan_canvas_page.dart test/features/planner/plan_canvas_first_save_test.dart
git commit -m "feat(planner): prompt for a plan name on first save"
```

Expected: `flutter analyze` reports `No issues found!`.

---

### Task 5: Rename from the saved-plans sheet

**Files:**
- Modify: `lib/features/planner/presentation/widgets/saved_plans_sheet.dart` (`_PlanTile` `PopupMenuButton` at `:252-278`)
- Test: `test/features/planner/saved_plans_sheet_test.dart` (append)

**Interfaces:**
- Consumes: `showPlanNameDialog(...)` from Task 2.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write the failing test**

Append this test inside the existing `void main() { ... }` block in `test/features/planner/saved_plans_sheet_test.dart`, after the last existing `testWidgets`:

```dart
  testWidgets('rename from the overflow menu updates the plan name', (
    tester,
  ) async {
    await repository.savePlan(_plan('p1', 'New Dive Plan'));
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename Plan'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Zenobia');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final summaries = await repository.getAllPlanSummaries();
    expect(summaries.single.name, 'Zenobia');
    expect(find.text('Zenobia'), findsOneWidget);
  });
```

Add `locale: const Locale('en')` to the existing `harness()` helper if it is not already pinned, so `Rename Plan` and `Save` resolve to their English values.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/planner/saved_plans_sheet_test.dart --plain-name "rename from the overflow menu"`

Expected: FAIL with `Expected: exactly one matching candidate / Actual: _TextFinder:<zero widgets with text "Rename Plan">`, because the menu only has Duplicate and Share.

- [ ] **Step 3: Add the Rename menu entry**

In `lib/features/planner/presentation/widgets/saved_plans_sheet.dart`, inside `_PlanTile`'s `PopupMenuButton`, add a `rename` branch as the first case in `onSelected` and a matching first `PopupMenuItem`:

```dart
          PopupMenuButton<String>(
            onSelected: (value) async {
              final repository = ref.read(divePlanRepositoryProvider);
              if (value == 'rename') {
                final plan = await repository.getPlan(summary.id);
                if (plan == null || !context.mounted) return;
                final entered = await showPlanNameDialog(
                  context,
                  initialName: plan.name,
                  title: context.l10n.divePlanner_action_renamePlan,
                );
                if (entered == null) return;
                await repository.savePlan(plan.copyWith(name: entered));
              } else if (value == 'duplicate') {
                await repository.duplicatePlan(summary.id);
              } else if (value == 'share') {
                final plan = await repository.getPlan(summary.id);
                if (plan == null) return;
                final safeName = plan.name
                    .replaceAll(RegExp(r'[^\w\s-]'), '')
                    .trim()
                    .replaceAll(RegExp(r'\s+'), '_');
                await saveAndShareFile(
                  planToSubplanJson(plan),
                  '${safeName.isEmpty ? 'dive_plan' : safeName}.$subplanExtension',
                  'application/json',
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'rename',
                child: Text(context.l10n.divePlanner_action_renamePlan),
              ),
              PopupMenuItem(
                value: 'duplicate',
                child: Text(context.l10n.plannerCanvas_saved_duplicate),
              ),
              PopupMenuItem(
                value: 'share',
                child: Text(context.l10n.plannerCanvas_share_menu),
              ),
            ],
          ),
```

Add the import:

```dart
import 'package:submersion/features/planner/presentation/widgets/plan_name_dialog.dart';
```

`repository` is read before the `getPlan` await, matching the existing rule in this file about not using `ref` across an async gap. `savePlan` is called without a `summary`, which leaves `summaryMaxDepth`, `summaryRuntimeSeconds`, and `summaryTtsSeconds` as `Value.absent()` in the companion, so the upsert preserves the existing denormalized values and the tile subtitle keeps its depth and runtime.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/planner/saved_plans_sheet_test.dart`

Expected: PASS, including the pre-existing tests in the file.

- [ ] **Step 5: Format, analyze, and commit**

```bash
dart format .
flutter analyze
git add lib/features/planner/presentation/widgets/saved_plans_sheet.dart test/features/planner/saved_plans_sheet_test.dart
git commit -m "feat(planner): rename a saved plan from the overflow menu"
```

Expected: `flutter analyze` reports `No issues found!`.

---

### Task 6: Full verification

**Files:** none modified.

**Interfaces:**
- Consumes: everything from Tasks 1-5.
- Produces: nothing.

- [ ] **Step 1: Confirm formatting is clean**

Run: `dart format .`

Expected: `Formatted N files (0 changed)`.

- [ ] **Step 2: Confirm analysis is clean**

Run: `flutter analyze`

Expected: `No issues found!`. Do not pipe this command; a pipe masks the exit code.

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`

Expected: all tests pass. If a failure appears in a suite unrelated to the planner, check it against `main` before assuming this branch caused it.

- [ ] **Step 4: Confirm no schema change slipped in**

Run: `git diff main --stat -- lib/core/database/`

Expected: no output. This feature must not touch the database layer.

- [ ] **Step 5: Commit any formatting drift**

```bash
git status --short
```

Expected: clean. If `dart format .` changed files in Step 1, commit them:

```bash
git add -A && git commit -m "style: apply dart format"
```

---

## Self-Review

**Spec coverage:**

| Spec section | Task |
| --- | --- |
| `generateDefaultPlanName` signature and four composition rules | Task 1 |
| Output table (site+depth, site only, depth only, neither) | Task 1, Step 1 |
| Zero/negative depth suppresses the depth segment | Task 1 rule 2, asserted via Task 4's `outcome.maxDepth > 0` guard |
| `startDateTime` preferred over now | Task 4, Step 4 |
| `showPlanNameDialog` signature, null on cancel, empty disables confirm | Task 2 |
| `TextEditingController` leak fix | Task 2, Step 3 |
| `isPersisted` getter and the `loadPlan` caveat | Task 4, Step 3 |
| First-save gate with Cancel aborting | Task 4, Step 4 |
| Async-gap discipline around `siteProvider` | Task 4, Step 4 |
| Canvas title edit affordance with ellipsis preserved | Task 2, Step 6 |
| Saved-plans sheet Rename entry | Task 5 |
| Two new ARB keys across eleven files plus regeneration | Task 3 |
| Convert-to-Dive, import, duplicate, undo-restore stay unprompted | Task 4, Step 6 regression run |
| No migration, no sync change | Task 6, Step 4 |

No spec requirement is unimplemented.

**Placeholder scan:** No TBD, TODO, "add appropriate error handling", or "similar to Task N". Every code step contains complete code. Task 4 Step 1 contains a conditional instruction about the save icon, but it names the exact command to resolve it rather than deferring the decision.

**Type consistency:** `generateDefaultPlanName` is declared in Task 1 with parameters `siteName`, `depthLabel`, `date`, `fallbackLabel` and is called with exactly those names in Task 4. `showPlanNameDialog` is declared in Task 2 with `initialName` and `title` and is called with exactly those names in Tasks 2, 4, and 5. `isPersisted` is declared in Task 4 Step 3 and used in Task 4 Step 4. The l10n getters `plannerCanvas_name_dialogTitle` and `plannerCanvas_name_defaultFallback` are created in Task 3 and consumed in Task 4. `DivePlan.copyWith` used in Task 5 exists at `dive_plan.dart:141`. `PlanSummaryData` and `planOutcomeProvider` are already in scope in `plan_canvas_page.dart`.
