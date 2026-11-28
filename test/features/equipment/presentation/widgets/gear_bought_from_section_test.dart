import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/gear_bought_from_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// "Bought from" on a buddy's page and "Bought here" on a dive centre's
/// (issue #5140): the gear they sold the diver, hidden when there is none.
void main() {
  late String? savedIntlLocale;
  setUp(() {
    savedIntlLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() => Intl.defaultLocale = savedIntlLocale);

  EquipmentItem item(
    String id, {
    String? buddy = 'b1',
    String? centre,
    DateTime? bought,
    EquipmentStatus status = EquipmentStatus.active,
  }) => EquipmentItem(
    id: id,
    name: id,
    type: EquipmentType.regulator,
    status: status,
    purchaseDate: bought,
    sellerBuddyId: buddy,
    sellerDiveCenterId: centre,
  );

  Future<void> pump(
    WidgetTester tester,
    List<EquipmentItem> items, {
    String? buddyId = 'b1',
    String? centerId,
    String title = 'Bought from Anna Berg',
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 3000);
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const Text('ABOVE'),
                  GearBoughtFromSection(
                    buddyId: buddyId,
                    centerId: centerId,
                    title: title,
                  ),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/equipment/:id',
          builder: (context, state) =>
              Text('ITEM ${state.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          allEquipmentProvider.overrideWith((ref) async => items),
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

  final showAll = find.byKey(const ValueKey('gear_bought_show_all'));

  testWidgets('nothing bought draws nothing', (tester) async {
    await pump(tester, [item('reg', buddy: 'b2')]);
    expect(find.text('Bought from Anna Berg'), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('one item shows its name and purchase date', (tester) async {
    await pump(tester, [item('Apeks XTX50', bought: DateTime(2025, 3, 12))]);
    expect(find.text('Bought from Anna Berg'), findsOneWidget);
    expect(find.text('Apeks XTX50'), findsOneWidget);
    expect(find.textContaining('Bought Mar 12, 2025'), findsOneWidget);
    expect(showAll, findsNothing);
  });

  testWidgets('many items show five and expand in place', (tester) async {
    await pump(tester, [
      for (var i = 0; i < 80; i++)
        item(
          'item ${i.toString().padLeft(2, '0')}',
          bought: DateTime(2000 + i % 25, 1, 1 + i % 28),
        ),
    ]);
    expect(find.byType(ListTile), findsNWidgets(5));
    expect(find.text('Show all (80)'), findsOneWidget);

    await tester.tap(showAll);
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNWidgets(80));
    expect(showAll, findsNothing);
  });

  testWidgets('an item that left the kit says so', (tester) async {
    await pump(tester, [
      item('sold on', bought: DateTime(2022), status: EquipmentStatus.sold),
      item('in use', bought: DateTime(2023)),
    ]);
    expect(find.textContaining('Sold'), findsOneWidget);
    expect(find.textContaining('Active'), findsNothing);
  });

  testWidgets('a wishlist item is left out', (tester) async {
    await pump(tester, [item('wish', status: EquipmentStatus.wanted)]);
    expect(find.text('wish'), findsNothing);
  });

  testWidgets('a row opens its gear item', (tester) async {
    await pump(tester, [item('reg', bought: DateTime(2025))]);
    await tester.tap(find.text('reg'));
    await tester.pumpAndSettle();
    expect(find.text('ITEM reg'), findsOneWidget);
  });

  testWidgets('a dive centre lists what was bought there', (tester) async {
    await pump(
      tester,
      [item('wing', buddy: null, centre: 'c1', bought: DateTime(2024))],
      buddyId: null,
      centerId: 'c1',
      title: 'Bought here',
    );
    expect(find.text('Bought here'), findsOneWidget);
    expect(find.text('wing'), findsOneWidget);
  });
}
