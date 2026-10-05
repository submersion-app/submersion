import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
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
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _MockServiceRecordNotifier
    extends StateNotifier<AsyncValue<List<ServiceRecord>>>
    implements ServiceRecordNotifier {
  _MockServiceRecordNotifier() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The detail page for wishlist gear (#2025).
void main() {
  late String? savedIntlLocale;
  setUp(() {
    savedIntlLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() => Intl.defaultLocale = savedIntlLocale);

  const id = 'wing';

  Future<void> pump(WidgetTester tester, EquipmentItem item) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 2400);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/equipment/$id',
      routes: [
        GoRoute(
          path: '/equipment/:id',
          builder: (context, state) =>
              const EquipmentDetailPage(equipmentId: id),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentItemProvider(id).overrideWith((ref) async => item),
          equipmentDiveCountProvider(id).overrideWith((ref) async => 0),
          equipmentTripCountProvider(id).overrideWith((ref) async => 0),
          serviceRecordNotifierProvider(
            id,
          ).overrideWith((ref) => _MockServiceRecordNotifier()),
          serviceClockStatusesProvider(
            id,
          ).overrideWith((ref) async => const []),
          equipmentComponentsProvider(id).overrideWith((ref) async => const []),
          equipmentExposureTotalsProvider(
            id,
          ).overrideWith((ref) async => EquipmentExposureTotals.empty),
          equipmentConditionProvider(id).overrideWith((ref) async => const []),
          conditionTrendProvider((
            equipmentId: id,
            kind: null,
          )).overrideWith((ref) async => null),
          conditionTrendProvider((
            equipmentId: id,
            kind: ConditionTrendKind.scrubberMinutes,
          )).overrideWith((ref) async => null),
          childEquipmentProvider(id).overrideWith((ref) async => const []),
          observationsForEquipmentProvider(
            id,
          ).overrideWith((ref) async => const []),
          equipmentWorstClockProvider.overrideWith((ref) async => {}),
          equipmentRollupClockProvider.overrideWith((ref) async => {}),
          tagsForEquipmentProvider(id).overrideWith((ref) async => const []),
        ].cast(),
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a wanted item calls its price the expected price', (
    tester,
  ) async {
    await pump(
      tester,
      const EquipmentItem(
        id: id,
        name: 'Dream wing',
        type: EquipmentType.bcd,
        status: EquipmentStatus.wanted,
        isActive: false,
        purchasePrice: 900,
      ),
    );

    expect(find.text('Expected Price'), findsOneWidget);
    expect(find.text('Purchase Price'), findsNothing);
  });

  testWidgets('owned gear keeps the purchase price label', (tester) async {
    await pump(
      tester,
      const EquipmentItem(
        id: id,
        name: 'Wing',
        type: EquipmentType.bcd,
        purchasePrice: 900,
      ),
    );

    expect(find.text('Purchase Price'), findsOneWidget);
    expect(find.text('Expected Price'), findsNothing);
  });

  testWidgets('a wanted item shows no service clocks card', (tester) async {
    await pump(
      tester,
      const EquipmentItem(
        id: id,
        name: 'Dream wing',
        type: EquipmentType.bcd,
        status: EquipmentStatus.wanted,
        isActive: false,
      ),
    );

    // Service clocks are for gear in the kit; schedules kept from when the
    // item was owned come back once it is bought.
    expect(find.text('Service clocks'), findsNothing);
  });

  testWidgets('owned gear keeps its service clocks card', (tester) async {
    await pump(
      tester,
      const EquipmentItem(id: id, name: 'Wing', type: EquipmentType.bcd),
    );

    expect(find.text('Service clocks'), findsOneWidget);
  });
}
