import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
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
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Stands in for the trip filter the Trips row reads: a change to it rebuilds
/// the count through a dependency, as a dive write does.
final _dependency = StateProvider<int>((ref) => 0);

/// The item page's count rows describe the lists they open (issue #4016).
void main() {
  const equipment = EquipmentItem(
    id: 'equip-trips',
    name: 'First stage',
    type: EquipmentType.regulator,
  );

  Future<ProviderContainer> pumpPage(WidgetTester tester) async {
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
          // In table mode a wide page stays put, instead of redirecting to the
          // master-detail list.
          equipmentListViewModeProvider.overrideWith(
            (ref) => ListViewMode.table,
          ),
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
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            initialLocation: '/item',
            routes: [
              GoRoute(
                path: '/item',
                builder: (context, state) =>
                    EquipmentDetailPage(equipmentId: equipment.id),
              ),
              GoRoute(
                path: '/dives',
                builder: (context, state) =>
                    const Scaffold(body: Text('DIVE_LIST')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(EquipmentDetailPage)),
    );
  }

  testWidgets('the Dives row opens the dives it counts', (tester) async {
    final container = await pumpPage(tester);

    await tester.tap(find.text('3 dives'));
    await tester.pumpAndSettle();

    expect(find.text('DIVE_LIST'), findsOneWidget);
    expect(
      container.read(diveFilterProvider),
      DiveFilterState.itemUse(equipment.id),
    );
  });

  // The row refreshes through the trip filter it counts, so every dive write
  // reloads it.
  testWidgets('the Trips row keeps its figure through a reload', (
    tester,
  ) async {
    final container = await pumpPage(tester);
    expect(find.text('1 trip'), findsOneWidget);

    container.read(_dependency.notifier).state++;
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
