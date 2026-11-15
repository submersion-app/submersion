import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/condition_trend.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_exposure_totals.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/condition_trend_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_exposure_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The Details card reads a cylinder's cubic feet at its own working
/// pressure (issue #4534), not at the 200 bar the app assumes without one.
void main() {
  late String? savedIntlLocale;
  setUp(() {
    savedIntlLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() => Intl.defaultLocale = savedIntlLocale);

  const tank = EquipmentItem(
    id: 'al80',
    name: 'AL80',
    type: EquipmentType.tank,
    attributes: [
      EquipmentAttribute(
        id: 'v',
        equipmentId: 'al80',
        key: EquipmentAttrKeys.volumeL,
        valueNum: 11.1,
      ),
      EquipmentAttribute(
        id: 'p',
        equipmentId: 'al80',
        key: EquipmentAttrKeys.workingPressureBar,
        valueNum: 206.843,
      ),
    ],
  );

  testWidgets('an imperial diver reads the rated capacity, not an estimate', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 1600);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final settings = MockSettingsNotifier();
    await settings.setVolumeUnit(VolumeUnit.cubicFeet);
    final overrides = await getBaseOverrides(settingsNotifier: settings);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          equipmentItemProvider(tank.id).overrideWith((ref) async => tank),
          equipmentDiveCountProvider(tank.id).overrideWith((ref) async => 0),
          equipmentDiveTimeProvider(tank.id).overrideWith((ref) async => 0),
          equipmentTripCountProvider(tank.id).overrideWith((ref) async => 0),
          equipmentComponentsProvider(
            tank.id,
          ).overrideWith((ref) async => const []),
          equipmentPartOfProvider(
            tank.id,
          ).overrideWith((ref) async => const []),
          equipmentExposureTotalsProvider(
            tank.id,
          ).overrideWith((ref) async => EquipmentExposureTotals.empty),
          equipmentConditionProvider(
            tank.id,
          ).overrideWith((ref) async => const []),
          conditionTrendProvider((
            equipmentId: tank.id,
            kind: null,
          )).overrideWith((ref) async => null),
          conditionTrendProvider((
            equipmentId: tank.id,
            kind: ConditionTrendKind.scrubberMinutes,
          )).overrideWith((ref) async => null),
          childEquipmentProvider(tank.id).overrideWith((ref) async => const []),
          observationsForEquipmentProvider(
            tank.id,
          ).overrideWith((ref) async => const []),
          equipmentWorstClockProvider.overrideWith((ref) async => {}),
          serviceRecordNotifierProvider(
            tank.id,
          ).overrideWith((ref) => _MockServiceRecordNotifier()),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EquipmentDetailPage(equipmentId: tank.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('77 cuft'), findsWidgets);
    expect(find.text('~78 cuft'), findsNothing);
  });
}

class _MockServiceRecordNotifier
    extends StateNotifier<AsyncValue<List<ServiceRecord>>>
    implements ServiceRecordNotifier {
  _MockServiceRecordNotifier() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
