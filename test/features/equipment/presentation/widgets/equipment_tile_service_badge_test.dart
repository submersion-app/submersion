import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/dense_equipment_list_tile.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Branch coverage for the service badge on both equipment list tiles:
/// ledger worst-clock, legacy overdue fallback, days-until, and status.
void main() {
  final t0 = DateTime(2025, 1, 1);

  DueClock worstClock(EquipmentItem item, ServiceClockSeverity severity) => (
    item: item,
    status: ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's1',
        equipmentId: item.id,
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
      dueDate: DateTime(2026, 1, 1),
      severity: severity,
      now: DateTime(2026, 7, 1),
    ),
  );

  Widget wrap(Widget child, {Map<String, DueClock> worst = const {}}) {
    return ProviderScope(
      overrides: [
        equipmentWorstClockProvider.overrideWith((ref) async => worst),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  group('DenseEquipmentListTile', () {
    testWidgets('shows the worst clock kind when the ledger has one', (
      tester,
    ) async {
      const item = EquipmentItem(
        id: 'e1',
        name: 'AL80',
        type: EquipmentType.tank,
      );
      await tester.pumpWidget(
        wrap(
          const DenseEquipmentListTile(item: item),
          worst: {'e1': worstClock(item, ServiceClockSeverity.overdue)},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hydrostatic test'), findsOneWidget);
    });

    testWidgets('dueSoon clock renders in tertiary styling', (tester) async {
      const item = EquipmentItem(
        id: 'e1',
        name: 'AL80',
        type: EquipmentType.tank,
      );
      await tester.pumpWidget(
        wrap(
          const DenseEquipmentListTile(item: item),
          worst: {'e1': worstClock(item, ServiceClockSeverity.dueSoon)},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hydrostatic test'), findsOneWidget);
    });
  });

  group('EquipmentListTile', () {
    testWidgets('worst clock badge names the kind (overdue)', (tester) async {
      const item = EquipmentItem(
        id: 'e1',
        name: 'AL80',
        type: EquipmentType.tank,
      );
      await tester.pumpWidget(
        wrap(
          const EquipmentListTile(item: item),
          worst: {'e1': worstClock(item, ServiceClockSeverity.overdue)},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hydrostatic test overdue'), findsOneWidget);
    });

    testWidgets('worst clock badge names the kind (due soon)', (tester) async {
      const item = EquipmentItem(
        id: 'e1',
        name: 'AL80',
        type: EquipmentType.tank,
      );
      await tester.pumpWidget(
        wrap(
          const EquipmentListTile(item: item),
          worst: {'e1': worstClock(item, ServiceClockSeverity.dueSoon)},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hydrostatic test'), findsOneWidget);
    });

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

    testWidgets('non-active status renders when nothing is due', (
      tester,
    ) async {
      const item = EquipmentItem(
        id: 'e1',
        name: 'Shelf Queen',
        type: EquipmentType.regulator,
        status: EquipmentStatus.retired,
      );
      await tester.pumpWidget(wrap(const EquipmentListTile(item: item)));
      await tester.pumpAndSettle();

      expect(find.text('Retired'), findsOneWidget);
    });
  });
}
