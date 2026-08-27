import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Purchase price round trip under locales whose decimal separator is not '.'
/// (#1091). Number formatting resolves against `Intl.defaultLocale`, the
/// process global `lib/app.dart` sets from the diver's locale, so these tests
/// pin that global rather than the MaterialApp locale. The interface is left
/// in English so the shared 'Save' finder keeps working; the separator
/// behaviour under test is governed entirely by the pinned global.
void main() {
  group('EquipmentEditPage purchase price', () {
    late EquipmentRepository repository;
    late String? previousLocale;

    setUp(() async {
      await setUpTestDatabase();
      repository = EquipmentRepository();
      previousLocale = Intl.defaultLocale;
    });

    tearDown(() async {
      Intl.defaultLocale = previousLocale;
      await tearDownTestDatabase();
    });

    Future<void> pumpEditor(WidgetTester tester, String equipmentId) async {
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            equipmentRepositoryProvider.overrideWithValue(repository),
          ].cast(),
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EquipmentEditPage(equipmentId: equipmentId, embedded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final priceField = find.byKey(const ValueKey('equipment-purchase-price'));

    Future<void> scrollTo(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    Future<void> save(WidgetTester tester) async {
      await scrollTo(tester, find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    Future<EquipmentItem> createItem({double? price}) async {
      return repository.createEquipment(
        EquipmentItem(
          id: '',
          name: 'Regulator',
          type: EquipmentType.regulator,
          purchasePrice: price,
          purchaseCurrency: 'EUR',
        ),
      );
    }

    testWidgets('saves a price typed with a comma decimal separator', (
      tester,
    ) async {
      Intl.defaultLocale = 'fr';
      final created = await createItem();
      await pumpEditor(tester, created.id);

      await scrollTo(tester, priceField);
      await tester.enterText(priceField, '12,50');
      await save(tester);

      final saved = await repository.getEquipmentById(created.id);
      expect(saved!.purchasePrice, 12.5);
    });

    testWidgets('seeds the field using the locale decimal separator', (
      tester,
    ) async {
      Intl.defaultLocale = 'fr';
      final created = await createItem(price: 12.5);
      await pumpEditor(tester, created.id);

      await scrollTo(tester, priceField);
      expect(find.text('12,5'), findsOneWidget);
    });

    testWidgets('preserves the stored price on a save that never touches it', (
      tester,
    ) async {
      // The trap that makes this bug dangerous to fix naively: under de, '.'
      // is the GROUPING separator, so a field seeded with double.toString()
      // ('12.5') and read back locale-aware would store 125.0. Opening an item
      // and saving it unchanged must be a no-op.
      Intl.defaultLocale = 'de';
      final created = await createItem(price: 12.5);
      await pumpEditor(tester, created.id);

      await save(tester);

      final saved = await repository.getEquipmentById(created.id);
      expect(saved!.purchasePrice, 12.5);
    });

    testWidgets('rejects an unreadable price instead of discarding it', (
      tester,
    ) async {
      Intl.defaultLocale = 'fr';
      final created = await createItem(price: 90);
      await pumpEditor(tester, created.id);

      await scrollTo(tester, priceField);
      await tester.enterText(priceField, 'not a number');
      await save(tester);

      // The diver is told, and the stored price is left alone rather than
      // silently nulled.
      expect(find.text('Enter a valid amount'), findsOneWidget);
      final saved = await repository.getEquipmentById(created.id);
      expect(saved!.purchasePrice, 90);
    });

    testWidgets('clearing the field still removes the stored price', (
      tester,
    ) async {
      Intl.defaultLocale = 'fr';
      final created = await createItem(price: 90);
      await pumpEditor(tester, created.id);

      await scrollTo(tester, priceField);
      await tester.enterText(priceField, '');
      await save(tester);

      final saved = await repository.getEquipmentById(created.id);
      expect(saved!.purchasePrice, isNull);
    });
  });
}
