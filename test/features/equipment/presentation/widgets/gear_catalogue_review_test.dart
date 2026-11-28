import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_offer.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_record.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_catalogue_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_catalogue_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/gear_catalogue_offer_line.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

final _perdix = EquipmentCatalogueRecord(
  id: 'shearwater-perdix-2',
  manufacturer: 'Shearwater',
  model: 'Perdix 2',
  type: EquipmentType.computer,
  attributes: const {'connectivity': 'ble', 'mount': 'wrist'},
  links: const EquipmentCatalogueLinks(manual: 'https://example.com/m.pdf'),
  sources: [
    EquipmentCatalogueSource(
      url: 'https://example.com/p2',
      publisher: CataloguePublisher.manufacturer,
      checked: DateTime.utc(2026, 11, 27),
      fields: const {'links.manual'},
    ),
  ],
);

const _loop = EquipmentCatalogueRecord(
  id: 'maker-loop',
  manufacturer: 'Maker',
  model: 'Loop',
  type: EquipmentType.rebreather,
  attributes: {'depth_rating_m': 100},
);

final _catalogue = EquipmentCatalogue(
  EquipmentCatalogueFile(
    format: 1,
    generatedAt: DateTime.utc(2026, 11, 27),
    records: [_perdix, _loop],
  ),
);

EquipmentItem _item({
  EquipmentType type = EquipmentType.computer,
  String brand = 'Shearwater',
  String model = 'Perdix 2',
  List<EquipmentAttribute> attributes = const [],
}) => EquipmentItem(
  id: 'e1',
  name: 'Perdix',
  type: type,
  brand: brand,
  model: model,
  attributes: attributes,
);

void main() {
  late String? savedIntl;
  setUp(() async {
    savedIntl = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
    await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
  });
  tearDown(() async {
    Intl.defaultLocale = savedIntl;
    await tearDownTestDatabase();
  });

  Future<EditSession<EquipmentItem>> pumpLine(
    WidgetTester tester,
    EquipmentItem item, {
    EquipmentCatalogue? catalogue,
    bool loading = false,
    DepthUnit depth = DepthUnit.meters,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.reset);
    final session = EditSession(item);
    addTearDown(session.dispose);
    final settings = MockSettingsNotifier();
    await settings.setDepthUnit(depth);
    final overrides = await getBaseOverrides(settingsNotifier: settings);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentCatalogueProvider.overrideWith(
            (ref) => loading
                ? Future<EquipmentCatalogue>.delayed(const Duration(days: 1))
                : Future.value(catalogue ?? _catalogue),
          ),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListenableBuilder(
              listenable: session,
              builder: (_, _) => GearCatalogueOfferLine(session: session),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return session;
  }

  const offerText = 'Built-in equipment catalogue has details for this model';

  testWidgets('the line shows when the typed name resolves', (tester) async {
    await pumpLine(tester, _item());
    expect(find.text(offerText), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
  });

  testWidgets('no line for a name the catalogue lacks', (tester) async {
    await pumpLine(tester, _item(model: 'Unknown 9'));
    expect(find.text(offerText), findsNothing);
  });

  testWidgets('no line for a record of another type', (tester) async {
    await pumpLine(tester, _item(type: EquipmentType.light));
    expect(find.text(offerText), findsNothing);
  });

  testWidgets('no line while the catalogue loads', (tester) async {
    await pumpLine(tester, _item(), loading: true);
    expect(find.text(offerText), findsNothing);
  });

  testWidgets('the sheet ticks empty fields and leaves differing ones', (
    tester,
  ) async {
    await pumpLine(
      tester,
      _item(
        attributes: const [
          EquipmentAttribute(
            id: 'm',
            equipmentId: 'e1',
            key: 'mount',
            valueText: 'console',
          ),
        ],
      ),
    );
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(
      find.text('From the manufacturer, checked Nov 27, 2026'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const ValueKey('catalogue-tick-connectivity')),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<Checkbox>(find.byKey(const ValueKey('catalogue-tick-mount')))
          .value,
      isFalse,
    );
    expect(find.text('Apply 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('catalogue-tick-mount')));
    await tester.pumpAndSettle();
    expect(find.text('Apply 2'), findsOneWidget);
    expect(
      find.text('Manufacturer links show on the gear page once linked.'),
      findsOneWidget,
    );
  });

  testWidgets('Apply holds the choice in the sitting and hides the line', (
    tester,
  ) async {
    final session = await pumpLine(tester, _item());
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply 2'));
    await tester.pumpAndSettle();
    expect(session.valueOf(gearCatalogueIdField), 'shearwater-perdix-2');
    expect(
      session.valueOf(gearAttributeField('connectivity'))?.valueText,
      'ble',
    );
    expect(session.stored.catalogueId, isNull);
    expect(find.text(offerText), findsNothing);
    expect(gearCatalogueRevision(session), 1);
  });

  testWidgets('Not this model hides the line', (tester) async {
    final session = await pumpLine(tester, _item());
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not this model'));
    await tester.pumpAndSettle();
    expect(session.valueOf(gearCatalogueAnswersField).notSame, {
      'shearwater-perdix-2',
    });
    expect(find.text(offerText), findsNothing);
  });

  testWidgets('dismissing the sheet changes nothing', (tester) async {
    final session = await pumpLine(tester, _item());
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(session.valueOf(gearCatalogueIdField), isNull);
    expect(find.text(offerText), findsOneWidget);
  });

  testWidgets('values are shown in the diver units', (tester) async {
    await pumpLine(
      tester,
      _item(type: EquipmentType.rebreather, brand: 'Maker', model: 'Loop'),
      depth: DepthUnit.feet,
    );
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.textContaining('328'), findsOneWidget);
    expect(find.textContaining('ft'), findsWidgets);
  });

  testWidgets('a match with nothing to fill offers the link only', (
    tester,
  ) async {
    await pumpLine(
      tester,
      _item(
        attributes: const [
          EquipmentAttribute(
            id: 'm',
            equipmentId: 'e1',
            key: 'mount',
            valueText: 'wrist',
          ),
          EquipmentAttribute(
            id: 'c',
            equipmentId: 'e1',
            key: 'connectivity',
            valueText: 'ble',
          ),
        ],
      ),
    );
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Link only'), findsOneWidget);
  });

  test('offerFor is what the sheet shows', () {
    expect(offerFor(_item(), _perdix).tickedByDefault, 2);
  });
}
