import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
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

  testWidgets('a fill deleted from the history is gone', (tester) async {
    final pid = await tester.runAsync(
      () => CylinderPassportRepository().ensurePassportId('tank'),
    );
    final t = DateTime(2026, 9, 20);
    await tester.runAsync(
      () => CylinderFillRepository().create(
        CylinderFill(
          id: 'f1',
          passportId: pid!,
          equipmentId: 'tank',
          filledAt: t,
          o2Percent: 32,
          createdAt: t,
          updatedAt: t,
        ),
      ),
    );
    final l10n = await pump(tester);
    expect(find.byTooltip(l10n.passport_history_delete), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.passport_history_delete));
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_history_deleteConfirm), findsOneWidget);
    await tester.tap(
      find.widgetWithText(FilledButton, l10n.passport_history_delete),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    final gone = await tester.runAsync(
      () => CylinderFillRepository().getById('f1'),
    );
    expect(gone, isNull);
    expect(find.byTooltip(l10n.passport_history_delete), findsNothing);
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

  testWidgets('a double tap on Track O2 cleaning makes one schedule', (
    tester,
  ) async {
    final l10n = await pump(tester);
    final track = find.text(l10n.passport_service_trackO2Clean);
    await tester.ensureVisible(track);
    await tester.tap(track);
    await tester.tap(track);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final schedules = await tester.runAsync(
      () => (db.select(
        db.serviceSchedules,
      )..where((t) => t.serviceKindId.equals('o2-clean'))).get(),
    );
    expect(schedules, hasLength(1));
  });
}
