# Naming a Saved Dive Plan

Date: 2026-07-25
Status: Approved, ready for implementation planning

## Problem

Saving a dive plan is silent. The save button persists the plan and shows a
"Plan saved" snackbar; the user is never asked what the plan is called. Every
new plan therefore carries the hardcoded, non-localized default `New Dive Plan`
(`lib/features/dive_planner/presentation/providers/dive_planner_providers.dart:73`
and `lib/features/dive_planner/domain/entities/plan_result.dart:598`). A diver
who saves three plans gets three identical rows in the saved-plans sheet,
distinguishable only by the date/depth subtitle.

Renaming is possible but undiscoverable: the plan canvas AppBar title is an
`InkWell` that opens a rename dialog
(`lib/features/planner/presentation/pages/plan_canvas_page.dart:106-110`,
`:717-749`) with no visual affordance indicating it is tappable.

## Scope

This is a presentation-layer feature only.

`dive_plans.name` already exists as a non-null `text()` column
(`lib/core/database/database.dart:413`) and already carries an `hlc` column
(`:481`). The table is registered in the sync table map
(`lib/core/data/repositories/sync_repository.dart:56`) and flagged HLC-capable
in the sync engine (`lib/core/services/sync/sync_service.dart:1750-1759`).

Consequences:

- No schema migration. The schema version stays where it is.
- No sync work. A rename propagates through the existing last-writer-wins path.
- No repository changes. `savePlan` already maps `name`
  (`lib/features/planner/data/repositories/dive_plan_repository.dart:405`).

The feature has three parts: a name dialog gating first save, a generated
default name pre-filled into that dialog, and discoverable rename entry points.

## Decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| When to prompt | First save only | A never-saved plan is the only case where the name is meaningless. Re-saves stay silent. |
| Default name shape | Site + depth + date | Most informative at a glance. Accepts that the unit is frozen into the stored string. |
| Cancel semantics | Cancel aborts the save | The dialog is a gate, not a courtesy. A user who rejects a name never finds a plan under it. |
| Other save paths | None prompt | Convert-to-Dive, import, duplicate, and undo-restore either already carry meaningful names or should not be interrupted. |
| Name collisions | Allowed | Names are labels, not identifiers. Uniqueness is unenforceable across synced devices. |

### Frozen units

The generated name embeds a unit-formatted depth (`Blue Hole 40m - Jul 25` for a
metric diver, `Blue Hole 130ft - Jul 25` for an imperial one). Because the name
is stored as a literal string, it does not re-render when the diver later
switches unit systems. This is accepted: the name is a user-editable label, and
regenerating it would overwrite names the user typed deliberately.

## Architecture

### New: `lib/features/planner/domain/services/plan_name_generator.dart`

A single pure function with no Flutter or Riverpod dependency, so it is testable
without a `ProviderContainer`:

```dart
String generateDefaultPlanName({
  String? siteName,
  String? depthLabel, // already unit-formatted by the caller
  required DateTime date,
  required String fallbackLabel, // localized "Dive Plan"
});
```

Composition rules:

1. Join the present values of `siteName` and `depthLabel` with a single space,
   then append `" - "` and the date.
2. Omit `depthLabel` when the plan's max depth is null or less than or equal to
   zero. An empty plan must not be named `Blue Hole 0m - Jul 25`.
3. When both `siteName` and `depthLabel` are absent, use `fallbackLabel` in the
   leading slot, yielding `Dive Plan - Jul 25`.
4. Format `date` with `DateFormat.MMMd()` so the result is locale-aware.

Unit formatting stays outside this function. `UnitFormatter` requires
`settingsProvider`, and taking it as a dependency would make the generator
untestable in isolation. The caller formats the depth and passes a string.

Expected outputs:

| Site | Max depth | Result |
| --- | --- | --- |
| Blue Hole | 40 m | `Blue Hole 40m - Jul 25` |
| Blue Hole | null or 0 | `Blue Hole - Jul 25` |
| null | 40 m | `40m - Jul 25` |
| null | null or 0 | `Dive Plan - Jul 25` |

The date source is `planState.startDateTime ?? DateTime.now()`.

### New: `lib/features/planner/presentation/widgets/plan_name_dialog.dart`

```dart
Future<String?> showPlanNameDialog(
  BuildContext context, {
  required String initialName,
  required String title,
});
```

Returns the trimmed entered name, or `null` when the user cancels. The confirm
button is disabled while the trimmed field is empty, so an empty name can never
be committed.

This replaces the inline `_showRenameDialog` at `plan_canvas_page.dart:717`,
which creates a `TextEditingController` inside the builder closure and never
disposes it. The extracted widget is a `StatefulWidget` that disposes its
controller in `dispose()`.

### Changed: `DivePlanNotifier`

Add a getter exposing whether the plan has been persisted in this editing
session:

```dart
bool get isPersisted => _loaded != null;
```

`_loaded` is set by `save()` (`dive_planner_providers.dart:507`) and by
`loadPlanById()` (`:116`), and cleared by `newPlan()` (`:101`). It is therefore
an accurate "this plan exists in the database" signal.

Known gap, deliberately not fixed: `loadPlan(DivePlanState)` (`:106`) sets state
without setting `_loaded`, so a plan loaded through it would report
`isPersisted == false`. That method has no production call sites; it is used
only by `test/features/dive_planner/presentation/providers/dive_planner_providers_test.dart:72`.
If a production caller is ever added, it must set `_loaded`.

