# Delete a Dive Plan from the Plan Canvas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a discoverable "Delete plan" action to the open plan canvas that confirms, deletes the persisted plan, navigates back to the planning hub, and offers an undo.

**Architecture:** Purely additive UI wiring in `PlanCanvasPage` over existing repository primitives (`getPlan`, `deletePlan`, `savePlan`). A tiny pure helper gates visibility on whether the current plan is persisted. Undo is implemented by capturing the plan before deletion and re-saving it. No schema change, no migration, no new table, no repository method.

**Tech Stack:** Flutter, Riverpod (StateNotifierProvider + FutureProvider), Drift, go_router, Flutter gen-l10n (ARB files).

## Global Constraints

- No emojis in code, comments, or documentation.
- `dart format .` must produce no changes before each commit.
- `flutter analyze` must be clean: **info-level lints fail CI**, treat them as errors.
- l10n: any new user-facing string must be added to **all 11** ARB files in `lib/l10n/arb/` (`app_en.arb` plus `ar, de, es, fr, he, hu, it, nl, pt, zh`), then regenerated with `flutter gen-l10n`. Placeholder metadata (`@key` block) lives **only** in the `app_en.arb` template.
- Deletion UX must follow the app's house convention: confirm dialog, then undo affordance. Reuse existing keys `common_action_cancel` ("Cancel") and `common_action_delete` ("Delete") for dialog buttons.
- "Delete plan" must be visible **only when the current plan is persisted** (its id is in `divePlanSummariesProvider`), falling back to `widget.planId != null` when summaries have not loaded.
- Deleting must navigate away from the `/planning/dive-planner/:planId` route (to `/planning`) so the editor is never left on a dead route.

---

### Task 1: Add localization strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (template + placeholder metadata)
- Modify: `lib/l10n/arb/app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`
- Generated (do not hand-edit): `lib/l10n/gen/` output from `flutter gen-l10n`

**Interfaces:**
- Produces: four new `context.l10n` getters consumed by Task 2 and Task 3:
  - `divePlanner_action_deletePlan` → `String`
  - `divePlanner_message_deleteConfirmation(String name)` → `String`
  - `divePlanner_message_planDeleted` → `String`
  - `divePlanner_undo` → `String`

- [ ] **Step 1: Add the four keys to `app_en.arb`**

Insert these entries (place them alphabetically near the other `divePlanner_` keys; the `@` block must immediately follow its key):

```json
  "divePlanner_action_deletePlan": "Delete plan",
  "divePlanner_message_deleteConfirmation": "Delete '{name}'?",
  "@divePlanner_message_deleteConfirmation": {
    "placeholders": {
      "name": { "type": "String" }
    }
  },
  "divePlanner_message_planDeleted": "Plan deleted",
  "divePlanner_undo": "Undo",
```

- [ ] **Step 2: Add the same four keys (translated) to each non-en ARB file**

Do **not** copy the `@divePlanner_message_deleteConfirmation` metadata block into non-en files (gen-l10n reads placeholders from the template only). Keep the `{name}` token verbatim inside the translated string. Values per locale:

| file | deletePlan | deleteConfirmation | planDeleted | undo |
| --- | --- | --- | --- | --- |
| `app_ar.arb` | `حذف الخطة` | `حذف '{name}'؟` | `تم حذف الخطة` | `تراجع` |
| `app_de.arb` | `Plan löschen` | `'{name}' löschen?` | `Plan gelöscht` | `Rückgängig` |
| `app_es.arb` | `Eliminar plan` | `¿Eliminar '{name}'?` | `Plan eliminado` | `Deshacer` |
| `app_fr.arb` | `Supprimer le plan` | `Supprimer '{name}' ?` | `Plan supprimé` | `Annuler` |
| `app_he.arb` | `מחק תוכנית` | `למחוק את '{name}'?` | `התוכנית נמחקה` | `בטל` |
| `app_hu.arb` | `Terv törlése` | `Törli a(z) '{name}' tervet?` | `Terv törölve` | `Visszavonás` |
| `app_it.arb` | `Elimina piano` | `Eliminare '{name}'?` | `Piano eliminato` | `Annulla` |
| `app_nl.arb` | `Plan verwijderen` | `'{name}' verwijderen?` | `Plan verwijderd` | `Ongedaan maken` |
| `app_pt.arb` | `Excluir plano` | `Excluir '{name}'?` | `Plano excluído` | `Desfazer` |
| `app_zh.arb` | `删除计划` | `删除 '{name}'？` | `计划已删除` | `撤销` |

