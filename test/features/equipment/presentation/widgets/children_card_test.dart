import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/children_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const ccr = EquipmentItem(
  id: 'r1',
  name: 'CCR',
  type: EquipmentType.rebreather,
);

class _FailingRepo extends EquipmentRepository {
  @override
  Future<EquipmentItem> replaceChild(EquipmentItem old, {DateTime? now}) =>
      Future.error(StateError('db closed'));
}

class _SlowRepo extends EquipmentRepository {
  final done = Completer<EquipmentItem>();

  @override
  Future<EquipmentItem> replaceChild(EquipmentItem old, {DateTime? now}) =>
      done.future;
}

class _RecordingRepo extends EquipmentRepository {
  final replaced = <EquipmentItem>[];

  @override
  Future<EquipmentItem> replaceChild(EquipmentItem old, {DateTime? now}) async {
    replaced.add(old);
    return old.copyWith(id: 'new');
  }
}

EquipmentItem child(
  String id,
  String name,
  EquipmentType type, {
  int? slot,
  required DateTime installed,
}) => EquipmentItem(
  id: id,
  name: name,
  type: type,
  parentEquipmentId: 'r1',
  attributes: [
    if (slot != null)
      EquipmentAttribute.curated(
        equipmentId: id,
        key: EquipmentAttrKeys.cellSlot,
        valueNum: slot.toDouble(),
      ),
    EquipmentAttribute.curated(
      equipmentId: id,
      key: EquipmentAttrKeys.installedDate,
      valueNum: installed.millisecondsSinceEpoch.toDouble(),
    ),
  ],
);

DueClock overdue(EquipmentItem item) {
  final t0 = DateTime(2025, 1, 1);
  return (
    item: item,
    status: ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's1',
        equipmentId: item.id,
        serviceKindId: 'k',
        createdAt: t0,
        updatedAt: t0,
      ),
      kind: ServiceKind(
        id: 'k',
        name: 'Battery',
        defaultIntervalDays: 365,
        isBuiltIn: true,
        createdAt: t0,
        updatedAt: t0,
      ),
      anchor: t0,
      dueDate: DateTime(2026, 1, 1),
      severity: ServiceClockSeverity.overdue,
      now: DateTime(2026, 7, 1),
    ),
  );
}

