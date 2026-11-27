import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/cylinder_passports/presentation/pages/passport_page.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/gear_item_edit_save_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/gear_passports/presentation/pages/gear_passport_page.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_service_sitting.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_clocks_card.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';
import '../../../equipment/presentation/pages/equipment_detail_page_unlock_harness.dart';

/// The gear passport is a satellite page of its item behind the phase 3
/// switch (issue #4527, plan 7).
void main() {
  final l = AppLocalizationsEn();
  final at = DateTime(2026, 3, 3);

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO service_kinds (id, name, default_interval_days, "
      "created_at, updated_at) VALUES ('k-hose', 'Hose swap', 730, 0, 0)",
    );
    addTearDown(SyncCoordinator.reset);
  });
  tearDown(tearDownTestDatabase);

  Future<FakeGearItemSave?> pump(
    WidgetTester tester,
    EquipmentItem item,
  ) async {
    await tester.runAsync(() => EquipmentRepository().createEquipment(item));
    tester.view.physicalSize = const Size(600, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final stored = StateProvider<EquipmentItem?>((ref) => item);
    FakeGearItemSave? save;
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          equipmentItemProvider(
            item.id,
          ).overrideWith((ref) async => ref.watch(stored)),
          passportIdProvider(item.id).overrideWith((ref) async => 'pp'),
          serviceClockStatusesProvider(
            item.id,
          ).overrideWith((ref) async => const <ServiceClockStatus>[]),
          serviceRecordsForEquipmentProvider(item.id).overrideWith(
            (ref) async => [
              ServiceRecord(
                id: 'r1',
                equipmentId: item.id,
                serviceCategory: ServiceCategory.annual,
                serviceDate: at,
                createdAt: at,
                updatedAt: at,
              ),
            ],
          ),
          serviceRecordNotifierProvider(
            item.id,
          ).overrideWith((ref) => CountingServiceRecords()),
          gearItemEditSaveServiceProvider.overrideWith(
            (ref) => save = FakeGearItemSave(ref.watch(stored.notifier)),
          ),
        ],
        child: GearPassportPage(equipmentId: item.id),
      ),
    );
    await tester.pumpAndSettle();
    return save;
  }

  testWidgets('opened alone it opens locked, and no tap writes', (
    tester,
  ) async {
    final save = await pump(tester, apex);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text(l.passport_tag_linkExisting), findsNothing);
    expect(find.byKey(const Key('passport-trip-assign')), findsNothing);
    expect(save?.calls ?? const [], isEmpty);
  });

  testWidgets('See all is hidden while the passport holds its own sitting', (
    tester,
  ) async {
    await pump(tester, apex);
    expect(find.text(l.gearPassport_recent_seeAll), findsOneWidget);

    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();

    expect(find.text(l.gearPassport_recent_seeAll), findsNothing);
  });

  testWidgets('the closed Service clocks card shows the clocks the sitting '
      'holds (issue #5042)', (tester) async {
    await pump(tester, apex);
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    final host =
        tester.state(find.byType(GearPassportPage))
            as RecordEditHost<GearPassportPage, EquipmentItem>;
    final session = host.editController.session!;
    await tester.runAsync(() => gearItemClocksList.currentOrRead(session));
    expect(find.text('Hose swap'), findsNothing);

    holdClock(
      session,
      ServiceSchedule(
        id: '',
        equipmentId: apex.id,
        serviceKindId: 'k-hose',
        createdAt: at,
        updatedAt: at,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(ServiceClocksCard),
        matching: find.text('Hose swap'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a tank forwards to the cylinder passport', (tester) async {
    await pump(
      tester,
      const EquipmentItem(id: 'c1', name: 'Left 12', type: EquipmentType.tank),
    );

    expect(find.byType(PassportPage), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });
}
