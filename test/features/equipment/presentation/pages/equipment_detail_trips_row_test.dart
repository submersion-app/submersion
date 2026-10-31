import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/condition_trend.dart';
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

/// Stands in for the trip filter the Trips row reads: a change to it rebuilds
/// the count through a dependency, as a dive write does.
final _dependency = StateProvider<int>((ref) => 0);

/// The Trips row refreshes through the trip filter it counts (issue #4016), so
/// every dive write reloads it. It keeps its figure while that runs.
void main() {
  const equipment = EquipmentItem(
    id: 'equip-trips',
    name: 'First stage',
    type: EquipmentType.regulator,
  );

  testWidgets('the Trips row keeps its figure through a reload', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 1600);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          equipmentItemProvider(
            equipment.id,
          ).overrideWith((ref) async => equipment),
          equipmentDiveCountProvider(
            equipment.id,
          ).overrideWith((ref) async => 3),
          equipmentDiveTimeProvider(
            equipment.id,
          ).overrideWith((ref) async => 0),
          equipmentTripCountProvider(equipment.id).overrideWith((ref) async {
            ref.watch(_dependency);
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return 1;
          }),
          equipmentComponentsProvider(
            equipment.id,
          ).overrideWith((ref) async => const []),
          equipmentPartOfProvider(
            equipment.id,
          ).overrideWith((ref) async => const []),
          equipmentExposureTotalsProvider(
            equipment.id,
          ).overrideWith((ref) async => EquipmentExposureTotals.empty),
          equipmentConditionProvider(
            equipment.id,
          ).overrideWith((ref) async => const []),
          conditionTrendProvider((
            equipmentId: equipment.id,
            kind: null,
          )).overrideWith((ref) async => null),
          conditionTrendProvider((
            equipmentId: equipment.id,
            kind: ConditionTrendKind.scrubberMinutes,
          )).overrideWith((ref) async => null),
          childEquipmentProvider(
            equipment.id,
          ).overrideWith((ref) async => const []),
          observationsForEquipmentProvider(
            equipment.id,
          ).overrideWith((ref) async => const []),
          equipmentWorstClockProvider.overrideWith((ref) async => {}),
          serviceRecordNotifierProvider(
            equipment.id,
          ).overrideWith((ref) => _MockServiceRecordNotifier()),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EquipmentDetailPage(equipmentId: equipment.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 trip'), findsOneWidget);

    ProviderScope.containerOf(
      tester.element(find.byType(EquipmentDetailPage)),
    ).read(_dependency.notifier).state++;
    await tester.pump();

    expect(find.text('1 trip'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('1 trip'), findsOneWidget);
  });
}

class _MockServiceRecordNotifier
    extends StateNotifier<AsyncValue<List<ServiceRecord>>>
    implements ServiceRecordNotifier {
  _MockServiceRecordNotifier() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
