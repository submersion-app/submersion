# Equipment Service Clock Unification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make service clocks the single source of truth for "service due" across the equipment UI, and fix the add-timer flow so a newly attached clock is always visible and configurable.

**Architecture:** The `ServiceDueEngine` and clock data model already exist and power the dashboard. This work re-points every remaining legacy `EquipmentItem.isServiceDue` read (edit form, detail header, list badges, pre-dive) at the clock engine, adds a clock-based service-due sort/column alongside the record-driven "Last service", surfaces unconfigured clocks in the detail card, and reconciles a migration edge case. The legacy DB columns are frozen (kept for export/import) not removed.

**Tech Stack:** Flutter, Riverpod, Drift ORM, go_router, flutter_test, Drift migration tests.

## Global Constraints

- Dart formatting: run `dart format .` before every commit; CI fails on any diff.
- Static analysis: `flutter analyze` must be clean over the whole project; info-level lints (e.g. `prefer_const`) fail CI.
- Localization: any new user-facing string is added to all 11 arb files (`en` is the template; also `ar de es fr he hu it nl pt zh`) and regenerated with `flutter gen-l10n`.
- No emojis in code, comments, or docs.
- Schema version: current `currentSchemaVersion` is 130; this plan bumps it to 131.
- Immutability: never mutate entities; use `copyWith`.
- Tests are written first (TDD) and must fail before implementation.

---

## File Structure

Production files touched:

- `lib/features/equipment/presentation/widgets/service_schedule_dialogs.dart` — override dialog accepts schedule+kind; picker opens dialog for no-default kinds.
- `lib/features/equipment/presentation/widgets/service_clocks_card.dart` — render unconfigured clocks.
- `lib/features/equipment/presentation/pages/equipment_detail_page.dart` — clock-derived header; remove "Mark as serviced".
- `lib/features/equipment/presentation/widgets/equipment_list_content.dart` — drop legacy badge fallback; pass clocks to sort + table adapter.
- `lib/features/equipment/presentation/widgets/dense_equipment_list_tile.dart` — drop legacy badge fallback.
- `lib/features/pre_dive/domain/services/session_item_composer.dart` — take `overdueEquipmentIds`.
- `lib/features/pre_dive/presentation/widgets/start_session_sheet.dart` — compute + pass overdue ids.
- `lib/features/equipment/presentation/pages/equipment_edit_page.dart` — remove Service Settings section.
- `lib/core/constants/sort_options.dart` — add `EquipmentSortField.serviceDue`.
- `lib/features/equipment/presentation/providers/equipment_providers.dart` — add `equipmentServiceUrgencyProvider`; `applyEquipmentSorting` clock arg.
- `lib/features/equipment/domain/constants/equipment_field.dart` — adapter carries clock map; redirect service-forecast fields.
- `lib/core/database/database.dart` — v131 reconciliation migration.
- `lib/l10n/arb/app_*.arb` (11 files) — `equipment_serviceClocks_unconfigured`.

---

