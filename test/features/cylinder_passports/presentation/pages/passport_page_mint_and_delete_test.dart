import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/presentation/pages/passport_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The passport against a real database: the id minted on first open, and a
/// fill deleted from the history.
void main() {
  late AppDatabase db;
  late String? savedIntlLocale;

  setUp(() async {
    savedIntlLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
    db = await setUpTestDatabase();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'tank',
            name: 'Faber 12',
            type: 'tank',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(null),
          ),
        );
  });
  tearDown(() async {
    Intl.defaultLocale = savedIntlLocale;
    await tearDownTestDatabase();
  });

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    String equipmentId = 'tank',
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 3000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PassportPage(equipmentId: equipmentId),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(PassportPage)));
  }

  testWidgets('opening the passport mints the cylinder id once', (
    tester,
  ) async {
    await pump(tester);
    final minted = await tester.runAsync(
      () => CylinderPassportRepository().getPassportId('tank'),
    );
    expect(minted, isNotNull);
    // Deterministic: the same equipment always mints the same id.
    final again = await tester.runAsync(
      () => CylinderPassportRepository().ensurePassportId('tank'),
    );
    expect(again, minted);
  });

  testWidgets('a passport opened for other gear mints nothing', (tester) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await tester.runAsync(
      () => db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: 'reg',
              name: 'Apeks',
              type: 'regulator',
              createdAt: t,
              updatedAt: t,
            ),
          ),
    );
    await pump(tester, equipmentId: 'reg');
    expect(tester.takeException(), isNull);
    final id = await tester.runAsync(
      () => CylinderPassportRepository().getPassportId('reg'),
    );
    expect(id, isNull);
  });

  testWidgets('a passport opened for a deleted item fails quietly', (
    tester,
  ) async {
    await pump(tester, equipmentId: 'gone');
    expect(tester.takeException(), isNull);
    final rows = await tester.runAsync(
      () => db.select(db.equipmentAttributes).get(),
    );
    expect(rows, isEmpty);
  });
}
