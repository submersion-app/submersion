import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_clocks_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// ServiceDueEngine derives hours-based clocks by summing logged dive
/// duration, which approximates rebreather loop time but excludes pre-breathe
/// and surface loop time. A diver trusting a scrubber clock has to be told
/// what it counts.
void main() {
  final t0 = DateTime(2025, 1, 1);
  final now = DateTime(2026, 8, 5);

  final scrubber = ServiceKind(
    id: 'scrubber-repack',
    name: 'Scrubber repack',
    applicableTypes: const [EquipmentType.rebreather],
    defaultIntervalHours: 3.0,
    autoAttach: true,
    isBuiltIn: true,
    createdAt: t0,
    updatedAt: t0,
  );
  final annual = ServiceKind(
    id: 'rebreather-annual',
    name: 'Rebreather annual service',
    applicableTypes: const [EquipmentType.rebreather],
    defaultIntervalDays: 365,
    autoAttach: true,
    isBuiltIn: true,
    createdAt: t0,
    updatedAt: t0,
  );

  ServiceSchedule sched(String kindId, {double? hours}) => ServiceSchedule(
    id: 's-$kindId',
    equipmentId: 'rb1',
    serviceKindId: kindId,
    intervalHours: hours,
    createdAt: t0,
    updatedAt: t0,
  );

  Widget buildCard({required bool includeHoursClock}) {
    final statuses = <ServiceClockStatus>[
      ServiceClockStatus(
        schedule: sched('rebreather-annual'),
        kind: annual,
        anchor: t0,
        dueDate: DateTime(2026, 12, 1),
        severity: ServiceClockSeverity.ok,
        now: now,
      ),
      if (includeHoursClock)
        ServiceClockStatus(
          schedule: sched('scrubber-repack', hours: 3.0),
          kind: scrubber,
          anchor: t0,
          hoursSinceAnchor: 1.2,
          hoursRemaining: 1.8,
          severity: ServiceClockSeverity.ok,
          now: now,
        ),
    ];

    return ProviderScope(
      overrides: [
        serviceClockStatusesProvider(
          'rb1',
        ).overrideWith((ref) async => statuses),
        serviceSchedulesForEquipmentProvider('rb1').overrideWith(
          (ref) async => [
            sched('rebreather-annual'),
            if (includeHoursClock) sched('scrubber-repack', hours: 3.0),
          ],
        ),
        serviceKindsProvider.overrideWith((ref) async => [scrubber, annual]),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ServiceClocksCard(
              equipmentId: 'rb1',
              equipmentType: EquipmentType.rebreather,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('an hours-based clock captions where its hours come from', (
    tester,
  ) async {
    await tester.pumpWidget(buildCard(includeHoursClock: true));
    await tester.pumpAndSettle();

    expect(find.text('Scrubber repack'), findsOneWidget);
    expect(find.text('Counted from logged dive time'), findsOneWidget);
  });

  testWidgets('a date-only clock shows no hours caption', (tester) async {
    await tester.pumpWidget(buildCard(includeHoursClock: false));
    await tester.pumpAndSettle();

    expect(find.text('Rebreather annual service'), findsOneWidget);
    expect(find.text('Counted from logged dive time'), findsNothing);
  });
}