For each non-en file, add lines of the form (example for `app_de.arb`):

```json
  "divePlanner_action_deletePlan": "Plan löschen",
  "divePlanner_message_deleteConfirmation": "'{name}' löschen?",
  "divePlanner_message_planDeleted": "Plan gelöscht",
  "divePlanner_undo": "Rückgängig",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: exits 0, no errors. The generated getters now exist.

- [ ] **Step 4: Verify the getters resolve and analysis is clean**

Run: `flutter analyze lib/l10n`
Expected: "No issues found!" (or no new issues). Confirms ARB syntax and the placeholder method signature are valid.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/l10n
git add lib/l10n
git commit -m "feat(planner): add l10n strings for delete-plan action"
```

---

### Task 2: Persisted-gate helper and conditional menu item

**Files:**
- Modify: `lib/features/planner/presentation/pages/plan_canvas_page.dart`
- Test: `test/features/planner/plan_canvas_delete_gate_test.dart` (create)

**Interfaces:**
- Consumes: `domain.DivePlanSummary` (has `String id`); `divePlanSummariesProvider` (`FutureProvider<List<domain.DivePlanSummary>>`); `DivePlanState.id` (`String`, via `ref.watch(divePlanNotifierProvider).id`).
- Produces: top-level `bool planIsPersisted(String id, List<domain.DivePlanSummary> summaries)` consumed by the canvas build and by Task 3's widget test indirectly.

- [ ] **Step 1: Write the failing unit test**

Create `test/features/planner/plan_canvas_delete_gate_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';

DivePlanSummary _summary(String id) =>
    DivePlanSummary(id: id, name: 'plan $id', updatedAt: DateTime(2026, 7, 22));

void main() {
  test('planIsPersisted is true when the id is in the summaries', () {
    final summaries = [_summary('a'), _summary('b')];
    expect(planIsPersisted('a', summaries), isTrue);
  });

  test('planIsPersisted is false when the id is absent', () {
    final summaries = [_summary('a')];
    expect(planIsPersisted('z', summaries), isFalse);
  });

  test('planIsPersisted is false for an empty list', () {
    expect(planIsPersisted('a', const []), isFalse);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/planner/plan_canvas_delete_gate_test.dart`
Expected: FAIL — `planIsPersisted` is not defined.

- [ ] **Step 3: Add the helper to `plan_canvas_page.dart`**

Add `import 'package:flutter/foundation.dart';` if not already present (for `@visibleForTesting`), and add this top-level function just above `class PlanCanvasPage`:

```dart
/// Whether [id] refers to a plan that already exists in the store. Drives the
/// visibility of the destructive "Delete plan" action: a brand-new, never-saved
/// plan has nothing to delete (Reset covers clearing it).
@visibleForTesting
bool planIsPersisted(String id, List<domain.DivePlanSummary> summaries) =>
    summaries.any((s) => s.id == id);
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/planner/plan_canvas_delete_gate_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Render the conditional "Delete plan" menu item**

In `plan_canvas_page.dart`, add the summaries watch inside `build` (near the existing `planState`/`units` reads, around line 77):

```dart
    final summaries =
        ref.watch(divePlanSummariesProvider).valueOrNull ??
        const <domain.DivePlanSummary>[];
    final canDelete =
        planIsPersisted(planState.id, summaries) || widget.planId != null;
