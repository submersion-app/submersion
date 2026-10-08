import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/presentation/connections_links.dart';
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
import 'package:submersion/features/equipment/presentation/providers/equipment_history_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/equipment/data/services/equipment_transfer_service.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_transfer_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _MockServiceRecordNotifier
    extends StateNotifier<AsyncValue<List<ServiceRecord>>>
    implements ServiceRecordNotifier {
  _MockServiceRecordNotifier() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Refuses every delete, as the repository does for another profile's item.
class _RefusingEquipmentNotifier
    extends StateNotifier<AsyncValue<List<EquipmentItem>>>
    implements EquipmentListNotifier {
  _RefusingEquipmentNotifier() : super(const AsyncValue.data([]));

  @override
  Future<bool> deleteEquipment(String id) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Transfers without touching a database (issue #2852).
class _FakeTransferService extends EquipmentTransferService {
  final transferred = <String>[];

  @override
  Future<EquipmentTransferPreview> preview({
    required List<String> equipmentIds,
    required String actingDiverId,
    String? toDiverId,
  }) async => EquipmentTransferPreview(
    unitIds: equipmentIds,
    skippedNotOwned: 0,
    computers: const [],
    transmitters: const [],
  );

  @override
  Future<EquipmentTransferResult> transfer({
    required List<String> equipmentIds,
    required String toDiverId,
    required String actingDiverId,
    bool keepAccess = true,
    bool moveRegistry = true,
  }) async {
    transferred.add(toDiverId);
    return EquipmentTransferResult(itemsMoved: equipmentIds.length);
  }
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
  late _FakeTransferService transfers;

  Future<void> pump(
    WidgetTester tester, {
    required String activeDiverId,
    List<Diver>? divers,
    bool refuseDelete = false,
    bool diverLoading = false,
    bool sharesLoading = false,
    EquipmentItem item = wing,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 2400);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides();
    transfers = _FakeTransferService();
    final router = GoRouter(
      initialLocation: '/equipment/$id',
      routes: [
        GoRoute(
          path: '/equipment/:id',
          builder: (context, state) =>
              const EquipmentDetailPage(equipmentId: id),
        ),
        GoRoute(
          path: '/equipment',
          builder: (context, state) =>
              const Scaffold(body: Text('EQUIPMENT LIST')),
        ),
        GoRoute(
          path: kConnectionsLocation,
          builder: (context, state) => Scaffold(
            body: Text('CONNECTIONS ${state.uri.queryParameters['focus']}'),
          ),
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
          allDiversProvider.overrideWith((ref) async => divers ?? [bill, anna]),
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) => diverLoading
                ? Completer<String?>().future
                : Future.value(activeDiverId),
          ),
          equipmentSharesProvider(id).overrideWith(
            (ref) => sharesLoading
                ? Completer<List<EquipmentShare>>().future
                : Future.value(shares),
          ),
          if (refuseDelete)
            equipmentListNotifierProvider.overrideWith(
              (ref) => _RefusingEquipmentNotifier(),
            ),
          equipmentHistoryProvider(id).overrideWith((ref) async => const []),
          equipmentTransferServiceProvider.overrideWithValue(transfers),
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

  testWidgets('a sharee sees Owned by and a menu without Delete', (
    tester,
  ) async {
    await pump(tester, activeDiverId: 'wife');
    expect(find.text('Owned by'), findsOneWidget);
    expect(find.text('Bill'), findsOneWidget);
    // Shared gear is on the sharee's own dives, so Connections is open to
    // them; deleting it stays with the owner (issue #2046).
    await tester.tap(find.byKey(overflow));
    await tester.pumpAndSettle();
    expect(find.text('Open in Connections'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
    await tester.tap(find.text('Open in Connections'));
    await tester.pumpAndSettle();
    expect(find.text('CONNECTIONS equipment:$id'), findsOneWidget);
  });

  testWidgets('the History card shows with two or more profiles', (
    tester,
  ) async {
    await pump(tester, activeDiverId: 'owner');
    await tester.scrollUntilVisible(
      find.text('History'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('a refused delete says so and stays on the page', (tester) async {
    await pump(tester, activeDiverId: 'owner', refuseDelete: true);
    await tester.tap(find.byKey(overflow));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    // Confirm in the dialog.
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Only its owner can delete this item'), findsOneWidget);
    expect(find.text('Equipment deleted'), findsNothing);
    expect(find.byKey(overflow), findsOneWidget);
  });

  testWidgets('an ownerless item offers no sharing', (tester) async {
    // No owner to manage its shares (issue #2046).
    await pump(
      tester,
      activeDiverId: 'owner',
      item: const EquipmentItem(id: id, name: 'Wing', type: EquipmentType.bcd),
    );
    expect(find.text('Shared with'), findsNothing);
    expect(find.text('Owned by'), findsNothing);
  });

  testWidgets('nothing about ownership shows while the diver loads', (
    tester,
  ) async {
    // Neither "Owned by <you>" nor Delete may flash for the wrong
    // profile before the active diver is known.
    await pump(tester, activeDiverId: 'wife', diverLoading: true);
    expect(find.text('Owned by'), findsNothing);
    expect(find.text('Shared with'), findsNothing);
    await tester.tap(find.byKey(overflow));
    await tester.pumpAndSettle();
    expect(find.text('Open in Connections'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('the owner cannot edit shares before they load', (tester) async {
    // Opening the checklist on an unread share list would start it empty,
    // and saving it would remove every existing share.
    await pump(tester, activeDiverId: 'owner', sharesLoading: true);
    expect(find.text('Shared with'), findsNothing);
    expect(find.text('Not shared'), findsNothing);
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

  group('transfer (issue #2852)', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byKey(overflow));
      await tester.pumpAndSettle();
    }

    testWidgets('the owner sees Transfer to in the page menu', (tester) async {
      await pump(tester, activeDiverId: 'owner');
      await openMenu(tester);
      expect(find.text('Transfer to...'), findsOneWidget);
    });

    testWidgets('a sharee does not', (tester) async {
      await pump(tester, activeDiverId: 'wife');
      await openMenu(tester);
      expect(find.text('Transfer to...'), findsNothing);
    });

    testWidgets('nobody does with one profile', (tester) async {
      await pump(tester, activeDiverId: 'owner', divers: [bill]);
      await openMenu(tester);
      expect(find.text('Transfer to...'), findsNothing);
    });

    testWidgets('keeping access stays on the item', (tester) async {
      await pump(tester, activeDiverId: 'owner');
      await openMenu(tester);
      await tester.tap(find.text('Transfer to...'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anna').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Transfer'));
      await tester.pumpAndSettle();
      expect(transfers.transferred, ['wife']);
      expect(find.text('EQUIPMENT LIST'), findsNothing);
      expect(find.byKey(overflow), findsOneWidget);
    });

    testWidgets('a transfer without keeping access leaves the item', (
      tester,
    ) async {
      await pump(tester, activeDiverId: 'owner');
      await openMenu(tester);
      await tester.tap(find.text('Transfer to...'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anna').last);
      await tester.tap(find.text('Keep access for me'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Transfer'));
      await tester.pumpAndSettle();
      expect(transfers.transferred, ['wife']);
      expect(find.text('EQUIPMENT LIST'), findsOneWidget);
    });
  });
}
