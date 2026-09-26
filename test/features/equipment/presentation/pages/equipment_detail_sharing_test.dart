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
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_share.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _MockServiceRecordNotifier
    extends StateNotifier<AsyncValue<List<ServiceRecord>>>
    implements ServiceRecordNotifier {
  _MockServiceRecordNotifier() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Sharing on the equipment detail page (issue #2046): the owner manages
/// shares; a profile the item is shared with sees who owns it and cannot
/// delete it.
void main() {
  late String? savedIntlLocale;
  setUp(() {
    savedIntlLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() => Intl.defaultLocale = savedIntlLocale);

  const id = 'wing';
  const wing = EquipmentItem(
    id: id,
    diverId: 'owner',
    name: 'Wing',
    type: EquipmentType.bcd,
  );
  final now = DateTime(2026);
  final bill = Diver(id: 'owner', name: 'Bill', createdAt: now, updatedAt: now);
  final anna = Diver(id: 'wife', name: 'Anna', createdAt: now, updatedAt: now);
  final shares = [
    EquipmentShare(id: 's1', equipmentId: id, diverId: 'wife', createdAt: now),
  ];
  const overflow = ValueKey('equipment-detail-overflow');

  Future<void> pump(
    WidgetTester tester, {
    required String activeDiverId,
    List<Diver>? divers,
  }) async {
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
          equipmentItemProvider(id).overrideWith((ref) async => wing),
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
          allDiversProvider.overrideWith((ref) async => divers ?? [bill, anna]),
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) async => activeDiverId,
          ),
          equipmentSharesProvider(id).overrideWith((ref) async => shares),
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

  testWidgets('the owner sees Shared with and the page menu', (tester) async {
    await pump(tester, activeDiverId: 'owner');
    expect(find.text('Shared with'), findsOneWidget);
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Owned by'), findsNothing);
    expect(find.byKey(overflow), findsOneWidget);
  });

  testWidgets('a sharee sees Owned by and no page menu', (tester) async {
    await pump(tester, activeDiverId: 'wife');
    expect(find.text('Owned by'), findsOneWidget);
    expect(find.text('Bill'), findsOneWidget);
    expect(find.byKey(overflow), findsNothing);
  });

  testWidgets('one profile shows no sharing rows', (tester) async {
    await pump(tester, activeDiverId: 'owner', divers: [bill]);
    expect(find.text('Shared with'), findsNothing);
    expect(find.text('Owned by'), findsNothing);
    expect(find.byKey(overflow), findsOneWidget);
  });

  testWidgets('tapping Shared with lists the other profiles', (tester) async {
    await pump(tester, activeDiverId: 'owner');
    await tester.tap(find.text('Shared with'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(CheckboxListTile, 'Anna'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Bill'), findsNothing);
  });
}
