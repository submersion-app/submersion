import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_offer.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_record.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_catalogue_answers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

const _perdix = EquipmentCatalogueRecord(
  id: 'shearwater-perdix-2',
  manufacturer: 'Shearwater',
  model: 'Perdix 2',
  aliases: ['Perdix2'],
  type: EquipmentType.computer,
  attributes: {'connectivity': 'ble', 'mount': 'wrist'},
);

const _light = EquipmentCatalogueRecord(
  id: 'lumo-quad',
  manufacturer: 'Lumo',
  model: 'Quad',
  type: EquipmentType.light,
  attributes: {'lumens': 1200},
);

EquipmentAttribute _attr(String key, {String? text, double? num}) =>
    EquipmentAttribute(
      id: 'a-$key',
      equipmentId: 'e1',
      key: key,
      valueText: text,
      valueNum: num,
    );

EquipmentItem _item({
  String? brand = 'Shearwater',
  String? model = 'Perdix 2',
  List<EquipmentAttribute> attributes = const [],
  String? catalogueId,
  EquipmentCatalogueAnswers answers = EquipmentCatalogueAnswers.empty,
  EquipmentType type = EquipmentType.computer,
}) => EquipmentItem(
  id: 'e1',
  name: 'Perdix',
  type: type,
  brand: brand,
  model: model,
  attributes: attributes,
  catalogueId: catalogueId,
  catalogueAnswers: answers,
);

CatalogueOfferRow? _row(CatalogueOffer offer, String field) =>
    offer.rows.where((r) => r.fieldName == field).firstOrNull;

final _catalogue = EquipmentCatalogue(
  EquipmentCatalogueFile(
    format: 1,
    generatedAt: DateTime.utc(2026, 11, 27),
    records: const [_perdix, _light],
  ),
);

void main() {
  group('offerFor', () {
    test('an empty attribute is offered ticked', () {
      final row = _row(offerFor(_item(), _perdix), 'connectivity')!;
      expect(row.kind, CatalogueOfferFieldKind.attribute);
      expect(row.itemValue, isNull);
      expect(row.recordValue, 'ble');
      expect(row.startTicked, isTrue);
    });

    test('a differing attribute is offered unticked', () {
      final offer = offerFor(
        _item(attributes: [_attr('mount', text: 'console')]),
        _perdix,
      );
      final row = _row(offer, 'mount')!;
      expect(row.itemValue, 'console');
      expect(row.recordValue, 'wrist');
      expect(row.startTicked, isFalse);
    });

    test('an equal attribute has no row', () {
      final offer = offerFor(
        _item(attributes: [_attr('mount', text: 'wrist')]),
        _perdix,
      );
      expect(_row(offer, 'mount'), isNull);
    });

    test('a number attribute compares as the stored value', () {
      final light = _item(
        brand: 'Lumo',
        model: 'Quad',
        type: EquipmentType.light,
        attributes: [_attr('lumens', num: 1200)],
      );
      expect(_row(offerFor(light, _light), 'lumens'), isNull);
      final dimmer = _item(
        brand: 'Lumo',
        model: 'Quad',
        type: EquipmentType.light,
        attributes: [_attr('lumens', num: 900)],
      );
      expect(_row(offerFor(dimmer, _light), 'lumens')!.startTicked, isFalse);
    });

    test('a declined empty field is left out', () {
      final offer = offerFor(
        _item(
          answers: EquipmentCatalogueAnswers.empty.withDeclined(
            'shearwater-perdix-2',
            ['connectivity'],
          ),
        ),
        _perdix,
      );
      expect(_row(offer, 'connectivity'), isNull);
      expect(_row(offer, 'mount'), isNotNull);
    });

    test('a different brand or model spelling is an unticked row', () {
      final offer = offerFor(_item(model: 'perdix2'), _perdix);
      final row = _row(offer, 'model')!;
      expect(row.kind, CatalogueOfferFieldKind.model);
      expect(row.itemValue, 'perdix2');
      expect(row.recordValue, 'Perdix 2');
      expect(row.startTicked, isFalse);
      expect(_row(offer, 'brand'), isNull);
    });

    test('an unlinked item adds the link', () {
      expect(offerFor(_item(), _perdix).addsLink, isTrue);
      expect(
        offerFor(_item(catalogueId: 'shearwater-perdix-2'), _perdix).addsLink,
        isFalse,
      );
    });
  });

  group('showOfferLine', () {
    test('hidden for a record the diver said is not this item', () {
      final item = _item(
        answers: EquipmentCatalogueAnswers.empty.withNotSame(
          'shearwater-perdix-2',
        ),
      );
      expect(showOfferLine(item, offerFor(item, _perdix)), isFalse);
    });

    test('shown for an unlinked item even with nothing to fill', () {
      final item = _item(
        attributes: [
          _attr('mount', text: 'wrist'),
          _attr('connectivity', text: 'ble'),
        ],
      );
      final offer = offerFor(item, _perdix);
      expect(offer.rows, isEmpty);
      expect(showOfferLine(item, offer), isTrue);
    });

    test('a linked item shows it only while an empty field is offered', () {
      final linked = _item(catalogueId: 'shearwater-perdix-2');
      expect(showOfferLine(linked, offerFor(linked, _perdix)), isTrue);
      final full = _item(
        catalogueId: 'shearwater-perdix-2',
        attributes: [
          _attr('mount', text: 'console'),
          _attr('connectivity', text: 'ble'),
        ],
      );
      // Only a differing (unticked) row is left: no line.
      expect(showOfferLine(full, offerFor(full, _perdix)), isFalse);
    });

    test('an item linked to another record never shows this offer', () {
      final other = _item(catalogueId: 'shearwater-teric');
      expect(showOfferLine(other, offerFor(other, _perdix)), isFalse);
    });
  });

  group('catalogueIdAfterRename', () {
    test('keeps the link on an alias spelling', () {
      final item = _item(model: 'perdix2', catalogueId: 'shearwater-perdix-2');
      expect(catalogueIdAfterRename(item, _catalogue), 'shearwater-perdix-2');
    });

    test('clears it for another model', () {
      final item = _item(model: 'Teric', catalogueId: 'shearwater-perdix-2');
      expect(catalogueIdAfterRename(item, _catalogue), isNull);
    });

    test('keeps it when the record is absent from the catalogue', () {
      final item = _item(model: 'Teric', catalogueId: 'gone-record');
      expect(catalogueIdAfterRename(item, _catalogue), 'gone-record');
    });

    test('an unlinked item stays unlinked', () {
      expect(catalogueIdAfterRename(_item(), _catalogue), isNull);
    });
  });
}