The notifier gains no UI dependency. `save()` stays a pure persistence call, so
the four other callers (`_convertToDive`, `.subplan` import, duplicate,
undo-delete restore) are unaffected.

### Changed: `_savePlan()` in `plan_canvas_page.dart`

```
if (!notifier.isPersisted) {
  siteName  = state.siteId == null
      ? null
      : (await ref.read(siteProvider(state.siteId!).future))?.name;
  depthLabel = outcome.maxDepth > 0 ? units.formatDepth(outcome.maxDepth) : null;
  suggested = generateDefaultPlanName(
    siteName: siteName,
    depthLabel: depthLabel,
    date: state.startDateTime ?? DateTime.now(),
    fallbackLabel: l10n.plannerCanvas_name_defaultFallback,
  );
  entered = await showPlanNameDialog(
    context,
    initialName: suggested,
    title: l10n.plannerCanvas_name_dialogTitle,
  );
  if (entered == null) return;  // Cancel: persist nothing, plan stays dirty
  notifier.updateName(entered);
}
await notifier.save(summary: ...);
```

Because `siteProvider` is a `FutureProvider.family`
(`lib/features/dive_sites/presentation/providers/site_providers.dart:273`),
resolving the site name is an `await` that runs before the dialog opens. On a
cold cache this introduces a brief gap between tapping Save and the dialog
appearing. This is accepted rather than mitigated with a loading indicator: the
read is a single indexed row lookup.

The `context` and `ref` reads that cross the `await` must be captured before it,
and `mounted` checked after, following the pattern already used in
`_confirmAndDeletePlan` (`saved_plans_sheet.dart:293`).

`_savePlan` is a method rather than part of `build`, so it constructs its own
`UnitFormatter(ref.read(settingsProvider))` the way `_sharePlanSlate` already
does at `plan_canvas_page.dart:518`, rather than reaching for the `units` local
built in `build` at `:86`. `PlanOutcome.maxDepth` is a non-null `double`
(`plan_result.dart:318`), so the `> 0` guard is the only check needed.

### Changed: canvas title affordance

The existing title `InkWell` (`plan_canvas_page.dart:106-110`) wraps its `Text`
in a `Row` with a trailing `Icon(Icons.edit_outlined, size: 14)` tinted
`colorScheme.onSurfaceVariant`. The `Flexible` stays on the `Text` so long plan
names still ellipsize rather than overflow the AppBar.

### Changed: saved-plans sheet

`_PlanTile` already renders a `PopupMenuButton` with Duplicate and Share
(`saved_plans_sheet.dart:252-278`). Add a `rename` entry as the first item. On
selection it loads the plan through `divePlanRepositoryProvider.getPlan`,
prompts with `showPlanNameDialog` seeded from the current name, and on confirm
writes back via `savePlan(plan.copyWith(name: entered))`.

The repository read must happen before the dialog `await`, matching the existing
comment on `_confirmAndDeletePlan` about not using `ref` across an async gap.

## Localization

Two new keys, added to `lib/l10n/arb/app_en.arb` and translated into all ten
non-English locales, then regenerated:

| Key | English |
| --- | --- |
| `plannerCanvas_name_dialogTitle` | Name your plan |
| `plannerCanvas_name_defaultFallback` | Dive Plan |

Reused without change: `divePlanner_field_planName` ("Plan Name"),
`divePlanner_action_renamePlan` ("Rename Plan"), `common_action_cancel`,
`common_action_save`, `plannerCanvas_saved_duplicate`.

The hardcoded `'New Dive Plan'` at `dive_planner_providers.dart:73` and
`plan_result.dart:598` stays as-is. In the normal flow it is a transient
in-memory placeholder shown on the canvas until the first-save gate replaces it.

It can still reach the database by one route: Convert-to-Dive on a
never-persisted plan calls `save()` directly without prompting, so the plan row
lands as `New Dive Plan`. That is the accepted consequence of the decision not
to interrupt the convert flow with a modal, and it is recoverable through the
saved-plans sheet's Rename entry.

## Testing

Unit tests for `generateDefaultPlanName`:

- All four presence combinations from the output table above.
- Zero and negative max depth suppress the depth segment.
- `startDateTime` is preferred over the current date when present.
- Locale-dependent date formatting produces the expected string for `en`.

Widget tests for `showPlanNameDialog`:

- Cancel returns `null`.
- Confirm returns the trimmed text.
- An all-whitespace field disables the confirm button.

Widget tests for the canvas save flow:

- First save on a never-persisted plan opens the dialog pre-filled with the
  generated name.
- Cancelling that dialog persists nothing and leaves `isDirty` true.
- Confirming persists under the entered name.
- A second save on the same plan does not open the dialog.

Widget test for the saved-plans sheet:

- The overflow menu exposes Rename, and confirming it updates the tile title.

## Out of scope

- Renaming from the planning page's recent-plans tiles
  (`lib/features/planning/presentation/pages/planning_page.dart:117-134`). Those
  are a read-only preview; the saved-plans sheet is the management surface.
- Regenerating stored names when the diver switches unit systems.
- Any uniqueness constraint or auto-numbering of names.
