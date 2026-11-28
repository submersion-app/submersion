import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_record.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/helpers/equipment_web_link_launcher.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_catalogue_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/gear_manufacturer_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

final _perdix = EquipmentCatalogueRecord(
  id: 'shearwater-perdix-2',
  manufacturer: 'Shearwater',
  model: 'Perdix 2',
  type: EquipmentType.computer,
  links: const EquipmentCatalogueLinks(
    product: 'https://example.com/p2',
    manual: 'https://example.com/m.pdf',
  ),
  sources: [
    EquipmentCatalogueSource(
      url: 'https://example.com/p2',
      publisher: CataloguePublisher.manufacturer,
      checked: DateTime.utc(2026, 11, 27),
      fields: const {'links.product', 'links.manual'},
    ),
  ],
);

const _bare = EquipmentCatalogueRecord(
  id: 'mares-puck',
  manufacturer: 'Mares',
  model: 'Puck',
  type: EquipmentType.computer,
);

final _catalogue = EquipmentCatalogue(
  EquipmentCatalogueFile(
    format: 1,
    generatedAt: DateTime.utc(2026, 11, 27),
    records: [_perdix, _bare],
  ),
);

const _linked = EquipmentItem(
  id: 'e1',
  name: 'Perdix',
  type: EquipmentType.computer,
  brand: 'Shearwater',
  model: 'Perdix 2',
  catalogueId: 'shearwater-perdix-2',
  attributes: [
    EquipmentAttribute(
      id: 'c',
      equipmentId: 'e1',
      key: 'connectivity',
      valueText: 'ble',
    ),
  ],
);

void main() {
  late String? savedIntl;
  late List<Uri> launched;
  setUp(() async {
    savedIntl = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
    launched = [];
    await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
  });
  tearDown(() async {
    Intl.defaultLocale = savedIntl;
    await tearDownTestDatabase();
  });

  Future<void> pump(WidgetTester tester, EquipmentItem item) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentCatalogueProvider.overrideWith((ref) async => _catalogue),
          equipmentWebLinkLaunchProvider.overrideWithValue((uri) async {
            launched.add(uri);
            return true;
          }),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: GearManufacturerCard(item: item)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a row per link the record has', (tester) async {
    await pump(tester, _linked);
    expect(find.text('From the manufacturer'), findsOneWidget);
    expect(find.text('Product page'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);
    expect(find.text('Support'), findsNothing);
    expect(
      find.text('From the manufacturer, checked Nov 27, 2026'),
      findsOneWidget,
    );
  });

  testWidgets('a row opens its link', (tester) async {
    await pump(tester, _linked);
    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();
    expect(launched, [Uri.parse('https://example.com/m.pdf')]);
  });

  testWidgets('nothing for an unlinked item', (tester) async {
    await pump(tester, _linked.copyWith(clearCatalogueId: true));
    expect(find.text('From the manufacturer'), findsNothing);
  });

  testWidgets('nothing for a record with no links', (tester) async {
    await pump(tester, _linked.copyWith(catalogueId: 'mares-puck'));
    expect(find.text('From the manufacturer'), findsNothing);
  });

  testWidgets('nothing for a record this catalogue lacks', (tester) async {
    await pump(tester, _linked.copyWith(catalogueId: 'gone'));
    expect(find.text('From the manufacturer'), findsNothing);
  });

  testWidgets('Unlink is in the card menu and keeps the values', (
    tester,
  ) async {
    final repo = EquipmentRepository();
    await repo.createEquipment(_linked);
    await pump(tester, _linked);
    expect(find.byType(ListTile), findsNothing);
    await tester.tap(find.byKey(const ValueKey('gear-manufacturer-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlink from catalogue'));
    await tester.pumpAndSettle();
    final stored = (await repo.getEquipmentById('e1'))!;
    expect(stored.catalogueId, isNull);
    expect(stored.attributes.single.valueText, 'ble');
  });
}
