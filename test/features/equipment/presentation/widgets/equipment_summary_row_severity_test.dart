import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_summary_widget.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Every Service Due row used to take the section's worst severity, so an
/// overdue item and a due-soon item read identically. Each row now carries
/// its own, which only means anything if an item with several clocks keeps
/// the worst of them (#2260).
void main() {
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Cold water reg',
    type: EquipmentType.regulator,
  );
  const fins = EquipmentItem(
    id: 'fins',
    name: 'Jets',
    type: EquipmentType.fins,
  );

  DueClock clock(
    EquipmentItem item,
    ServiceClockSeverity severity,
    String kindName,
  ) {
    final t0 = DateTime(2026, 1, 1);
    return (
      item: item,
      status: ServiceClockStatus(
        schedule: ServiceSchedule(
          id: 's-${item.id}-$kindName',
          equipmentId: item.id,
          serviceKindId: kindName,
          createdAt: t0,
          updatedAt: t0,
        ),
        kind: ServiceKind(
          id: kindName,
          name: kindName,
          createdAt: t0,
          updatedAt: t0,
        ),
        anchor: t0,
        dueDate: DateTime.now().add(const Duration(days: 5)),
        severity: severity,
        now: DateTime.now(),
      ),
    );
  }

  Future<void> pumpSummary(
    WidgetTester tester, {
    required List<EquipmentItem> serviceDue,
    required List<DueClock> dueClocks,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final settings = MockSettingsNotifier();
    final overrides = await getBaseOverrides(settingsNotifier: settings);
    final router = GoRouter(
      initialLocation: '/equipment',
      routes: [
        GoRoute(
          path: '/equipment',
          builder: (context, state) => const EquipmentSummaryWidget(),
        ),
      ],
    );

    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          allEquipmentProvider.overrideWith((ref) async => serviceDue),
          // A family since #2259 (keyed by ServiceDueFilter); override every
          // argument, as the summary's own currency test does.
          serviceDueEquipmentProvider.overrideWith(
            (ref, _) async => serviceDue,
          ),
          dueClocksProvider.overrideWith((ref) async => dueClocks),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an item with two clocks reports the worse one', (tester) async {
    // dueClocksProvider yields worst-first, so a map comprehension keyed by
    // item id silently kept the LAST, least urgent, entry. The row then
    // said "due in 5d" for gear that was actually overdue.
    await pumpSummary(
      tester,
      serviceDue: const [reg],
      dueClocks: [
        clock(reg, ServiceClockSeverity.overdue, 'Annual service'),
        clock(reg, ServiceClockSeverity.dueSoon, 'Hydrostatic test'),
      ],
    );

    expect(find.textContaining('Annual service overdue'), findsOneWidget);
    expect(find.textContaining('Hydrostatic test due'), findsNothing);
  });

  testWidgets('rows with different severities no longer read alike', (
    tester,
  ) async {
    await pumpSummary(
      tester,
      serviceDue: const [reg, fins],
      dueClocks: [
        clock(reg, ServiceClockSeverity.overdue, 'Annual service'),
        clock(fins, ServiceClockSeverity.dueSoon, 'Strap check'),
      ],
    );

    expect(find.textContaining('Annual service overdue'), findsOneWidget);
    expect(find.textContaining('Strap check due'), findsOneWidget);
  });
}
