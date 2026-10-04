import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/overview/trip_overview_summary_card.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_detail_tabs.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

final _now = DateTime.now();
DateTime _days(int n) => DateTime(_now.year, _now.month, _now.day + n);

Trip _trip({int? perDay = 3, int sharing = 2}) => Trip(
  id: 't1',
  name: 'Bonaire',
  startDate: _days(12),
  endDate: _days(19),
  divesPerDayTarget: perDay,
  diversSharingCylinders: sharing,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

TripChecklistItem _todo(String id, {bool done = false, DateTime? due}) =>
    TripChecklistItem(
      id: id,
      tripId: 't1',
      title: id,
      isDone: done,
      dueDate: due,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

TripCylinderState _slot(String id, {String? equipmentId}) => foldCylinderState(
  cylinder: TripCylinder(
    id: id,
    tripId: 't1',
    label: id,
    equipmentId: equipmentId,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
  events: const [],
  uses: const [],
);

ItineraryDay _day(int offset, {int? planned, DayType type = DayType.diveDay}) =>
    ItineraryDay(
      id: 'i$offset',
      tripId: 't1',
      dayNumber: offset + 1,
      date: _days(12 + offset),
      dayType: type,
      plannedDives: planned,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

DueClock _alert(String itemId, ServiceClockSeverity severity) {
  final t0 = DateTime(2025, 1, 1);
  return (
    item: EquipmentItem(
      id: itemId,
      name: itemId,
      type: EquipmentType.regulator,
    ),
    status: ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's-$itemId',
        equipmentId: itemId,
        serviceKindId: 'k',
        createdAt: t0,
        updatedAt: t0,
      ),
      kind: ServiceKind(
        id: 'k',
        name: 'Annual service',
        defaultIntervalDays: 365,
        isBuiltIn: true,
        createdAt: t0,
        updatedAt: t0,
      ),
      anchor: t0,
      dueDate: _days(14),
      severity: severity,
      now: _now,
    ),
  );
}

Future<({List<TripDetailTab> opened, List<String> pushed})> _pump(
  WidgetTester tester, {
  Trip? trip,
  List<TripChecklistItem>? checklist,
  List<EquipmentItem>? gear,
  List<TripCylinderState>? slots,
  List<DueClock>? alerts,
  List<ItineraryDay>? days,
  bool loading = false,
}) async {
  final opened = <TripDetailTab>[];
  final pushed = <String>[];
  final never = Completer<List<TripChecklistItem>>().future;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: TripOverviewSummaryCard(
            trip: trip ?? _trip(),
            onOpenTab: opened.add,
          ),
        ),
      ),
      GoRoute(
        path: '/trips/:id/edit',
        builder: (_, s) {
          pushed.add(s.uri.path);
          return const Scaffold();
        },
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        tripChecklistProvider('t1').overrideWith(
          (ref) => loading ? never : Future.value(checklist ?? []),
        ),
        tripGearProvider('t1').overrideWith((ref) async => gear ?? const []),
        tripCylinderStatesProvider(
          't1',
        ).overrideWith((ref) async => slots ?? const []),
        tripServiceAlertsProvider(
          't1',
        ).overrideWith((ref) async => alerts ?? const []),
        itineraryDaysProvider(
          't1',
        ).overrideWith((ref) async => days ?? const []),
      ],
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  if (loading) {
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
  return (opened: opened, pushed: pushed);
}

void main() {
  testWidgets('the checklist row counts done items and the week ahead', (
    tester,
  ) async {
    await _pump(
      tester,
      checklist: [
        _todo('a', done: true),
        _todo('b', due: _days(5)),
        _todo('c', due: _days(-1)),
        _todo('d'),
      ],
    );
    expect(
      find.text('1 of 4 done · 1 due this week · 1 overdue'),
      findsOneWidget,
    );
  });

  testWidgets('the gear row counts packed items, cylinders and alerts', (
    tester,
  ) async {
    await _pump(
      tester,
      gear: const [
        EquipmentItem(id: 'g1', name: 'Reg', type: EquipmentType.regulator),
        EquipmentItem(id: 'g2', name: 'Fins', type: EquipmentType.fins),
      ],
      slots: [_slot('c1'), _slot('c2'), _slot('c3')],
      alerts: [_alert('g1', ServiceClockSeverity.dueSoon)],
    );
    expect(
      find.text('2 items packed · 3 cylinders · 1 service alert'),
      findsOneWidget,
    );
  });

  testWidgets('the packed count leaves out owned tanks on a cylinder slot, '
      'as the Gear tab does (#2874)', (tester) async {
    await _pump(
      tester,
      gear: const [
        EquipmentItem(id: 'g1', name: 'Reg', type: EquipmentType.regulator),
        EquipmentItem(id: 'tank1', name: 'AL80', type: EquipmentType.tank),
      ],
      slots: [
        _slot('c1', equipmentId: 'tank1'),
        _slot('c2'),
      ],
    );
    expect(find.text('1 item packed · 2 cylinders'), findsOneWidget);
  });

  testWidgets('the itinerary row sums planned dives and falls back to the '
      'per-day target', (tester) async {
    await _pump(
      tester,
      days: [
        _day(0, type: DayType.travel),
        _day(1, planned: 2),
        _day(2),
        _day(3, type: DayType.rest),
      ],
    );
    // 2 planned, plus the target of 3 on the derived dive day.
    expect(find.text('4 days · 5 dives planned'), findsOneWidget);
  });

  testWidgets('the itinerary row leaves out bare plan days outside the trip, '
      'as the Itinerary tab does', (tester) async {
    // The trip runs offsets 0 to 7; -2 and 9 are plan-only rows a shortened
    // trip left behind, which sync does not prune (#2663).
    await _pump(
      tester,
      days: [
        _day(-2, planned: 2),
        _day(0, planned: 2),
        _day(1, planned: 2),
        _day(9, planned: 2),
      ],
    );
    expect(find.text('2 days · 4 dives planned'), findsOneWidget);
  });

  testWidgets('with no itinerary the row says so', (tester) async {
    await _pump(tester);
    expect(find.text('Not planned yet'), findsOneWidget);
  });

  testWidgets('the plan row reads the planning numbers', (tester) async {
    await _pump(tester);
    expect(find.text('3 dives/day · 2 divers share cylinders'), findsOneWidget);
  });

  testWidgets('with no planning numbers the plan row says Not set', (
    tester,
  ) async {
    await _pump(tester, trip: _trip(perDay: null, sharing: 1));
    expect(find.text('Not set'), findsOneWidget);
  });

  testWidgets('a row whose data has not loaded shows its label alone', (
    tester,
  ) async {
    await _pump(tester, loading: true);
    expect(find.text('Checklist'), findsOneWidget);
    expect(find.textContaining(' of '), findsNothing);
  });

  testWidgets('each row opens its tab, and Plan opens the edit page', (
    tester,
  ) async {
    final h = await _pump(tester);
    await tester.tap(find.text('Checklist'));
    await tester.tap(find.text('Gear'));
    await tester.tap(find.text('Itinerary'));
    expect(h.opened, [
      TripDetailTab.checklist,
      TripDetailTab.gear,
      TripDetailTab.itinerary,
    ]);
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(h.pushed, ['/trips/t1/edit']);
  });
}
