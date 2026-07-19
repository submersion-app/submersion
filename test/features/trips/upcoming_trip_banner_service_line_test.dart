import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/widgets/upcoming_trip_banner.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final now = DateTime.now();
  final t0 = DateTime(2025, 1, 1);

  Trip trip() => Trip(
    id: 'trip-1',
    name: 'Bonaire',
    startDate: now.add(const Duration(days: 10)),
    endDate: now.add(const Duration(days: 17)),
    createdAt: t0,
    updatedAt: t0,
  );

  DueClock alert(String scheduleId) => (
    item: const EquipmentItem(id: 'e1', name: 'AL80', type: EquipmentType.tank),
    status: ServiceClockStatus(
      schedule: ServiceSchedule(
        id: scheduleId,
        equipmentId: 'e1',
        serviceKindId: scheduleId,
        createdAt: t0,
        updatedAt: t0,
      ),
      kind: ServiceKind(
        id: scheduleId,
        name: 'Kind $scheduleId',
        defaultIntervalDays: 365,
        isBuiltIn: true,
        createdAt: t0,
        updatedAt: t0,
      ),
      anchor: t0,
      dueDate: now.add(const Duration(days: 5)),
      severity: ServiceClockSeverity.dueSoon,
      now: now,
    ),
  );

  Widget buildBanner(
    List<DueClock> alerts, {
    ({int done, int total})? progress,
  }) {
    return ProviderScope(
      overrides: [
        tripServiceAlertsProvider('trip-1').overrideWith((ref) async => alerts),
        tripChecklistProgressProvider(
          'trip-1',
        ).overrideWith((ref) async => progress ?? (done: 0, total: 0)),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: UpcomingTripBanner(trip: trip())),
      ),
    );
  }

  testWidgets('shows a service line collapsing clocks to distinct items', (
    tester,
  ) async {
    // Two blocking clocks on the SAME item -> "1 item".
    await tester.pumpWidget(buildBanner([alert('hydro'), alert('vip')]));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.build), findsOneWidget);
    expect(find.text('1 item needs service before this trip'), findsOneWidget);
  });

  testWidgets('no service line when nothing blocks the trip', (tester) async {
    await tester.pumpWidget(buildBanner(const []));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.build), findsNothing);
    expect(
      find.byIcon(Icons.schedule),
      findsOneWidget,
    ); // countdown still shows
  });

  testWidgets('checklist progress renders alongside the service line', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildBanner([alert('hydro')], progress: (done: 2, total: 5)),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.build), findsOneWidget);
    expect(find.textContaining('2'), findsWidgets);
  });
}
