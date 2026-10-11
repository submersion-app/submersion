import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/gear_passports/presentation/utils/scan_owned_item.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

const regId = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
const wishId = '11111111-2222-4333-8444-555555555555';
const tankId = '22222222-3333-4444-8555-666666666666';
const otherId = '33333333-4444-4555-8666-777777777777';
const wishTankId = '44444444-5555-4666-8777-888888888888';

void main() {
  late AppDatabase db;

  Future<void> seed(
    String id,
    String name,
    String type,
    String pid, {
    String status = 'active',
  }) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: name,
            type: type,
            status: Value(status),
            createdAt: t,
            updatedAt: t,
          ),
        );
    await CylinderPassportRepository().assignPassportId(
      equipmentId: id,
      passportId: pid,
    );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await seed('reg', 'Primary', 'regulator', regId);
    await seed('wish', 'Wish', 'regulator', wishId, status: 'wanted');
    await seed('tank', 'Faber 12', 'tank', tankId);
    await seed('wishTank', 'Wish tank', 'tank', wishTankId, status: 'wanted');
  });
  tearDown(tearDownTestDatabase);

  /// Scans [text] through [scanOwnedItem]; returns the item and the strings.
  Future<(EquipmentItem?, AppLocalizations)> scan(
    WidgetTester tester,
    String? text,
  ) async {
    EquipmentItem? result;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () async =>
                    result = await scanOwnedItem(context, ref),
                child: const Text('scan'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/equipment/gear-tag',
          builder: (context, state) => const Text('foreign gear page'),
        ),
        GoRoute(
          path: '/equipment/tag',
          builder: (context, state) => const Text('foreign cylinder page'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          passportScanLauncherProvider.overrideWithValue(
            (context) async => text,
          ),
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
    final l10n = AppLocalizations.of(tester.element(find.text('scan')));
    await tester.tap(find.text('scan'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    return (result, l10n);
  }

  testWidgets('an own gear tag returns the item', (tester) async {
    final (item, _) = await scan(
      tester,
      'https://submersion.app/g#f=1&p=$regId&t=regulator',
    );
    expect(item?.id, 'reg');
  });

  testWidgets('an own cylinder tag returns the tank', (tester) async {
    final (item, _) = await scan(
      tester,
      'https://submersion.app/c#f=1&p=$tankId',
    );
    expect(item?.id, 'tank');
  });

  testWidgets('a foreign tag says so and View opens it', (tester) async {
    final (item, l10n) = await scan(
      tester,
      'https://submersion.app/g#f=1&p=$otherId&t=bcd',
    );
    expect(item, isNull);
    expect(find.text(l10n.gearPassport_scan_notYours), findsOneWidget);
    await tester.tap(find.text(l10n.gearPassport_scan_view));
    await tester.pumpAndSettle();
    expect(find.text('foreign gear page'), findsOneWidget);
  });

  testWidgets('a wanted item is refused by name', (tester) async {
    final (item, l10n) = await scan(
      tester,
      'https://submersion.app/g#f=1&p=$wishId&t=regulator',
    );
    expect(item, isNull);
    expect(find.text(l10n.gearPassport_scan_wishlist('Wish')), findsOneWidget);
  });

  testWidgets('text that is no tag says so', (tester) async {
    final (item, l10n) = await scan(tester, 'hello');
    expect(item, isNull);
    expect(find.text(l10n.tagScan_linkInvalid), findsOneWidget);
  });

  testWidgets('a closed scan sheet returns nothing quietly', (tester) async {
    final (item, l10n) = await scan(tester, null);
    expect(item, isNull);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a wanted tank is refused before its tag fill is stored', (
    tester,
  ) async {
    final (item, l10n) = await scan(
      tester,
      'https://submersion.app/c#f=1&p=$wishTankId'
      '&fi=55555555-6666-4777-8888-999999999999'
      '&ft=2026-10-01T09%3A30%3A00Z&fo=32',
    );
    expect(item, isNull);
    expect(
      find.text(l10n.gearPassport_scan_wishlist('Wish tank')),
      findsOneWidget,
    );
    final fills = await tester.runAsync(
      () => db.select(db.cylinderFills).get(),
    );
    expect(fills, isEmpty);
  });

  testWidgets('an own tank tag with a fill says the fill was added', (
    tester,
  ) async {
    final (item, _) = await scan(
      tester,
      'https://submersion.app/c#f=1&p=$tankId'
      '&fi=66666666-7777-4888-8999-aaaaaaaaaaaa'
      '&ft=2026-10-01T09%3A30%3A00Z&fo=32&fp=200',
    );
    expect(item?.id, 'tank');
    expect(find.textContaining('EAN32'), findsOneWidget);
  });
}
