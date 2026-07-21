import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  final t0 = DateTime(2025, 1, 1);

  ServiceClockStatus overdueStatus(String eid) => ServiceClockStatus(
    schedule: ServiceSchedule(
      id: 's-$eid',
      equipmentId: eid,
      serviceKindId: 'regulator-service',
      createdAt: t0,
      updatedAt: t0,
    ),
    kind: ServiceKind(
      id: 'regulator-service',
      name: 'Regulator service',
      defaultIntervalDays: 365,
      isBuiltIn: true,
      createdAt: t0,
      updatedAt: t0,
    ),
    anchor: t0,
    dueDate: DateTime(2025, 6, 1),
    severity: ServiceClockSeverity.overdue,
    now: DateTime(2026, 1, 1),
  );

  Future<void> pumpDetail(
    WidgetTester tester, {
    required EquipmentItem item,
    required List<ServiceClockStatus> clockStatuses,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 1600);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentItemProvider(item.id).overrideWith((ref) async => item),
          equipmentDiveCountProvider(item.id).overrideWith((ref) async => 0),
          equipmentTripCountProvider(item.id).overrideWith((ref) async => 0),
          serviceRecordNotifierProvider(
            item.id,
          ).overrideWith((ref) => _MockServiceRecordNotifier()),
          serviceRecordTotalCostProvider(
            item.id,
          ).overrideWith((ref) async => 0.0),
          serviceClockStatusesProvider(
            item.id,
          ).overrideWith((ref) async => clockStatuses),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EquipmentDetailPage(equipmentId: item.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('overdue banner follows clocks, not the legacy interval', (
    tester,
  ) async {
    final legacyOverdue = EquipmentItem(
      id: 'e1',
      name: 'Old Reg',
      type: EquipmentType.regulator,
      lastServiceDate: DateTime.now().subtract(const Duration(days: 400)),
      serviceIntervalDays: 365, // legacy getter says overdue
    );
    await pumpDetail(tester, item: legacyOverdue, clockStatuses: const []);
    expect(find.text('Service is overdue!'), findsNothing);
  });

  testWidgets('overdue banner shows when a clock is overdue', (tester) async {
    const item = EquipmentItem(
      id: 'e1',
      name: 'Reg',
      type: EquipmentType.regulator,
    );
    await pumpDetail(tester, item: item, clockStatuses: [overdueStatus('e1')]);
    expect(find.text('Service is overdue!'), findsOneWidget);
  });

  testWidgets('the overflow menu no longer offers Mark as Serviced', (
    tester,
  ) async {
    const item = EquipmentItem(
      id: 'e1',
      name: 'Reg',
      type: EquipmentType.regulator,
    );
    await pumpDetail(tester, item: item, clockStatuses: const []);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Mark as Serviced'), findsNothing);
  });
}

class _MockServiceRecordNotifier
    extends StateNotifier<AsyncValue<List<ServiceRecord>>>
    implements ServiceRecordNotifier {
  _MockServiceRecordNotifier() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
