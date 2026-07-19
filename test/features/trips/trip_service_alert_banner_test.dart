import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_service_alert_banner.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final now = DateTime.now();
  final t0 = DateTime(2025, 1, 1);

  Trip upcomingTrip() => Trip(
    id: 'trip-1',
    name: 'Bonaire',
    startDate: now.add(const Duration(days: 10)),
    endDate: now.add(const Duration(days: 17)),
    createdAt: t0,
    updatedAt: t0,
  );

  DueClock hydroAlert() {
    final kind = ServiceKind(
      id: 'hydro',
      name: 'Hydrostatic test',
      defaultIntervalDays: 1825,
      isBuiltIn: true,
      createdAt: t0,
      updatedAt: t0,
    );
    return (
      item: const EquipmentItem(
        id: 'e1',
        name: 'AL80',
        type: EquipmentType.tank,
      ),
      status: ServiceClockStatus(
        schedule: ServiceSchedule(
          id: 's1',
          equipmentId: 'e1',
          serviceKindId: 'hydro',
          createdAt: t0,
          updatedAt: t0,
        ),
        kind: kind,
        anchor: t0,
        dueDate: now.add(const Duration(days: 5)),
        severity: ServiceClockSeverity.dueSoon,
        now: now,
      ),
    );
  }

  Widget buildBanner(Trip trip, List<DueClock> alerts) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(body: TripServiceAlertBanner(trip: trip)),
        ),
        GoRoute(
          path: '/equipment/:id',
          builder: (_, _) => const Scaffold(body: Text('EQUIPMENT_PAGE')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        tripServiceAlertsProvider(trip.id).overrideWith((ref) async => alerts),
      ],
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  testWidgets('renders count and opens sheet listing blocking gear', (
    tester,
  ) async {
    await tester.pumpWidget(buildBanner(upcomingTrip(), [hydroAlert()]));
    await tester.pumpAndSettle();

    expect(find.text('1 item needs service before this trip'), findsOneWidget);

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.text('AL80'), findsOneWidget);
    expect(find.textContaining('Hydrostatic test due'), findsOneWidget);
  });

  testWidgets('two blocking clocks on one item still count as 1 item', (
    tester,
  ) async {
    final vipKind = ServiceKind(
      id: 'vip',
      name: 'Visual inspection (VIP)',
      defaultIntervalDays: 365,
      isBuiltIn: true,
      createdAt: t0,
      updatedAt: t0,
    );
    final vipAlert = (
      item: const EquipmentItem(
        id: 'e1',
        name: 'AL80',
        type: EquipmentType.tank,
      ),
      status: ServiceClockStatus(
        schedule: ServiceSchedule(
          id: 's2',
          equipmentId: 'e1',
          serviceKindId: 'vip',
          createdAt: t0,
          updatedAt: t0,
        ),
        kind: vipKind,
        anchor: t0,
        dueDate: now.add(const Duration(days: 3)),
        severity: ServiceClockSeverity.dueSoon,
        now: now,
      ),
    );
    await tester.pumpWidget(
      buildBanner(upcomingTrip(), [hydroAlert(), vipAlert]),
    );
    await tester.pumpAndSettle();

    // Per-clock alerts collapse to distinct equipment items in the label.
    expect(find.text('1 item needs service before this trip'), findsOneWidget);
  });

  testWidgets('overdue alert styles the banner and taps through to the item', (
    tester,
  ) async {
    final overdue = (
      item: const EquipmentItem(
        id: 'e1',
        name: 'AL80',
        type: EquipmentType.tank,
      ),
      status: ServiceClockStatus(
        schedule: ServiceSchedule(
          id: 's1',
          equipmentId: 'e1',
          serviceKindId: 'hydro',
          createdAt: t0,
          updatedAt: t0,
        ),
        kind: ServiceKind(
          id: 'hydro',
          name: 'Hydrostatic test',
          defaultIntervalDays: 1825,
          isBuiltIn: true,
          createdAt: t0,
          updatedAt: t0,
        ),
        anchor: t0,
        dueDate: now.subtract(const Duration(days: 30)),
        severity: ServiceClockSeverity.overdue,
        now: now,
      ),
    );
    await tester.pumpWidget(buildBanner(upcomingTrip(), [overdue]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    // Overdue clocks phrase without a due date.
    expect(find.text('Hydrostatic test overdue'), findsOneWidget);

    // Tapping the row closes the sheet and navigates to the item.
    await tester.tap(find.text('AL80'));
    await tester.pumpAndSettle();
    expect(find.text('EQUIPMENT_PAGE'), findsOneWidget);
  });

  testWidgets(
    'usage-overdue clock with a future dueDate still reads as overdue',
    (tester) async {
      // Overdue on dive count while the date trigger is still in the future.
      final usageOverdue = (
        item: const EquipmentItem(
          id: 'e1',
          name: 'Apeks XTX50',
          type: EquipmentType.regulator,
        ),
        status: ServiceClockStatus(
          schedule: ServiceSchedule(
            id: 's1',
            equipmentId: 'e1',
            serviceKindId: 'reg',
            createdAt: t0,
            updatedAt: t0,
          ),
          kind: ServiceKind(
            id: 'reg',
            name: 'Reg service',
            defaultIntervalDives: 100,
            isBuiltIn: true,
            createdAt: t0,
            updatedAt: t0,
          ),
          anchor: t0,
          dueDate: now.add(const Duration(days: 200)), // future
          divesRemaining: -4,
          severity: ServiceClockSeverity.overdue,
          now: now,
        ),
      );
      await tester.pumpWidget(buildBanner(upcomingTrip(), [usageOverdue]));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(find.text('Reg service overdue'), findsOneWidget);
      // Must not present the future date via the "{kind} due {date}" phrasing.
      expect(find.textContaining('Reg service due'), findsNothing);
    },
  );

  testWidgets('renders nothing when there are no alerts', (tester) async {
    await tester.pumpWidget(buildBanner(upcomingTrip(), const []));
    await tester.pumpAndSettle();
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('renders nothing for past trips', (tester) async {
    final pastTrip = Trip(
      id: 'trip-1',
      name: 'Old trip',
      startDate: now.subtract(const Duration(days: 30)),
      endDate: now.subtract(const Duration(days: 23)),
      createdAt: t0,
      updatedAt: t0,
    );
    await tester.pumpWidget(buildBanner(pastTrip, [hydroAlert()]));
    await tester.pumpAndSettle();
    expect(find.byType(InkWell), findsNothing);
  });
}
