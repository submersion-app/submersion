import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
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
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/equipment_media_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _NoServiceRecords extends StateNotifier<AsyncValue<List<ServiceRecord>>>
    implements ServiceRecordNotifier {
  _NoServiceRecords() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The gear page's Seller row (issue #5140): a buddy or dive centre the
/// diver can open is a link to it; anything else is the name as text.
void main() {
  late String? savedIntlLocale;
  setUp(() {
    savedIntlLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() => Intl.defaultLocale = savedIntlLocale);

  final t = DateTime(2025);
  final anna = Buddy(id: 'b1', name: 'Anna B.', createdAt: t, updatedAt: t);
  final anchor = DiveCenter(
    id: 'c1',
    name: 'Anchor Dive',
    createdAt: t,
    updatedAt: t,
  );

  EquipmentItem item({String? buddy, String? centre, String? retailer}) =>
      EquipmentItem(
        id: 'e9',
        name: 'MK25 EVO',
        type: EquipmentType.regulator,
        sellerBuddyId: buddy,
        sellerDiveCenterId: centre,
        attributes: [
          if (retailer != null)
            EquipmentAttribute.curated(
              equipmentId: 'e9',
              key: 'retailer',
              valueText: retailer,
            ),
        ],
      );

  Future<void> pump(WidgetTester tester, EquipmentItem equipment) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 2000);
    addTearDown(tester.view.reset);
    final id = equipment.id;
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/equipment/$id',
      routes: [
        GoRoute(
          path: '/equipment/:id',
          builder: (context, state) =>
              EquipmentDetailPage(equipmentId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/buddies/:id',
          builder: (context, state) =>
              Text('BUDDY ${state.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/dive-centers/:id',
          builder: (context, state) =>
              Text('CENTER ${state.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          allBuddiesProvider.overrideWith((ref) async => [anna]),
          allDiveCentersProvider.overrideWith((ref) async => [anchor]),
          equipmentItemProvider(id).overrideWith((ref) async => equipment),
          equipmentDiveCountProvider(id).overrideWith((ref) async => 0),
          equipmentTripCountProvider(id).overrideWith((ref) async => 0),
          equipmentComponentsProvider(id).overrideWith((ref) async => const []),
          equipmentPartOfProvider(id).overrideWith((ref) async => const []),
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
          serviceRecordNotifierProvider(
            id,
          ).overrideWith((ref) => _NoServiceRecords()),
          mediaForEquipmentProvider(
            id,
          ).overrideWith((ref) async => const <MediaItem>[]),
        ].cast(),
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final link = find.byKey(const ValueKey('equipment-detail-seller-link'));

  testWidgets('a linked buddy shows its current name and opens it', (
    tester,
  ) async {
    await pump(tester, item(buddy: 'b1', retailer: 'Anna'));

    expect(find.text('Seller'), findsOneWidget);
    expect(find.text('Anna B.'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);

    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('BUDDY b1'), findsOneWidget);
  });

  testWidgets('a linked dive centre opens it', (tester) async {
    await pump(tester, item(centre: 'c1', retailer: 'Anchor'));

    expect(find.text('Anchor Dive'), findsOneWidget);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('CENTER c1'), findsOneWidget);
  });

  testWidgets('a typed seller is plain text', (tester) async {
    await pump(tester, item(retailer: 'Dive Shop Ltd'));

    expect(find.text('Dive Shop Ltd'), findsOneWidget);
    expect(link, findsNothing);
  });

  testWidgets('a link this profile cannot open is plain text', (tester) async {
    // Another profile's buddy, on an item shared with this one.
    await pump(tester, item(buddy: 'b9', retailer: 'Lars Holm'));

    expect(find.text('Lars Holm'), findsOneWidget);
    expect(link, findsNothing);
  });

  testWidgets('no seller draws no row', (tester) async {
    await pump(tester, item());
    expect(find.text('Seller'), findsNothing);
  });
}