## Task 1: Generalize the schedule override dialog to accept schedule + kind

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/service_schedule_dialogs.dart`
- Modify: `lib/features/equipment/presentation/widgets/service_clocks_card.dart` (the one existing caller, in `_onAction`)
- Test: `test/features/equipment/presentation/widgets/service_schedule_override_dialog_test.dart` (create)

**Interfaces:**
- Produces: `Future<void> showScheduleOverrideDialog(BuildContext context, WidgetRef ref, {required ServiceSchedule schedule, required ServiceKind kind})`

- [ ] **Step 1: Write the failing test**

Create `test/features/equipment/presentation/widgets/service_schedule_override_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_schedule_dialogs.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final t0 = DateTime(2025, 1, 1);

  testWidgets('override dialog opens for a bare schedule + kind', (tester) async {
    final schedule = ServiceSchedule(
      id: 'sch1',
      equipmentId: 'e1',
      serviceKindId: 'general-service',
      createdAt: t0,
      updatedAt: t0,
    );
    final kind = ServiceKind(
      id: 'general-service',
      name: 'General service',
      createdAt: t0,
      updatedAt: t0,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showScheduleOverrideDialog(
                    context,
                    ref,
                    schedule: schedule,
                    kind: kind,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Dialog title includes the kind name.
    expect(find.textContaining('General service'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/equipment/presentation/widgets/service_schedule_override_dialog_test.dart`
Expected: FAIL — `showScheduleOverrideDialog` still requires `status:` (compile error / named-param mismatch).

- [ ] **Step 3: Change the dialog signature to schedule + kind**

In `service_schedule_dialogs.dart`, replace `showScheduleOverrideDialog` and `_ScheduleOverrideDialog` field wiring. Change the public function:

```dart
/// Edits one schedule's interval overrides and baseline date. Accepts the
/// schedule and its kind directly so it serves brand-new and unconfigured
/// clocks as well as existing ones.
Future<void> showScheduleOverrideDialog(
  BuildContext context,
  WidgetRef ref, {
  required ServiceSchedule schedule,
  required ServiceKind kind,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) =>
        _ScheduleOverrideDialog(schedule: schedule, kind: kind, ref: ref),
  );
}
```

Change `_ScheduleOverrideDialog` to hold `schedule` + `kind` instead of `status`:

```dart
class _ScheduleOverrideDialog extends StatefulWidget {
  final ServiceSchedule schedule;
  final ServiceKind kind;
  final WidgetRef ref;

  const _ScheduleOverrideDialog({
    required this.schedule,
    required this.kind,
    required this.ref,
  });

  @override
  State<_ScheduleOverrideDialog> createState() =>
      _ScheduleOverrideDialogState();
}
```

In `_ScheduleOverrideDialogState`, replace every `widget.status.schedule` with `widget.schedule` and every `widget.status.kind` with `widget.kind`. Specifically:
- `initState`: `final s = widget.schedule;`
- `build`: `final kind = widget.kind;`
- Save button: `final schedule = widget.schedule;`

- [ ] **Step 4: Update the existing caller in the clocks card**

In `service_clocks_card.dart` `_onAction`, change the `'edit'` case:

```dart
      case 'edit':
        await showScheduleOverrideDialog(
          context,
          ref,
          schedule: status.schedule,
          kind: status.kind,
        );
```

- [ ] **Step 5: Run tests + analyze**

Run: `flutter test test/features/equipment/presentation/widgets/service_schedule_override_dialog_test.dart`
Expected: PASS
Run: `flutter analyze lib/features/equipment/presentation/widgets/service_schedule_dialogs.dart lib/features/equipment/presentation/widgets/service_clocks_card.dart`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/equipment/presentation/widgets/service_schedule_dialogs.dart lib/features/equipment/presentation/widgets/service_clocks_card.dart test/features/equipment/presentation/widgets/service_schedule_override_dialog_test.dart
git commit -m "refactor(equipment): schedule override dialog takes schedule + kind"
```

---

## Task 2: Surface unconfigured clocks in the service clocks card

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/service_clocks_card.dart`
- Modify: `lib/l10n/arb/app_en.arb` (+ 10 other locales)
- Test: `test/features/equipment/presentation/widgets/service_clocks_card_unconfigured_test.dart` (create)

**Interfaces:**
- Consumes: `showScheduleOverrideDialog(..., schedule:, kind:)` from Task 1.
- Consumes l10n key `equipment_serviceClocks_unconfigured`.

- [ ] **Step 1: Add the l10n key to the English template**

In `lib/l10n/arb/app_en.arb`, next to the other `equipment_serviceClocks_*` keys, add:

```json
  "equipment_serviceClocks_unconfigured": "No interval set - tap to configure",
  "@equipment_serviceClocks_unconfigured": {
    "description": "Subtitle for a service clock that is enabled but has no interval yet"
  },
```

- [ ] **Step 2: Mirror the key into the other 10 locales**

Add the same key to `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb` with a translated value (translate "No interval set - tap to configure" appropriately per locale; keep the leading key name identical). Then regenerate:

Run: `flutter gen-l10n`
Expected: `lib/l10n/arb/app_localizations*.dart` regenerated with the new getter.

- [ ] **Step 3: Write the failing widget test**

Create `test/features/equipment/presentation/widgets/service_clocks_card_unconfigured_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_clocks_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final t0 = DateTime(2025, 1, 1);

  testWidgets('an enabled interval-less schedule shows a configure row', (
    tester,
  ) async {
    final schedule = ServiceSchedule(
      id: 'sch1',
      equipmentId: 'e1',
      serviceKindId: 'general-service',
      createdAt: t0,
      updatedAt: t0,
    );
    final kind = ServiceKind(
      id: 'general-service',
      name: 'General service',
      isBuiltIn: true,
      createdAt: t0,
      updatedAt: t0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // No evaluated statuses (interval-less => engine emits nothing).
          serviceClockStatusesProvider('e1').overrideWith((ref) async => const []),
          serviceSchedulesForEquipmentProvider('e1')
              .overrideWith((ref) async => [schedule]),
          serviceKindsProvider.overrideWith((ref) async => [kind]),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: ServiceClocksCard(
              equipmentId: 'e1',
              equipmentType: EquipmentType.mask,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('General service'), findsOneWidget);
    expect(find.text('No interval set - tap to configure'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/features/equipment/presentation/widgets/service_clocks_card_unconfigured_test.dart`
Expected: FAIL — the configure row text is not found (schedule is invisible today).

- [ ] **Step 5: Render unconfigured clocks in the card**

In `service_clocks_card.dart`, inside the `data: (statuses)` builder, after computing `paused` and `kindsById`, compute the unconfigured set and render it. Replace the empty-state guard and the returned `Column` so it also lists unconfigured schedules:

```dart
              data: (statuses) {
                final schedules = schedulesAsync.value ?? const [];
                final paused = schedules.where((s) => !s.enabled).toList();
                final kindsById = {
                  for (final k in kindsAsync.value ?? []) k.id: k,
                };
                // Enabled schedules the engine emitted no status for have no
                // effective interval (no override, no kind default). They are
                // invisible otherwise; surface them so the user can configure.
                final evaluatedIds = {for (final s in statuses) s.schedule.id};
                final unconfigured = schedules
                    .where((s) => s.enabled && !evaluatedIds.contains(s.id))
                    .toList();

                if (statuses.isEmpty && paused.isEmpty && unconfigured.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.equipment_serviceClocks_empty,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final status in statuses)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.circle,
                          size: 14,
                          color: _dotColor(context, status.severity),
                        ),
                        title: Text(status.kind.name),
                        subtitle: Text(_triggerText(context, status)),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) =>
                              _onAction(context, ref, action, status),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'log',
                              child: Text(
                                l10n.equipment_serviceClocks_logService,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'edit',
                              child: Text(l10n.equipment_serviceClocks_edit),
                            ),
                            PopupMenuItem(
                              value: 'pause',
                              child: Text(l10n.equipment_serviceClocks_pause),
                            ),
                            PopupMenuItem(
                              value: 'remove',
                              child: Text(l10n.equipment_serviceClocks_remove),
                            ),
                          ],
                        ),
                      ),
                    for (final schedule in unconfigured)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.circle_outlined,
                          size: 14,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        title: Text(
                          kindsById[schedule.serviceKindId]?.name ??
                              schedule.serviceKindId,
                        ),
                        subtitle: Text(
                          l10n.equipment_serviceClocks_unconfigured,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final kind = kindsById[schedule.serviceKindId];
                          if (kind == null) return;
                          await showScheduleOverrideDialog(
                            context,
                            ref,
                            schedule: schedule,
                            kind: kind,
                          );
                          invalidateServiceClockProviders(ref, equipmentId);
                        },
                      ),
                    for (final schedule in paused)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.pause_circle_outline,
                          size: 18,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        title: Text(
                          (kindsById[schedule.serviceKindId]?.name ??
                              schedule.serviceKindId),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        subtitle: Text(l10n.equipment_serviceClocks_paused),
                        trailing: TextButton(
                          onPressed: () async {
                            await ref
                                .read(serviceScheduleRepositoryProvider)
                                .updateSchedule(
                                  schedule.copyWith(enabled: true),
                                );
                            invalidateServiceClockProviders(ref, equipmentId);
                          },
                          child: Text(l10n.equipment_serviceClocks_resume),
                        ),
                      ),
                  ],
                );
              },
```

Note: this replaces the previous `paused`/`kindsById` locals defined earlier in the builder — remove the old duplicate declarations so they are declared once as above.

- [ ] **Step 6: Run test + analyze**

Run: `flutter test test/features/equipment/presentation/widgets/service_clocks_card_unconfigured_test.dart`
Expected: PASS
Run: `flutter analyze lib/features/equipment/presentation/widgets/service_clocks_card.dart`
Expected: No issues.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/equipment/presentation/widgets/service_clocks_card.dart lib/l10n test/features/equipment/presentation/widgets/service_clocks_card_unconfigured_test.dart
git commit -m "fix(equipment): show enabled but unconfigured service clocks"
```

---

## Task 3: Add-picker opens the interval dialog for kinds with no default

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/service_schedule_dialogs.dart` (`showServiceKindPicker`)
- Test: `test/features/equipment/presentation/widgets/service_kind_picker_test.dart` (create)

**Interfaces:**
- Consumes: `showScheduleOverrideDialog(..., schedule:, kind:)`, `ServiceScheduleRepository.createSchedule`.

- [ ] **Step 1: Write the failing test**

Create `test/features/equipment/presentation/widgets/service_kind_picker_test.dart`. Override `serviceKindsProvider` and `serviceSchedulesForEquipmentProvider`, and `serviceScheduleRepositoryProvider` with a fake repository that records `createSchedule` calls and returns the schedule. Assert that tapping a no-default kind opens the override dialog (title contains the kind name), and tapping a default-bearing kind does not.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_schedule_dialogs.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeScheduleRepo extends ServiceScheduleRepository {
  final created = <ServiceSchedule>[];
  @override
  Future<ServiceSchedule> createSchedule(ServiceSchedule schedule) async {
    final withId = schedule.copyWith(id: 'new-${created.length}');
    created.add(withId);
    return withId;
  }
}

void main() {
  final t0 = DateTime(2025, 1, 1);
  final noDefault = ServiceKind(
    id: 'general-service',
    name: 'General service',
    isBuiltIn: true,
    createdAt: t0,
    updatedAt: t0,
  );
  final withDefault = ServiceKind(
    id: 'regulator-service',
    name: 'Regulator service',
    applicableTypes: const [EquipmentType.regulator],
    defaultIntervalDays: 365,
    isBuiltIn: true,
    createdAt: t0,
    updatedAt: t0,
  );

  Future<void> pumpPicker(WidgetTester tester, _FakeScheduleRepo repo) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceKindsProvider.overrideWith((ref) async => [noDefault, withDefault]),
          serviceSchedulesForEquipmentProvider('e1')
              .overrideWith((ref) async => const []),
          serviceScheduleRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showServiceKindPicker(
                    context,
                    ref,
                    equipmentId: 'e1',
                    equipmentType: EquipmentType.regulator,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('no-default kind opens the interval dialog after create', (
    tester,
  ) async {
    final repo = _FakeScheduleRepo();
    await pumpPicker(tester, repo);
    await tester.tap(find.text('General service'));
    await tester.pumpAndSettle();
    expect(repo.created, hasLength(1));
    // Override dialog title includes the kind name.
    expect(find.textContaining('General service'), findsWidgets);
    // The interval-days field from the override dialog is present.
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('default-bearing kind is one-tap (no dialog)', (tester) async {
    final repo = _FakeScheduleRepo();
    await pumpPicker(tester, repo);
    await tester.tap(find.text('Regulator service'));
    await tester.pumpAndSettle();
    expect(repo.created, hasLength(1));
    // No override dialog: no TextField on screen.
    expect(find.byType(TextField), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/equipment/presentation/widgets/service_kind_picker_test.dart`
Expected: FAIL — `no-default kind opens the interval dialog` fails (no dialog opens today).

- [ ] **Step 3: Open the dialog for no-default kinds in the picker**

In `service_schedule_dialogs.dart` `showServiceKindPicker`, change the `onTap` of the kind `ListTile` so that after creating the schedule, it opens the override dialog when the kind has no default interval:

```dart
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final now = DateTime.now();
                  final created = await ref
                      .read(serviceScheduleRepositoryProvider)
                      .createSchedule(
                        ServiceSchedule(
                          id: '',
                          equipmentId: equipmentId,
                          serviceKindId: kind.id,
                          createdAt: now,
                          updatedAt: now,
                        ),
                      );
                  // A kind with no default interval yields an invisible clock
                  // until an interval is set, so configure it immediately.
                  final needsInterval = kind.defaultIntervalDays == null &&
                      kind.defaultIntervalDives == null &&
                      kind.defaultIntervalHours == null;
                  if (needsInterval && context.mounted) {
                    await showScheduleOverrideDialog(
                      context,
                      ref,
                      schedule: created,
                      kind: kind,
                    );
                  }
                  invalidateServiceClockProviders(ref, equipmentId);
                },
```

Note: use the outer `context` (the page context passed to `showServiceKindPicker`) for the dialog, since `sheetContext` is popped. Confirm `context` is in scope (it is the function parameter).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/equipment/presentation/widgets/service_kind_picker_test.dart`
Expected: PASS (both cases)

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/equipment/presentation/widgets/service_schedule_dialogs.dart test/features/equipment/presentation/widgets/service_kind_picker_test.dart
git commit -m "fix(equipment): configure interval when adding a no-default service clock"
```

---

## Task 4: Detail header derives overdue from clocks; remove "Mark as serviced"

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart`
- Test: `test/features/equipment/presentation/pages/equipment_detail_service_test.dart` (create)

**Interfaces:**
- Consumes: `serviceClockStatusesProvider(equipmentId)`, `ServiceClockSeverity`.

- [ ] **Step 1: Write the failing test**

Create `test/features/equipment/presentation/pages/equipment_detail_service_test.dart`. Render `EquipmentDetailPage` (embedded) with overrides: `equipmentItemProvider(id)` returning an item that is legacy-overdue (`serviceIntervalDays`+old `lastServiceDate`) but with `serviceClockStatusesProvider(id)` returning `[]`. Assert the overdue banner (`equipment_detail_serviceOverdue` text) is NOT shown — proving the header reads clocks, not `isServiceDue`. Add a second case where `serviceClockStatusesProvider` returns an overdue status and assert the banner IS shown. Mirror the ProviderScope + MaterialApp harness from `equipment_tile_service_badge_test.dart`; also override `equipmentDiveCountProvider`, `equipmentTripCountProvider`, `serviceRecordNotifierProvider`, `serviceRecordTotalCostProvider`, and `settingsProvider` as needed to render without a database (follow existing detail/page tests under `test/features/equipment/` for the exact override set).

```dart
// Skeleton — fill provider overrides following existing equipment page tests.
testWidgets('overdue banner follows clocks, not legacy interval', (tester) async {
  final legacyOverdue = EquipmentItem(
    id: 'e1',
    name: 'Old Reg',
    type: EquipmentType.regulator,
    lastServiceDate: DateTime.now().subtract(const Duration(days: 400)),
    serviceIntervalDays: 365, // legacy says overdue
  );
  await tester.pumpWidget(wrapDetail(
    equipmentId: 'e1',
    item: legacyOverdue,
    clockStatuses: const [], // clocks say fine
  ));
  await tester.pumpAndSettle();
  expect(find.text('Service overdue'), findsNothing);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/equipment/presentation/pages/equipment_detail_service_test.dart`
Expected: FAIL — banner is shown because the header still reads `equipment.isServiceDue`.

- [ ] **Step 3: Derive overdue from clocks in the detail content**

In `equipment_detail_page.dart`, in `_EquipmentDetailContent.build`, compute a clock-derived flag and thread it into the header builders:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final isServiceOverdue = ref
            .watch(serviceClockStatusesProvider(equipmentId))
            .value
            ?.any((s) => s.severity == ServiceClockSeverity.overdue) ??
        false;
    // ... use isServiceOverdue below
```

Add `import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';` if not present.

Change `_buildHeaderSection` and `_buildEmbeddedHeader` to accept a `bool isServiceOverdue` parameter and replace all `equipment.isServiceDue` reads inside them with `isServiceOverdue`. Update their call sites in `build` to pass `isServiceOverdue`.

- [ ] **Step 4: Remove the "Mark as serviced" menu action**

In `_buildMenuItems`, delete the `if (equipment.isActive) PopupMenuItem(value: 'service', ...)` entry. In `_handleMenuAction`, delete the `case 'service':` block.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/equipment/presentation/pages/equipment_detail_service_test.dart`
Expected: PASS
Run: `flutter analyze lib/features/equipment/presentation/pages/equipment_detail_page.dart`
Expected: No issues (confirm `markAsServiced` no longer referenced here; the repo/notifier method stays).

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/equipment/presentation/pages/equipment_detail_page.dart test/features/equipment/presentation/pages/equipment_detail_service_test.dart
git commit -m "feat(equipment): detail header service state from clocks; drop mark-as-serviced"
```

---

## Task 5: List badges rely solely on clocks

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (`EquipmentListTile` avatar + `_buildTrailing`)
- Modify: `lib/features/equipment/presentation/widgets/dense_equipment_list_tile.dart`
- Modify: `test/features/equipment/presentation/widgets/equipment_tile_service_badge_test.dart`

**Interfaces:**
- Consumes: `equipmentWorstClockProvider`.

- [ ] **Step 1: Update the badge test to the new contract (failing)**

In `equipment_tile_service_badge_test.dart`, delete the two legacy tests `legacy overdue fallback when no ledger data` and `legacy days-until fallback` (lines ~131-157). Add a test asserting that with no ledger entry and a legacy-overdue item, NO "Service Due" text appears:

```dart
    testWidgets('no badge when the ledger has no entry (legacy ignored)', (
      tester,
    ) async {
      final item = EquipmentItem(
        id: 'e1',
        name: 'Old Reg',
        type: EquipmentType.regulator,
        lastServiceDate: DateTime.now().subtract(const Duration(days: 400)),
        serviceIntervalDays: 365,
      );
      await tester.pumpWidget(wrap(EquipmentListTile(item: item)));
      await tester.pumpAndSettle();

      expect(find.text('Service Due'), findsNothing);
      expect(find.textContaining('Service in '), findsNothing);
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_tile_service_badge_test.dart`
Expected: FAIL — "Service Due" still shows via the legacy fallback.

- [ ] **Step 3: Drop the legacy fallback in `equipment_list_content.dart`**

In `EquipmentListTile.build`, change the avatar overdue computation to clocks-only:

```dart
    final worstClock = ref.watch(equipmentWorstClockProvider).value?[item.id];
    final isOverdue =
        worstClock?.status.severity == ServiceClockSeverity.overdue;
```

In `_buildTrailing`, delete the entire `// Legacy single-clock fallback ...` block (`if (item.isServiceDue) {...}`) and the following `if (item.daysUntilService != null) {...}` block, so that when `worstClock == null` the method falls through to its final return (the plain type label). Keep the `if (worstClock != null) {...}` branch.

- [ ] **Step 4: Drop the legacy fallback in `dense_equipment_list_tile.dart`**

Apply the same edit: remove the `if (item.isServiceDue) {...}` and `if (item.daysUntilService != null) {...}` fallback blocks in its trailing builder, and set the avatar/overdue read to `worstClock?.status.severity == ServiceClockSeverity.overdue`. (Read the file first to confirm the exact avatar variable and final return.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_tile_service_badge_test.dart test/features/equipment/presentation/widgets/dense_equipment_list_tile_test.dart test/features/equipment/presentation/widgets/equipment_list_content_test.dart`
Expected: PASS. If `dense_equipment_list_tile_test` or `equipment_list_content_test` asserted legacy-fallback behaviour, update those assertions to the clocks-only contract the same way.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/equipment/presentation/widgets/equipment_list_content.dart lib/features/equipment/presentation/widgets/dense_equipment_list_tile.dart test/features/equipment/presentation/widgets/
git commit -m "feat(equipment): list badges use clocks only, drop legacy fallback"
```

---

## Task 6: Pre-dive checklist flags overdue gear from clocks

**Files:**
- Modify: `lib/features/pre_dive/domain/services/session_item_composer.dart`
- Modify: `lib/features/pre_dive/presentation/widgets/start_session_sheet.dart`
- Modify: `test/features/pre_dive/domain/services/session_item_composer_test.dart`

**Interfaces:**
- Produces: `SessionItemComposer.compose({..., Set<String> overdueEquipmentIds = const {}})`
- Consumes (in sheet): `equipmentWorstClockProvider`.

- [ ] **Step 1: Update the composer test to the new contract (failing)**

In `session_item_composer_test.dart`, find the test(s) that rely on `EquipmentItem.isServiceDue` to flag a gear row. Change them to pass `overdueEquipmentIds` instead. Add/adjust:

```dart
    final items = SessionItemComposer.compose(
      templateItems: templateItems,
      equipmentSet: set,
      equipmentItems: gear,
      now: now,
      serviceOverdueNote: 'Overdue',
      overdueEquipmentIds: {'g1'}, // g1 flagged via clocks
    );
    final row = items.firstWhere((i) => i.equipmentId == 'g1');
    expect(row.state, PreDiveItemState.flagged);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/pre_dive/domain/services/session_item_composer_test.dart`
Expected: FAIL — `compose` has no `overdueEquipmentIds` parameter (compile error).

- [ ] **Step 3: Add the parameter to the composer**

In `session_item_composer.dart`, add the parameter and use it:

```dart
  static List<PreDiveSessionItem> compose({
    required List<PreDiveChecklistTemplateItem> templateItems,
    EquipmentSet? equipmentSet,
    List<EquipmentItem> equipmentItems = const [],
    required DateTime now,
    required String serviceOverdueNote,
    // Ids of gear whose service is overdue, derived from the clock engine by
    // the caller so this domain service stays pure.
    Set<String> overdueEquipmentIds = const {},
  }) {
```

Replace `final overdue = gear.isServiceDue;` with:

```dart
          final overdue = overdueEquipmentIds.contains(gear.id);
```

- [ ] **Step 4: Pass clock-derived ids from the start-session sheet**

In `start_session_sheet.dart`, before the `SessionItemComposer.compose(...)` call at line ~83, read the worst-clock map and build the overdue set, then pass it:

```dart
      final worstClocks =
          await ref.read(equipmentWorstClockProvider.future);
      final overdueEquipmentIds = <String>{
        for (final entry in worstClocks.entries)
          if (entry.value.status.severity == ServiceClockSeverity.overdue)
            entry.key,
      };
      final items = SessionItemComposer.compose(
        // ... existing args ...
        overdueEquipmentIds: overdueEquipmentIds,
      );
```

Add imports if missing: `equipment_providers.dart` (for `equipmentWorstClockProvider`) and `service_clock_status.dart` (for `ServiceClockSeverity`). Confirm the surrounding method is async (it awaits elsewhere).

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/pre_dive/domain/services/session_item_composer_test.dart`
Expected: PASS
Run: `flutter analyze lib/features/pre_dive/`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/pre_dive/ test/features/pre_dive/domain/services/session_item_composer_test.dart
git commit -m "feat(pre-dive): flag overdue gear from service clocks"
```

---

## Task 7: Remove the legacy "Service Settings" section from the edit form

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_edit_page.dart`
- Test: `test/features/equipment/presentation/pages/equipment_edit_service_section_test.dart` (create)

**Interfaces:**
- On save, legacy columns are preserved from `existingEquipment`, not from removed controls.

- [ ] **Step 1: Write the failing test**

Create `test/features/equipment/presentation/pages/equipment_edit_service_section_test.dart`: render `EquipmentEditPage(equipmentId: 'e1')` (editing) with `equipmentItemProvider('e1')` overridden to return an item, and assert the "Service Interval" field is absent:

```dart
    // The legacy service interval label must no longer render.
    expect(find.text('Service Interval (days)'), findsNothing);
```

Use the en template value of `equipment_edit_serviceIntervalLabel` for the exact string (read it from `app_en.arb`). Follow the edit-page test harness under `test/features/equipment/` for provider overrides.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/equipment/presentation/pages/equipment_edit_service_section_test.dart`
Expected: FAIL — the field is still rendered.

- [ ] **Step 3: Remove the section and its state**

In `equipment_edit_page.dart`:
- Delete the `if (widget.isEditing) ...[ _buildServiceSection(context), const SizedBox(height: 24), ]` block in `_buildForm`.
- Delete the `_buildServiceSection` method and the `_selectLastServiceDate` method.
- Delete `final _serviceIntervalController = TextEditingController();` and `DateTime? _lastServiceDate;`.
- Remove `_serviceIntervalController.addListener(_onFieldChanged);` in `initState` and `_serviceIntervalController.dispose();` in `dispose`.
- In `_initializeFromEquipment`, delete the two lines assigning `_serviceIntervalController.text` and `_lastServiceDate`.

In `_saveEquipment`, preserve the legacy values from the existing item instead of the removed controls:

```dart
        lastServiceDate: existingEquipment?.lastServiceDate,
        serviceIntervalDays: existingEquipment?.serviceIntervalDays,
```

- [ ] **Step 4: Run test + analyze**

Run: `flutter test test/features/equipment/presentation/pages/equipment_edit_service_section_test.dart`
Expected: PASS
Run: `flutter analyze lib/features/equipment/presentation/pages/equipment_edit_page.dart`
Expected: No issues (no unused fields/methods left behind).

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/equipment/presentation/pages/equipment_edit_page.dart test/features/equipment/presentation/pages/equipment_edit_service_section_test.dart
git commit -m "feat(equipment): remove legacy service settings from edit form"
```

---

## Task 8: Add the clock-based "Service due" list sort

**Files:**
- Modify: `lib/core/constants/sort_options.dart`
- Modify: `lib/features/equipment/presentation/providers/equipment_providers.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (two `applyEquipmentSorting` call sites)
- Test: `test/features/equipment/presentation/providers/equipment_sort_test.dart` (create)

**Interfaces:**
- Produces: `EquipmentSortField.serviceDue`
- Produces: `final equipmentServiceUrgencyProvider = FutureProvider<Map<String, ServiceClockStatus>>`
- Produces: `List<EquipmentItem> applyEquipmentSorting(List<EquipmentItem> equipment, SortState<EquipmentSortField> sort, {Map<String, ServiceClockStatus> serviceUrgency = const {}})`

- [ ] **Step 1: Write the failing test**

Create `test/features/equipment/presentation/providers/equipment_sort_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

void main() {
  final t0 = DateTime(2025, 1, 1);
  ServiceClockStatus status(String eid, ServiceClockSeverity sev, DateTime? due) =>
      ServiceClockStatus(
        schedule: ServiceSchedule(
          id: 's-$eid',
          equipmentId: eid,
          serviceKindId: 'general-service',
          createdAt: t0,
          updatedAt: t0,
        ),
        kind: ServiceKind(
          id: 'general-service',
          name: 'General service',
          createdAt: t0,
          updatedAt: t0,
        ),
        anchor: t0,
        dueDate: due,
        severity: sev,
        now: DateTime(2026, 1, 1),
      );

  test('serviceDue ascending orders overdue, then soonest, then no-clock last', () {
    const overdue = EquipmentItem(id: 'a', name: 'A', type: EquipmentType.tank);
    const soon = EquipmentItem(id: 'b', name: 'B', type: EquipmentType.tank);
    const none = EquipmentItem(id: 'c', name: 'C', type: EquipmentType.tank);

    final sorted = applyEquipmentSorting(
      [none, soon, overdue],
      const SortState(
        field: EquipmentSortField.serviceDue,
        direction: SortDirection.ascending,
      ),
      serviceUrgency: {
        'a': status('a', ServiceClockSeverity.overdue, DateTime(2025, 6, 1)),
        'b': status('b', ServiceClockSeverity.dueSoon, DateTime(2026, 3, 1)),
      },
    );

    expect(sorted.map((e) => e.id).toList(), ['a', 'b', 'c']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/equipment/presentation/providers/equipment_sort_test.dart`
Expected: FAIL — `EquipmentSortField.serviceDue` undefined and `applyEquipmentSorting` has no `serviceUrgency` parameter.

- [ ] **Step 3: Add the sort field enum value**

In `sort_options.dart`, add to `EquipmentSortField`:

```dart
enum EquipmentSortField {
  name('Name', Icons.sort_by_alpha),
  type('Type', Icons.category),
  purchaseDate('Purchase Date', Icons.shopping_bag),
  lastServiceDate('Last Service', Icons.build),
  serviceDue('Service Due', Icons.av_timer);
```

- [ ] **Step 4: Add the urgency provider and extend the sort function**

In `equipment_providers.dart`, add the provider near the other ledger providers:

```dart
/// Most-urgent clock per active equipment id, INCLUDING ok (not-yet-due)
/// clocks -- unlike [equipmentWorstClockProvider], which only carries due or
/// overdue clocks. Backs the service-due sort and the Next Service Due table
/// column so not-yet-due gear still sorts and displays its upcoming date.
final equipmentServiceUrgencyProvider =
    FutureProvider<Map<String, ServiceClockStatus>>((ref) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  ref.invalidateSelfWhen(repository.watchEquipmentChanges());
  final items = await repository.getActiveEquipment(diverId: validatedDiverId);
  final kinds = await ref.watch(serviceKindRepositoryProvider).getAllKinds();
  final out = <String, ServiceClockStatus>{};
  for (final item in items) {
    final statuses = await _evaluateClocksFor(ref, item, kinds: kinds);
    if (statuses.isEmpty) continue;
    // Engine returns statuses worst-severity-first, then dueDate ascending.
    out[item.id] = statuses.first;
  }
  return out;
});
```

Extend `applyEquipmentSorting` with the optional urgency map and a `serviceDue` case:

```dart
List<EquipmentItem> applyEquipmentSorting(
  List<EquipmentItem> equipment,
  SortState<EquipmentSortField> sort, {
  Map<String, ServiceClockStatus> serviceUrgency = const {},
}) {
  final sorted = List<EquipmentItem>.from(equipment);

  // Rank for the service-due sort: overdue (2) > dueSoon (1) > ok (0);
  // items with no clock rank -1 so they sort last on ascending (most-urgent
  // first). Ties break by soonest dueDate.
  int urgencyRank(EquipmentItem e) {
    final s = serviceUrgency[e.id];
    if (s == null) return -1;
    return s.severity.index; // ok=0, dueSoon=1, overdue=2
  }

  sorted.sort((a, b) {
    int comparison;
    final invertForText =
        sort.field == EquipmentSortField.name ||
        sort.field == EquipmentSortField.type;

    switch (sort.field) {
      case EquipmentSortField.name:
        comparison = a.name.compareTo(b.name);
      case EquipmentSortField.type:
        comparison = a.type.displayName.compareTo(b.type.displayName);
      case EquipmentSortField.purchaseDate:
        comparison = (a.purchaseDate ?? DateTime(1900)).compareTo(
          b.purchaseDate ?? DateTime(1900),
        );
      case EquipmentSortField.lastServiceDate:
        comparison = (a.lastServiceDate ?? DateTime(1900)).compareTo(
          b.lastServiceDate ?? DateTime(1900),
        );
      case EquipmentSortField.serviceDue:
        final ra = urgencyRank(a), rb = urgencyRank(b);
        if (ra != rb) {
          // Higher rank = more urgent. Ascending should list most urgent
          // first, so invert: more urgent yields a negative comparison.
          final c = rb.compareTo(ra);
          return sort.direction == SortDirection.ascending ? c : -c;
        }
        final da = serviceUrgency[a.id]?.dueDate;
        final db = serviceUrgency[b.id]?.dueDate;
        final byDate = (da ?? DateTime(9999)).compareTo(db ?? DateTime(9999));
        return sort.direction == SortDirection.ascending ? byDate : -byDate;
    }

    if (invertForText) {
      return sort.direction == SortDirection.ascending
          ? -comparison
          : comparison;
    }
    return sort.direction == SortDirection.ascending ? comparison : -comparison;
  });

  return sorted;
}
```

- [ ] **Step 5: Pass the urgency map at the list call sites**

In `equipment_list_content.dart`, where `applyEquipmentSorting(equipment, sort)` is called (two places, around lines 132 and 139), read the urgency map and pass it:

```dart
    final serviceUrgency =
        ref.watch(equipmentServiceUrgencyProvider).value ?? const {};
    // ...
    applyEquipmentSorting(equipment, sort, serviceUrgency: serviceUrgency)
```

Ensure `serviceUrgency` is read once in the relevant build scope and used in both call sites.

- [ ] **Step 6: Run tests + analyze**

Run: `flutter test test/features/equipment/presentation/providers/equipment_sort_test.dart`
Expected: PASS
Run: `flutter analyze lib/core/constants/sort_options.dart lib/features/equipment/presentation/providers/equipment_providers.dart lib/features/equipment/presentation/widgets/equipment_list_content.dart`
Expected: No issues.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/core/constants/sort_options.dart lib/features/equipment/presentation/providers/equipment_providers.dart lib/features/equipment/presentation/widgets/equipment_list_content.dart test/features/equipment/presentation/providers/equipment_sort_test.dart
git commit -m "feat(equipment): add clock-based Service Due list sort"
```

---

## Task 9: Redirect the table service-forecast columns to clocks

**Files:**
- Modify: `lib/features/equipment/domain/constants/equipment_field.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (`_buildTableView`)
- Test: `test/features/equipment/domain/constants/equipment_field_test.dart` (add a case; create if absent)

**Interfaces:**
- Consumes: `equipmentServiceUrgencyProvider` (Task 8).
- Produces: `EquipmentFieldAdapter({Map<String, ServiceClockStatus> worstClocks = const {}})`

- [ ] **Step 1: Write the failing test**

Add to `test/features/equipment/domain/constants/equipment_field_test.dart`:

```dart
  test('nextServiceDue extracts the clock due date, not the legacy getter', () {
    final t0 = DateTime(2025, 1, 1);
    const item = EquipmentItem(id: 'e1', name: 'AL80', type: EquipmentType.tank);
    final due = DateTime(2026, 6, 1);
    final adapter = EquipmentFieldAdapter(worstClocks: {
      'e1': ServiceClockStatus(
        schedule: ServiceSchedule(
          id: 's1', equipmentId: 'e1', serviceKindId: 'hydro',
          createdAt: t0, updatedAt: t0,
        ),
        kind: ServiceKind(
          id: 'hydro', name: 'Hydro', defaultIntervalDays: 1825,
          createdAt: t0, updatedAt: t0,
        ),
        anchor: t0,
        dueDate: due,
        severity: ServiceClockSeverity.dueSoon,
        now: t0,
      ),
    });
    expect(adapter.extractValue(EquipmentField.nextServiceDue, item), due);
  });
```

Add the necessary imports (`ServiceClockStatus`, `ServiceKind`, `ServiceSchedule`, `EquipmentType`).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/equipment/domain/constants/equipment_field_test.dart`
Expected: FAIL — `EquipmentFieldAdapter` has no `worstClocks` constructor arg; `extractValue` returns the legacy `entity.nextServiceDue`.

- [ ] **Step 3: Make the adapter carry a clock map and redirect fields**

In `equipment_field.dart`:
- Add `import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';`
- Replace the singleton wiring and add the field/constructor:

```dart
class EquipmentFieldAdapter
    extends EntityFieldAdapter<EquipmentItem, EquipmentField> {
  /// Most-urgent clock per equipment id (from equipmentServiceUrgencyProvider).
  /// Empty for the shared singleton used only for config deserialization.
  final Map<String, ServiceClockStatus> worstClocks;

  EquipmentFieldAdapter({this.worstClocks = const {}});

  /// Shared instance for config deserialization (fieldFromName). Carries no
  /// clock data; views construct their own instance with the current map.
  static final instance = EquipmentFieldAdapter();
```

Remove the old `EquipmentFieldAdapter._();` private constructor and the `static const List<EquipmentField> _allFields` / `_fieldsByCategory` if they reference the private constructor — keep them as-is (they do not); only the constructor changes.

In `extractValue`, redirect the two forecast fields to the clock map:

```dart
      EquipmentField.lastServiceDate => entity.lastServiceDate,
      EquipmentField.nextServiceDue => worstClocks[entity.id]?.dueDate,
      EquipmentField.daysUntilService => worstClocks[entity.id]?.daysUntilDue,
      EquipmentField.serviceIntervalDays => entity.serviceIntervalDays,
```

(`lastServiceDate` and `serviceIntervalDays` stay entity-backed; `nextServiceDue`/`daysUntilService` now come from clocks.)

- [ ] **Step 4: Pass a clock-carrying adapter from the table view**

In `equipment_list_content.dart` `_buildTableView`, construct the adapter with the current urgency map. Read the map and build the `EquipmentFieldAdapter`:

```dart
    final serviceUrgency =
        ref.watch(equipmentServiceUrgencyProvider).value ?? const {};
    // ... where EntityTableView is built:
        EntityTableView<EquipmentItem, EquipmentField>(
          // ...
          adapter: EquipmentFieldAdapter(worstClocks: serviceUrgency),
          // ...
        ),
```

(Confirm the current `adapter:` argument — it is likely `EquipmentFieldAdapter.instance`; replace it with the per-build instance.)

- [ ] **Step 5: Run tests + analyze**

Run: `flutter test test/features/equipment/domain/constants/equipment_field_test.dart`
Expected: PASS
Run: `flutter analyze lib/features/equipment/domain/constants/equipment_field.dart lib/features/equipment/presentation/widgets/equipment_list_content.dart`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/equipment/domain/constants/equipment_field.dart lib/features/equipment/presentation/widgets/equipment_list_content.dart test/features/equipment/domain/constants/equipment_field_test.dart
git commit -m "feat(equipment): table Next Service Due column reads clocks"
```

---

## Task 10: v131 migration to reconcile late legacy edits

**Files:**
- Modify: `lib/core/database/database.dart`
- Test: `test/core/database/migration_v131_service_reconcile_test.dart` (create)

**Interfaces:**
- Bumps `currentSchemaVersion` 130 -> 131 and adds an onUpgrade `if (from < 131)` block calling `_reconcileLegacyServiceSchedules()`.

- [ ] **Step 1: Write the failing test**

Create `test/core/database/migration_v131_service_reconcile_test.dart`. Open an `AppDatabase` on an in-memory executor, insert a diver + equipment with `service_interval_days` set but no `legacy-svc-` schedule, run `_reconcileLegacyServiceSchedules`, and assert a schedule with id `legacy-svc-<id>` now exists; then a second item whose `legacy-svc-` id is present in `deletion_log` must NOT get a schedule. Mirror the harness of an existing migration test under `test/core/database/` for constructing the database and calling migration helpers (use the same `NativeDatabase.memory()` / test constructor pattern those tests use).

```dart
// Skeleton — follow an existing migration test for DB construction.
test('reconcile creates legacy-svc clock for un-migrated interval', () async {
  // insert diver 'd1'
  // insert equipment 'e1' with serviceIntervalDays = 180, no schedule
  await db.reconcileLegacyServiceSchedulesForTest(); // exposed hook
  final rows = await db.customSelect(
    "SELECT id FROM service_schedules WHERE id = 'legacy-svc-e1'",
  ).get();
  expect(rows, hasLength(1));
});

test('reconcile skips a tombstoned legacy-svc clock', () async {
  // insert equipment 'e2' with serviceIntervalDays = 180, no schedule
  // insert deletion_log row (entity_type='serviceSchedules', record_id='legacy-svc-e2')
  await db.reconcileLegacyServiceSchedulesForTest();
  final rows = await db.customSelect(
    "SELECT id FROM service_schedules WHERE id = 'legacy-svc-e2'",
  ).get();
  expect(rows, isEmpty);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/migration_v131_service_reconcile_test.dart`
Expected: FAIL — the reconcile helper does not exist.

- [ ] **Step 3: Add the reconcile helper**

In `database.dart`, add the method next to `_backfillLegacyServiceSchedules`:

```dart
  /// v131 one-time reconciliation: items whose legacy interval was set via the
  /// edit form AFTER the v122 backfill ran have an interval column but no
  /// clock. Create the same deterministic `legacy-svc-<id>` "General service"
  /// clock for them so removing the legacy edit field does not drop their due
  /// signal. Guarded by the deletion log so a clock the user deleted is never
  /// resurrected. onUpgrade only, never beforeOpen (re-running would resurrect).
  Future<void> _reconcileLegacyServiceSchedules() async {
    final eqCols = await customSelect("PRAGMA table_info('equipment')").get();
    final names = eqCols.map((c) => c.read<String>('name')).toSet();
    if (!names.containsAll({'service_interval_days', 'last_service_date'})) {
      return;
    }
    await customStatement('''
      INSERT OR IGNORE INTO service_schedules
        (id, equipment_id, service_kind_id, interval_days, anchor_date,
         enabled, created_at, updated_at)
      SELECT 'legacy-svc-' || e.id, e.id, 'general-service',
             e.service_interval_days, e.last_service_date, 1, n.now_ms, n.now_ms
      FROM equipment e
      CROSS JOIN (
        SELECT CAST(strftime('%s','now') AS INTEGER) * 1000 AS now_ms
      ) n
      WHERE e.service_interval_days IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM service_schedules s WHERE s.id = 'legacy-svc-' || e.id
        )
        AND NOT EXISTS (
          SELECT 1 FROM deletion_log d
          WHERE d.entity_type = 'serviceSchedules'
            AND d.record_id = 'legacy-svc-' || e.id
        )
    ''');
  }

  /// Test-only hook to exercise the v131 reconciliation directly.
  @visibleForTesting
  Future<void> reconcileLegacyServiceSchedulesForTest() =>
      _reconcileLegacyServiceSchedules();
```

Ensure `import 'package:flutter/foundation.dart';` (for `@visibleForTesting`) is present in `database.dart` (add if missing).

- [ ] **Step 4: Bump the schema version and wire the onUpgrade block**

Change `static const int currentSchemaVersion = 130;` to `= 131;`.

In the `onUpgrade` migration callback, after the `if (from < 129) ...` block, add:

```dart
        // v131: reconcile legacy service intervals edited after the v122
        // backfill into General service clocks (deletion-log guarded).
        if (from < 131) {
          await _reconcileLegacyServiceSchedules();
        }
        if (from < 131) await reportProgress();
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/core/database/migration_v131_service_reconcile_test.dart`
Expected: PASS (both cases)

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/core/database/database.dart test/core/database/migration_v131_service_reconcile_test.dart
git commit -m "feat(db): v131 reconcile legacy service intervals into clocks"
```

---

## Task 11: Full-suite verification

**Files:** none (verification only)

- [ ] **Step 1: Format and analyze the whole project**

Run: `dart format --set-exit-if-changed .`
Expected: no changes.
Run: `flutter analyze`
Expected: No issues found (whole project, info lints included).

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: all pass. Any remaining failures are legacy-service assertions in files not yet updated (e.g. `equipment_providers_test.dart`, `equipment_repository_test.dart`, `service_due_engine_test.dart`); update those assertions to the clocks-only / unchanged-engine contract as appropriate, keeping each fix in a focused follow-up commit.

- [ ] **Step 3: Manual smoke (macOS)**

Run: `flutter run -d macos`
Verify: (1) add a "General service" timer to a mask -> a configure dialog opens and, once an interval is set, the clock shows in the card; (2) the edit form has no "Service Settings" section; (3) the equipment list sort sheet offers "Service Due"; (4) an item overdue only by clocks shows the detail banner; a legacy-only-overdue item does not.

- [ ] **Step 4: Commit any follow-up test fixes**

```bash
dart format .
git add -A
git commit -m "test(equipment): update service assertions for clock unification"
```

---

## Self-review notes

- Spec coverage: Part A -> Tasks 1-3; Part B -> Tasks 4-7; Part C -> Tasks 8-9; Part D -> Task 10; testing -> each task + Task 11.
- The engine (`ServiceDueEngine`) is intentionally unchanged; `service_due_engine_test.dart` should not need behavioural edits (only add cases if desired).
- `markAsServiced` remains in the repository/notifier (unused by UI) to limit churn, as the spec states.
- `serviceIntervalDays` `EquipmentField` is retained (entity-backed) to avoid breaking persisted table configs referencing it by name.
