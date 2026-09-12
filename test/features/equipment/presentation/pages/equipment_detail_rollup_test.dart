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
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The same fake `equipment_detail_service_test.dart` keeps private: the
/// history section needs a notifier that never touches the database.
class _MockServiceRecordNotifier
    extends StateNotifier<AsyncValue<List<ServiceRecord>>>
    implements ServiceRecordNotifier {
  _MockServiceRecordNotifier() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  final t0 = DateTime(2025, 1, 1);
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Cold water reg',
    type: EquipmentType.regulator,
  );

  RollupClock overdueOnHose() => (
    ownerId: 'hose',
    ownerName: 'Necklace hose',
    status: ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's1',
        equipmentId: 'hose',
        serviceKindId: 'hose-swap',
        createdAt: t0,
        updatedAt: t0,
      ),
      kind: ServiceKind(
        id: 'hose-swap',
        name: 'Hose replacement',
        defaultIntervalDays: 1825,
        isBuiltIn: false,
        createdAt: t0,
        updatedAt: t0,
      ),
      anchor: t0,
      dueDate: DateTime(2026, 1, 1),
      severity: ServiceClockSeverity.overdue,
      now: DateTime(2026, 7, 1),
    ),
  );

  Future<void> pump(
    WidgetTester tester,
    Map<String, RollupClock> rollup,
  ) async {
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
          equipmentItemProvider('reg').overrideWith((ref) async => reg),
          equipmentDiveCountProvider('reg').overrideWith((ref) async => 0),
          equipmentTripCountProvider('reg').overrideWith((ref) async => 0),
          serviceRecordNotifierProvider(
            'reg',
          ).overrideWith((ref) => _MockServiceRecordNotifier()),
          serviceClockStatusesProvider(
            'reg',
          ).overrideWith((ref) async => const []),
          equipmentComponentsProvider(
            'reg',
          ).overrideWith((ref) async => const []),
          observationsForEquipmentProvider(
            'reg',
          ).overrideWith((ref) async => const []),
          equipmentWorstClockProvider.overrideWith((ref) async => {}),
          equipmentRollupClockProvider.overrideWith((ref) async => rollup),
        ].cast(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EquipmentDetailPage(equipmentId: 'reg'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the header lights when a part is overdue', (tester) async {
    await pump(tester, {'reg': overdueOnHose()});
    expect(find.text('Service is overdue!'), findsOneWidget);
  });

  testWidgets('the header stays calm when nothing in the subtree is due', (
    tester,
  ) async {
    await pump(tester, const {});
    expect(find.text('Service is overdue!'), findsNothing);
  });
}
