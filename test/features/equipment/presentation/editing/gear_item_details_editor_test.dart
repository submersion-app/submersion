import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_details_editor.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The gear item's Details card edited in place (issue #4527, phase 3,
/// plan 6).
void main() {
  final l = AppLocalizationsEn();
  const rebreather = EquipmentItem(
    id: 'r1',
    name: 'Loop',
    type: EquipmentType.rebreather,
  );
  const mask = EquipmentItem(id: 'm1', name: 'Mask', type: EquipmentType.mask);
  const cell = EquipmentItem(
    id: 'c1',
    name: 'Cell A',
    type: EquipmentType.o2Cell,
    serialNumber: 'S9',
  );
  const regulator = EquipmentItem(
    id: 'g1',
    name: 'Apex',
    type: EquipmentType.regulator,
    serialNumber: 'A1',
  );

  setUp(() async {
    await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
  });
  tearDown(tearDownTestDatabase);

  Future<EditSession<EquipmentItem>> pumpEditor(
    WidgetTester tester,
    EquipmentItem item, {
    Future<List<EquipmentItem>> Function()? active,
    String? defaultCurrency,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 2600);
    addTearDown(tester.view.reset);
    final session = EditSession(item);
    addTearDown(session.dispose);
    final settings = MockSettingsNotifier();
    final overrides = await getBaseOverrides(settingsNotifier: settings);
    if (defaultCurrency != null) {
      await settings.setDefaultCurrency(defaultCurrency);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          activeEquipmentProvider.overrideWith(
            (ref) => active?.call() ?? Future.value(const [rebreather, mask]),
          ),
          equipmentDiveCountProvider(item.id).overrideWith((ref) async => 3),
          equipmentTripCountProvider(item.id).overrideWith((ref) async => 1),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: GearItemDetailsEditor(session: session),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return session;
  }

  final parentPicker = find.byKey(const Key('equipment-parent-picker'));

  testWidgets('an O2 cell offers rebreathers as its parent', (tester) async {
    final session = await pumpEditor(tester, cell);

    expect(parentPicker, findsOneWidget);
    await tester.tap(parentPicker);
    await tester.pumpAndSettle();
    expect(find.text('Loop').last, findsOneWidget);
    expect(find.text('Mask'), findsNothing);
    await tester.tap(find.text('Loop').last);
    await tester.pumpAndSettle();

    expect(session.working.parentEquipmentId, 'r1');
    expect(session.changedCardIds, {'details'});
  });

  testWidgets('the parent stays while the candidates load', (tester) async {
    final fitted = cell.copyWith(parentEquipmentId: 'r1');
    final session = await pumpEditor(
      tester,
      fitted,
      active: () => Future.delayed(const Duration(days: 1)),
    );

    expect(session.working.parentEquipmentId, 'r1');
    expect(session.isDirty, isFalse);
  });

  testWidgets('a regulator shows no parent picker', (tester) async {
    await pumpEditor(tester, regulator);

    expect(parentPicker, findsNothing);
  });

  testWidgets('the Details editor has no legacy service section', (
    tester,
  ) async {
    await pumpEditor(tester, regulator);

    expect(find.text('Service Settings'), findsNothing);
    expect(find.text('Service Interval (days)'), findsNothing);
  });

  testWidgets('a wanted item\'s Details editor is relabelled and trimmed', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      cell.copyWith(status: EquipmentStatus.wanted, isActive: false),
    );

    expect(find.text(l.equipment_edit_expectedPriceLabel), findsOneWidget);
    expect(find.text(l.equipment_edit_purchasePriceLabel), findsNothing);
    expect(find.byKey(const ValueKey('gear-edit-serial')), findsNothing);
    expect(find.byKey(const ValueKey('gear-edit-purchase-date')), findsNothing);
    expect(parentPicker, findsNothing);
  });

  testWidgets('Wanted and back keeps the serial and parent', (tester) async {
    final fitted = cell.copyWith(parentEquipmentId: 'r1');
    final session = await pumpEditor(tester, fitted);

    session.set(gearStatusField, EquipmentStatus.wanted);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('gear-edit-serial')), findsNothing);
    session.set(gearStatusField, EquipmentStatus.active);
    await tester.pumpAndSettle();

    expect(session.working.serialNumber, 'S9');
    expect(session.working.parentEquipmentId, 'r1');
    expect(find.byKey(const ValueKey('gear-edit-serial')), findsOneWidget);
  });

  testWidgets('calculated rows are read only inside the editor', (
    tester,
  ) async {
    await pumpEditor(tester, regulator);

    expect(find.text(l.equipment_detail_divesCountPlural(3)), findsOneWidget);
    expect(find.text(l.equipment_detail_tripsCountSingular(1)), findsOneWidget);
    // Shown as text, not as fields.
    expect(
      find.ancestor(
        of: find.text(l.equipment_detail_divesCountPlural(3)),
        matching: find.byType(TextField),
      ),
      findsNothing,
    );
  });

  testWidgets('brand and serial typed are the Details card\'s changes', (
    tester,
  ) async {
    final session = await pumpEditor(tester, regulator);

    await tester.enterText(
      find.byKey(const ValueKey('gear-edit-brand')),
      'Scubapro',
    );
    await tester.enterText(find.byKey(const ValueKey('gear-edit-serial')), '');
    await tester.pumpAndSettle();

    expect(session.working.brand, 'Scubapro');
    expect(session.working.serialNumber, isNull);
    expect(session.changedCardIds, {'details'});
  });

  testWidgets('an unreadable price blocks the card until it is fixed', (
    tester,
  ) async {
    final session = await pumpEditor(
      tester,
      regulator.copyWith(purchasePrice: 400, purchaseCurrency: 'EUR'),
    );
    final price = find.byKey(const ValueKey('equipment-purchase-price'));

    await tester.enterText(price, '4x0');
    await tester.pumpAndSettle();
    expect(gearDetailsValid(session), isFalse);
    expect(find.textContaining('Enter a valid number'), findsOneWidget);
    expect(session.working.purchasePrice, 400);

    await tester.enterText(price, '450');
    await tester.pumpAndSettle();
    expect(gearDetailsValid(session), isTrue);
    expect(session.working.purchasePrice, 450);
    expect(session.working.purchaseCurrency, 'EUR');
  });

  testWidgets('reopening the editor after an unreadable price unblocks the '
      'card', (tester) async {
    final session = await pumpEditor(
      tester,
      regulator.copyWith(purchasePrice: 400, purchaseCurrency: 'EUR'),
    );
    await tester.enterText(
      find.byKey(const ValueKey('equipment-purchase-price')),
      '4x0',
    );
    await tester.pumpAndSettle();
    expect(gearDetailsValid(session), isFalse);

    // The card closes and opens again: the field shows the readable price.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProviderScope(
            overrides: (await getBaseOverrides()).cast(),
            child: SingleChildScrollView(
              child: GearItemDetailsEditor(session: session),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(gearDetailsValid(session), isTrue);
  });

  test('a unit picked with no number yet is kept', () {
    final key = EquipmentAttributeCatalog.attributesFor(
      EquipmentType.bcd,
    ).firstWhere((d) => d.kind == AttributeKind.number).key;
    final bcd = regulator.copyWith(type: EquipmentType.bcd);
    final session = EditSession(bcd)
      ..set(
        gearAttributeField(key),
        EquipmentAttribute.curated(
          equipmentId: 'g1',
          key: key,
          valueUnit: 'kg',
        ),
      );

    final saved = gearItemToSave(bcd, session.applyTo(bcd));

    expect(saved.attr(key)?.valueUnit, 'kg');
  });

  /// Runs the rest of a test under [locale], put back afterwards.
  void underLocale(String locale) {
    final previous = Intl.defaultLocale;
    addTearDown(() => Intl.defaultLocale = previous);
    Intl.defaultLocale = locale;
  }

  EquipmentItem wetsuit({double? price}) => EquipmentItem(
    id: 'w1',
    name: '7mm Wetsuit',
    type: EquipmentType.wetsuit,
    purchasePrice: price,
    purchaseCurrency: 'EUR',
    attributes: [
      EquipmentAttribute.curated(
        equipmentId: 'w1',
        key: 'buoyancy_kg',
        valueNum: 5.0,
      ),
      EquipmentAttribute.curated(
        equipmentId: 'w1',
        key: 'dry_weight_kg',
        valueNum: 2.5,
      ),
    ],
  );

  final buoyancy = find.byKey(const ValueKey('attr-field-buoyancy_kg'));
  final price = find.byKey(const ValueKey('equipment-purchase-price'));
  final currencyMenu = find.byType(DropdownMenu<String>);

  testWidgets('a stored attribute shows as stored, and a number typed is '
      'held', (tester) async {
    final session = await pumpEditor(tester, wetsuit());

    expect(find.text('5'), findsOneWidget);
    expect(find.text('2.5'), findsOneWidget);
    await tester.enterText(buoyancy, '-2.5');
    await tester.pumpAndSettle();

    expect(session.working.attrNum('buoyancy_kg'), -2.5);
    expect(session.working.attrNum('dry_weight_kg'), 2.5);
    expect(session.changedCardIds, {'details'});
  });

  testWidgets('an attribute cleared is taken off the item', (tester) async {
    final session = await pumpEditor(tester, wetsuit());

    await tester.enterText(buoyancy, '');
    await tester.pumpAndSettle();

    expect(session.working.attrNum('buoyancy_kg'), isNull);
    expect(session.working.attrNum('dry_weight_kg'), 2.5);
  });

  testWidgets('under a comma locale an item opens unchanged, its price '
      'written with a comma', (tester) async {
    underLocale('de');
    final session = await pumpEditor(tester, wetsuit(price: 12.5));

    expect(find.text('12,5'), findsOneWidget);
    expect(session.isDirty, isFalse);
  });

  testWidgets('a price typed with a comma decimal is read under a comma '
      'locale', (tester) async {
    underLocale('fr');
    final session = await pumpEditor(tester, regulator);

    await tester.enterText(price, '12,50');
    await tester.pumpAndSettle();

    expect(session.working.purchasePrice, 12.5);
  });

  testWidgets('a price cleared is no price', (tester) async {
    final session = await pumpEditor(
      tester,
      regulator.copyWith(purchasePrice: 90, purchaseCurrency: 'EUR'),
    );

    await tester.enterText(price, '');
    await tester.pumpAndSettle();

    expect(session.working.purchasePrice, isNull);
    expect(gearDetailsValid(session), isTrue);
  });

  testWidgets('the stored currency shows in its menu and its symbol on the '
      'price', (tester) async {
    await pumpEditor(
      tester,
      regulator.copyWith(purchasePrice: 150, purchaseCurrency: 'EUR'),
    );

    expect(
      tester.widget<DropdownMenu<String>>(currencyMenu).controller?.text,
      'EUR',
    );
    expect(
      tester.widget<TextField>(price).decoration?.prefixText,
      contains('€'),
    );
  });

  testWidgets('a stored currency outside the presets leads its menu', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      regulator.copyWith(purchasePrice: 150, purchaseCurrency: 'ISK'),
    );

    final entries = tester
        .widget<DropdownMenu<String>>(currencyMenu)
        .dropdownMenuEntries;
    expect(entries.first.value, 'ISK');
  });

  testWidgets('a currency cleared falls back to the diver default, not '
      'USD', (tester) async {
    final session = await pumpEditor(
      tester,
      regulator.copyWith(purchasePrice: 150, purchaseCurrency: 'EUR'),
      defaultCurrency: 'NOK',
    );

    await tester.enterText(
      find.descendant(of: currencyMenu, matching: find.byType(TextField)),
      '',
    );
    await tester.pumpAndSettle();

    expect(session.working.purchaseCurrency, 'NOK');
  });

  testWidgets('a purchase date is picked, and cleared', (tester) async {
    final session = await pumpEditor(tester, regulator);

    await tester.tap(find.byKey(const ValueKey('gear-edit-purchase-date')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(session.valueOf(gearPurchaseDateField), isNotNull);

    await tester.tap(find.text(l.equipment_edit_clearDate));
    await tester.pumpAndSettle();
    expect(session.valueOf(gearPurchaseDateField), isNull);
  });

  testWidgets('fins show their stored colour, and a colour picked then '
      'cleared is held', (tester) async {
    final session = await pumpEditor(
      tester,
      EquipmentItem(
        id: 'f1',
        name: 'Jet fins',
        type: EquipmentType.fins,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: 'f1',
            key: 'color',
            valueText: '#EF4444',
          ),
        ],
      ),
    );
    final field = find.byKey(const ValueKey('attr-field-color'));
    expect(find.descendant(of: field, matching: find.text('Red')), findsOne);

    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('color-swatch-#14B8A6')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: field, matching: find.text('Teal')), findsOne);
    expect(session.working.attrText('color'), '#14B8A6');

    await tester.tap(
      find.descendant(of: field, matching: find.byIcon(Icons.clear)),
    );
    await tester.pumpAndSettle();
    expect(find.descendant(of: field, matching: find.text('--')), findsOne);
    expect(session.working.attrText('color'), isNull);
  });

  testWidgets('the attribute fields follow the type held in the sitting', (
    tester,
  ) async {
    final session = await pumpEditor(tester, regulator);
    Finder fieldOf(String key) => find.byKey(ValueKey('attr-field-$key'));
    expect(fieldOf('connection'), findsOneWidget);
    expect(fieldOf('thickness_mm'), findsNothing);

    session.set(gearTypeField, EquipmentType.wetsuit);
    await tester.pumpAndSettle();

    expect(fieldOf('thickness_mm'), findsOneWidget);
    expect(fieldOf('connection'), findsNothing);
  });
}