Widget host({
  required EquipmentItem equipment,
  required List<EquipmentItem> children,
  Map<String, DueClock> worst = const {},
  EquipmentRepository? repo,
  List<String>? pushed,
  List<String?>? newParents,
  Future<List<EquipmentItem>> Function()? load,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            Scaffold(body: ChildrenCard(equipment: equipment)),
      ),
      GoRoute(
        path: '/equipment/new',
        builder: (context, state) {
          newParents?.add(state.uri.queryParameters['parent']);
          return const Scaffold(body: Text('NEW'));
        },
      ),
      GoRoute(
        path: '/equipment/:id',
        builder: (context, state) {
          pushed?.add(state.pathParameters['id']!);
          return const Scaffold(body: Text('ITEM'));
        },
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      childEquipmentProvider(
        equipment.id,
      ).overrideWith((ref) => load?.call() ?? Future.value(children)),
      equipmentWorstClockProvider.overrideWith((ref) async => worst),
      if (repo != null) equipmentRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  final now = DateTime.now();
  final cell = child(
    'c1',
    'Cell 1',
    EquipmentType.o2Cell,
    slot: 1,
    installed: now.subtract(const Duration(days: 40)),
  );
  final battery = child(
    'b1',
    'Handset battery',
    EquipmentType.battery,
    installed: now.subtract(const Duration(days: 200)),
  );

  testWidgets('lists slot, age and the worst clock dot', (tester) async {
    await tester.pumpWidget(
      host(
        equipment: ccr,
        children: [cell, battery],
        worst: {'b1': overdue(battery)},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Installed parts'), findsOneWidget);
    expect(find.text('Slot 1 · Cell 1'), findsOneWidget);
    expect(find.text('Handset battery'), findsOneWidget);
    expect(find.textContaining('40 days ago'), findsOneWidget);
    expect(find.textContaining('6 months ago'), findsOneWidget);
    final scheme = Theme.of(
      tester.element(find.byType(ChildrenCard)),
    ).colorScheme;
    final dots = tester.widgetList<Icon>(find.byIcon(Icons.circle)).toList();
    expect(dots.where((d) => d.color == scheme.error), hasLength(1));
  });

  testWidgets('replace confirms, calls the repository and reports', (
    tester,
  ) async {
    final repo = _RecordingRepo();
    await tester.pumpWidget(host(equipment: ccr, children: [cell], repo: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(find.text('Replace Cell 1?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Replace'));
    await tester.pumpAndSettle();
    expect(repo.replaced.map((e) => e.id), ['c1']);
    expect(find.text('Cell 1 replaced'), findsOneWidget);
  });

  testWidgets('open navigates to the child', (tester) async {
    final pushed = <String>[];
    await tester.pumpWidget(
      host(equipment: ccr, children: [cell], pushed: pushed),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(pushed, ['c1']);
  });

  testWidgets('a full year reads as twelve months', (tester) async {
    // Completed calendar months: an average month length undercounts, so
    // a part installed a year ago read "11 months".
    final yearOld = child(
      'y1',
      'Old cell',
      EquipmentType.o2Cell,
      slot: 2,
      installed: DateTime(now.year - 1, now.month, now.day),
    );
    await tester.pumpWidget(host(equipment: ccr, children: [yearOld]));
    await tester.pumpAndSettle();
    expect(find.textContaining('12 months'), findsOneWidget);
  });

  testWidgets('a part with no install date dates from its creation', (
    tester,
  ) async {
    // Its exposure counts from createdAt (parentDivesFrom), so the card
    // states that date rather than only the type.
    final bare = EquipmentItem(
      id: 'b1',
      name: 'Spare cell',
      type: EquipmentType.o2Cell,
      parentEquipmentId: 'r1',
      createdAt: now.subtract(const Duration(days: 12)),
    );
    await tester.pumpWidget(host(equipment: ccr, children: [bare]));
    await tester.pumpAndSettle();
    expect(find.textContaining('12 days ago'), findsOneWidget);
  });

  testWidgets('a failed replace tells the diver', (tester) async {
    await tester.pumpWidget(
      host(equipment: ccr, children: [cell], repo: _FailingRepo()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Replace'));
    await tester.pumpAndSettle();
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('a failed load shows a localized line, not the error', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        equipment: ccr,
        children: const [],
        load: () => Future.error(StateError('db closed')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('db closed'), findsNothing);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('add opens a new part already fitted to this host', (
    tester,
  ) async {
    final parents = <String?>[];
    await tester.pumpWidget(
      host(equipment: ccr, children: const [], newParents: parents),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(parents, ['r1']);
  });

  testWidgets('a slot no cell reading can match is not shown as one', (
    tester,
  ) async {
    // Slots run 1 to 6 (o2Sensor1 to o2Sensor6); the form takes any number,
    // and "Slot 0" would never match a trend or a slot finding.
    final odd = child(
      'c0',
      'Spare cell',
      EquipmentType.o2Cell,
      slot: 0,
      installed: now.subtract(const Duration(days: 40)),
    );
    await tester.pumpWidget(host(equipment: ccr, children: [odd]));
    await tester.pumpAndSettle();
    expect(find.textContaining('Slot 0'), findsNothing);
    expect(find.text('Spare cell'), findsOneWidget);
  });

  testWidgets('a retired host offers no Add', (tester) async {
    // A part added from here is fitted to this host, which a retired or
    // sold host cannot take; the editor would drop the parent silently.
    final retired = ccr.copyWith(
      status: EquipmentStatus.retired,
      isActive: false,
    );
    await tester.pumpWidget(host(equipment: retired, children: const []));
    await tester.pumpAndSettle();
    expect(find.text('Add'), findsNothing);
  });

  testWidgets('sixty days still reads in days', (tester) async {
    // Days through day 60, calendar months after (the phase plan). The
    // install day is a local calendar day, as the date picker stores it.
    final today = DateTime(now.year, now.month, now.day);
    final sixty = child(
      'c6',
      'Cell 6',
      EquipmentType.o2Cell,
      slot: 2,
      installed: DateTime(today.year, today.month, today.day - 60),
    );
    await tester.pumpWidget(host(equipment: ccr, children: [sixty]));
    await tester.pumpAndSettle();
    expect(find.textContaining('60 days ago'), findsOneWidget);
  });

  testWidgets('a replace that finishes after the page is gone does not throw', (
    tester,
  ) async {
    final repo = _SlowRepo();
    await tester.pumpWidget(host(equipment: ccr, children: [cell], repo: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Replace'));
    await tester.pump();
    // The diver leaves the item page while the replacement is saving.
    await tester.pumpWidget(const SizedBox());
    repo.done.complete(cell.copyWith(id: 'new'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a host with no children shows the empty line', (tester) async {
    await tester.pumpWidget(host(equipment: ccr, children: const []));
    await tester.pumpAndSettle();
    expect(find.text('No cells or batteries recorded'), findsOneWidget);
  });

  testWidgets('a non-host type renders nothing', (tester) async {
    const mask = EquipmentItem(id: 'm', name: 'Mask', type: EquipmentType.mask);
    await tester.pumpWidget(host(equipment: mask, children: const []));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);
  });
}