```

Add the import for the summaries provider at the top of the file:

```dart
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
```

Add a `_deleteMenuItem` builder next to `_menuItem` (around line 201):

```dart
  PopupMenuItem<String> _deleteMenuItem(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return PopupMenuItem(
      value: 'delete',
      child: ListTile(
        leading: Icon(Icons.delete_outline, color: error),
        title: Text(
          context.l10n.divePlanner_action_deletePlan,
          style: TextStyle(color: error),
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
```

Append the item to the overflow menu `itemBuilder` list, after the existing `'reset'` `_menuItem(...)` entry (around line 170), so it renders last:

```dart
              _menuItem(
                'reset',
                Icons.refresh,
                context.l10n.divePlanner_action_resetPlan,
              ),
              if (canDelete) _deleteMenuItem(context),
```

- [ ] **Step 6: Verify format, analysis, and the gate test**

```bash
dart format lib/features/planner/presentation/pages/plan_canvas_page.dart test/features/planner/plan_canvas_delete_gate_test.dart
flutter analyze lib/features/planner/presentation/pages/plan_canvas_page.dart
flutter test test/features/planner/plan_canvas_delete_gate_test.dart
```
Expected: no format changes, "No issues found!", 3 tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/features/planner/presentation/pages/plan_canvas_page.dart test/features/planner/plan_canvas_delete_gate_test.dart
git commit -m "feat(planner): show a persisted-gated Delete plan menu item in the canvas"
```

---

### Task 3: Delete handler with confirm, navigate, and undo

**Files:**
- Modify: `lib/features/planner/presentation/pages/plan_canvas_page.dart`
- Test: `test/features/planner/plan_canvas_delete_test.dart` (create)

**Interfaces:**
- Consumes: `planIsPersisted` and the conditional menu item from Task 2; `divePlanRepositoryProvider` → `DivePlanRepository` with `Future<domain.DivePlan?> getPlan(String id)`, `Future<void> deletePlan(String id)`, `Future<void> savePlan(domain.DivePlan plan, {PlanSummaryData? summary})`; `planOutcomeProvider` (fields `maxDepth`, `runtimeSeconds`, `ttsAtBottom`); `PlanSummaryData({required double maxDepth, required int runtimeSeconds, int? ttsSeconds})`.
- Produces: `_deletePlan()` handler wired to `_onMenu`'s `case 'delete'`.

- [ ] **Step 1: Write the failing widget tests**

Create `test/features/planner/plan_canvas_delete_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

DivePlan _plan(String id, String name) => DivePlan(
  id: id,
  name: name,
  gfLow: 50,
  gfHigh: 80,
  createdAt: DateTime(2026, 7, 5),
  updatedAt: DateTime(2026, 7, 5),
);

void main() {
  late DivePlanRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DivePlanRepository();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  // Router harness: canvas at the plan route, a stub /planning to land on.
  Widget harness(String path) => testAppRouter(
    overrides: const [],
    router: GoRouter(
      initialLocation: path,
      routes: [
        GoRoute(
          path: '/planning',
          builder: (_, _) => const Scaffold(body: Text('planning-hub')),
        ),
        GoRoute(
          path: '/planning/dive-planner',
          builder: (_, _) => const PlanCanvasPage(),
        ),
        GoRoute(
          path: '/planning/dive-planner/:planId',
          builder: (_, state) =>
              PlanCanvasPage(planId: state.pathParameters['planId']),
        ),
      ],
    ),
  );

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }

  testWidgets('delete removes the plan and navigates to the hub', (
    tester,
  ) async {
    await repository.savePlan(_plan('a', 'Reef dive'));

    await tester.pumpWidget(harness('/planning/dive-planner/a'));
    await tester.pumpAndSettle();

    await openMenu(tester);
    expect(find.text('Delete plan'), findsOneWidget);
    await tester.tap(find.text('Delete plan'));
    await tester.pumpAndSettle();

    // Confirmation dialog names the plan.
    expect(find.text("Delete 'Reef dive'?"), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await repository.getAllPlanSummaries(), isEmpty);
    expect(find.text('planning-hub'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('undo restores the deleted plan', (tester) async {
    await repository.savePlan(_plan('a', 'Reef dive'));

    await tester.pumpWidget(harness('/planning/dive-planner/a'));
    await tester.pumpAndSettle();

    await openMenu(tester);
    await tester.tap(find.text('Delete plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await repository.getAllPlanSummaries(), isEmpty);

    await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
    await tester.pumpAndSettle();

    final restored = await repository.getAllPlanSummaries();
    expect(restored, hasLength(1));
    expect(restored.single.name, 'Reef dive');
  });

  testWidgets('cancel keeps the plan', (tester) async {
    await repository.savePlan(_plan('a', 'Reef dive'));

    await tester.pumpWidget(harness('/planning/dive-planner/a'));
    await tester.pumpAndSettle();

    await openMenu(tester);
    await tester.tap(find.text('Delete plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(await repository.getAllPlanSummaries(), hasLength(1));
  });

  testWidgets('delete is hidden for a brand-new unsaved plan', (tester) async {
    await tester.pumpWidget(harness('/planning/dive-planner'));
    await tester.pumpAndSettle();

    await openMenu(tester);
    expect(find.text('Delete plan'), findsNothing);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/planner/plan_canvas_delete_test.dart`
Expected: FAIL — tapping "Delete plan" does nothing (no `case 'delete'`), so the confirmation dialog never appears.

- [ ] **Step 3: Add the `_deletePlan` handler**

In `plan_canvas_page.dart`, add the `case 'delete'` to the `_onMenu` switch (around line 222, after `case 'reset'`):

```dart
      case 'reset':
        _resetPlan();
      case 'delete':
        _deletePlan();
```

Add the handler method (place it next to `_resetPlan`, around line 577). It captures everything it needs into locals **before** navigating, because the page is disposed once `context.go` runs:

```dart
  Future<void> _deletePlan() async {
    final planId = ref.read(divePlanNotifierProvider).id;
    final name = ref.read(divePlanNotifierProvider).name;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.divePlanner_action_deletePlan),
        content: Text(context.l10n.divePlanner_message_deleteConfirmation(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.common_action_cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repository = ref.read(divePlanRepositoryProvider);
    final outcome = ref.read(planOutcomeProvider);

    // Capture the full plan before deleting so undo can re-save it verbatim.
    final captured = await repository.getPlan(planId);
    if (captured == null || !mounted) return;
    final capturedSummary = PlanSummaryData(
      maxDepth: outcome.maxDepth,
      runtimeSeconds: outcome.runtimeSeconds,
      ttsSeconds: outcome.ttsAtBottom,
    );

    await repository.deletePlan(planId);
    if (!mounted) return;

    // Capture messenger + strings before navigating; this page is about to be
    // disposed and its context becomes defunct.
    final messenger = ScaffoldMessenger.of(context);
    final deletedLabel = context.l10n.divePlanner_message_planDeleted;
    final undoLabel = context.l10n.divePlanner_undo;
    context.go('/planning');
    messenger.showSnackBar(
      SnackBar(
        content: Text(deletedLabel),
        action: SnackBarAction(
          label: undoLabel,
          onPressed: () =>
              repository.savePlan(captured, summary: capturedSummary),
        ),
      ),
    );
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/planner/plan_canvas_delete_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Verify format and analysis**

```bash
dart format lib/features/planner/presentation/pages/plan_canvas_page.dart test/features/planner/plan_canvas_delete_test.dart
flutter analyze lib/features/planner/presentation/pages/plan_canvas_page.dart test/features/planner/plan_canvas_delete_test.dart
```
Expected: no format changes, "No issues found!".

- [ ] **Step 6: Run the whole planner test folder for regressions**

Run: `flutter test test/features/planner/`
Expected: all pass (no regression in `plan_canvas_page_test.dart` or `saved_plans_sheet_test.dart`).

- [ ] **Step 7: Commit**

```bash
git add lib/features/planner/presentation/pages/plan_canvas_page.dart test/features/planner/plan_canvas_delete_test.dart
git commit -m "feat(planner): delete the open plan from the canvas with confirm and undo"
```

---

## Self-Review

**Spec coverage:**
- Affordance in `⋮` menu, last, destructive styling → Task 2 Step 5 (`_deleteMenuItem`, error color, appended after Reset).
- Visible only when persisted, fallback to `widget.planId != null` → Task 2 Steps 3, 5.
- Confirm dialog naming the plan → Task 3 Step 3 (`divePlanner_message_deleteConfirmation(name)`).
- Capture → delete → navigate to `/planning` → Task 3 Step 3.
- Undo SnackBar via re-save, messenger captured pre-navigation → Task 3 Step 3.
- Sync tombstones handled by existing `deletePlan`; undo `savePlan` writes newer HLC — no code needed → covered by reuse, asserted by "undo restores" test.
- l10n across all 11 locales + regen → Task 1.
- Testing (visibility, confirm gate, delete+navigate, restore) → Task 2 Step 1, Task 3 Step 1.

**Placeholder scan:** No TBD/TODO/"handle edge cases"; every code step shows full code; the null-plan and unmounted edge cases are handled explicitly in `_deletePlan`.

**Type consistency:** `planIsPersisted(String, List<domain.DivePlanSummary>)` defined in Task 2, used identically in Task 2 Step 5. `PlanSummaryData(maxDepth, runtimeSeconds, ttsSeconds)` and `planOutcomeProvider` fields (`maxDepth`, `runtimeSeconds`, `ttsAtBottom`) match the existing `_savePlan` usage. `getPlan`/`deletePlan`/`savePlan` signatures match `DivePlanRepository`. `DivePlanState.id`/`.name` confirmed present.

**Out of scope (per spec):** `/planning` hub tiles and the saved-plans sheet are intentionally untouched.
