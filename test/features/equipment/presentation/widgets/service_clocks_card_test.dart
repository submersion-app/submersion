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

void main() {
  final t0 = DateTime(2025, 1, 1);
  final now = DateTime(2026, 7, 16);

  final hydro = ServiceKind(
    id: 'hydro',
    name: 'Hydrostatic test',
    applicableTypes: const [EquipmentType.tank],
    defaultIntervalDays: 1825,
    autoAttach: true,
    isBuiltIn: true,
    createdAt: t0,
    updatedAt: t0,
  );
  final vip = ServiceKind(
    id: 'vip',
    name: 'Visual inspection (VIP)',
    applicableTypes: const [EquipmentType.tank],
    defaultIntervalDays: 365,
    autoAttach: true,
    isBuiltIn: true,
    createdAt: t0,
    updatedAt: t0,
  );
  final o2 = ServiceKind(
    id: 'o2-clean',
    name: 'O2 clean',
    applicableTypes: const [EquipmentType.tank],
    defaultIntervalDays: 365,
    isBuiltIn: true,
    createdAt: t0,
    updatedAt: t0,
  );

  ServiceSchedule sched(String kindId) => ServiceSchedule(
    id: 's-$kindId',
    equipmentId: 'e1',
    serviceKindId: kindId,
    createdAt: t0,
    updatedAt: t0,
  );

  ServiceClockStatus status(
    ServiceKind kind,
    ServiceClockSeverity severity,
    DateTime dueDate,
  ) => ServiceClockStatus(
    schedule: sched(kind.id),
    kind: kind,
    anchor: t0,
    dueDate: dueDate,
    severity: severity,
    now: now,
  );

  Widget buildCard() {
    return ProviderScope(
      overrides: [
        serviceClockStatusesProvider('e1').overrideWith(
          (ref) async => [
            status(hydro, ServiceClockSeverity.overdue, DateTime(2026, 1, 1)),
            status(vip, ServiceClockSeverity.ok, DateTime(2027, 5, 1)),
          ],
        ),
        serviceSchedulesForEquipmentProvider(
          'e1',
        ).overrideWith((ref) async => [sched('hydro'), sched('vip')]),
        serviceKindsProvider.overrideWith((ref) async => [hydro, vip, o2]),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ServiceClocksCard(
              equipmentId: 'e1',
              equipmentType: EquipmentType.tank,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders one row per clock with trigger text', (tester) async {
    await tester.pumpWidget(buildCard());
    await tester.pumpAndSettle();

    expect(find.text('Hydrostatic test'), findsOneWidget);
    expect(find.text('Visual inspection (VIP)'), findsOneWidget);
    expect(find.textContaining('Overdue since'), findsOneWidget);
    expect(find.textContaining('Due '), findsOneWidget);
  });

  testWidgets('Add clock sheet lists only unattached kinds', (tester) async {
    await tester.pumpWidget(buildCard());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add clock'));
    await tester.pumpAndSettle();

    expect(find.text('O2 clean'), findsOneWidget);
    // hydro is already attached: only the card row shows it, not the sheet.
    expect(find.text('Hydrostatic test'), findsOneWidget);
    expect(find.text('Manage service types'), findsOneWidget);
  });
}
