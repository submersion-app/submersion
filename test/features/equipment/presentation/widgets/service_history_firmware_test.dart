import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_history_section.dart';
import 'package:submersion/features/firmware/domain/firmware_catalogue.dart';
import 'package:submersion/features/firmware/domain/firmware_status.dart';
import 'package:submersion/features/firmware/presentation/providers/firmware_status_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Firmware updates in an item's service history (issue #5104): a row names
/// the version it installed, and a version the catalogue ranks below the one
/// before it reads as a change.
void main() {
  const equipmentId = 'e1';

  ServiceRecord firmware(String id, String version, DateTime when) =>
      ServiceRecord(
        id: id,
        equipmentId: equipmentId,
        serviceCategory: ServiceCategory.firmwareUpdate,
        serviceDate: when,
        firmwareVersion: version,
        createdAt: when,
        updatedAt: when,
      );

  Future<void> pump(
    WidgetTester tester,
    List<ServiceRecord> records, {
    FirmwareStatus? status,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 1200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          serviceKindsProvider.overrideWith((ref) async => const []),
          allServiceKindsByIdProvider.overrideWith((ref) async => const {}),
          serviceRecordNotifierProvider(
            equipmentId,
          ).overrideWith((ref) => _Records(records)),
          equipmentItemProvider(equipmentId).overrideWith(
            (ref) async => const EquipmentItem(
              id: equipmentId,
              name: 'Perdix 2',
              type: EquipmentType.computer,
            ),
          ),
          if (status != null)
            firmwareStatusesProvider.overrideWith(
              (ref) async => {equipmentId: status},
            ),
        ].cast(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ServiceHistorySection(equipmentId: equipmentId),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a firmware record names the version it installed', (
    tester,
  ) async {
    await pump(tester, [firmware('f1', 'V95', DateTime(2026, 10, 1))]);
    expect(find.text('Firmware updated to V95'), findsOneWidget);
  });

  testWidgets('a step back down the catalogue reads as a change', (
    tester,
  ) async {
    const model = FirmwareModel(
      id: 'm',
      manufacturer: 'Shearwater',
      model: 'Perdix 2',
      equipmentTypes: {EquipmentType.computer},
      releases: [
        FirmwareRelease(version: 'V95'),
        FirmwareRelease(version: 'V94'),
      ],
    );
    await pump(tester, [
      firmware('f2', 'V94', DateTime(2026, 11, 1)),
      firmware('f1', 'V95', DateTime(2026, 10, 1)),
    ], status: const FirmwareUpToDate(model));
    expect(find.text('Firmware changed to V94'), findsOneWidget);
    expect(find.text('Firmware updated to V95'), findsOneWidget);
  });
}

class _Records extends StateNotifier<AsyncValue<List<ServiceRecord>>>
    implements ServiceRecordNotifier {
  _Records(List<ServiceRecord> records) : super(AsyncValue.data(records));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
