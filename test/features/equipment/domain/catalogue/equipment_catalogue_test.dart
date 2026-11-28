import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_record.dart';

EquipmentCatalogueRecord _record(
  String id,
  String maker,
  String model, {
  EquipmentType type = EquipmentType.computer,
  List<String> makerAliases = const [],
  List<String> aliases = const [],
}) => EquipmentCatalogueRecord(
  id: id,
  manufacturer: maker,
  manufacturerAliases: makerAliases,
  model: model,
  aliases: aliases,
  type: type,
);

final _catalogue = EquipmentCatalogue(
  EquipmentCatalogueFile(
    format: 1,
    generatedAt: DateTime.utc(2026, 11, 27),
    records: [
      _record(
        'shearwater-perdix-2',
        'Shearwater',
        'Perdix 2',
        makerAliases: ['Shearwater Research'],
        aliases: ['Perdix2'],
      ),
      _record('shearwater-perdix', 'Shearwater', 'Perdix'),
      _record('shearwater-teric', 'Shearwater', 'Teric'),
      _record('mares-puck-pro', 'Mares', 'Puck Pro'),
      _record('mares-puck-pro-plus', 'Mares', 'Puck Pro +'),
      _record('mares-quad', 'Mares', 'Quad'),
      _record('lumo-quad', 'Lumo', 'Quad', type: EquipmentType.light),
      _record('twin-a', 'Twin', 'Same'),
      _record('twin-b', 'Twin', 'Other', aliases: ['Same']),
    ],
  ),
);

void main() {
  test('catalogueNameKey ignores case, spaces and punctuation', () {
    expect(catalogueNameKey(' Perdix-2 '), catalogueNameKey('perdix2'));
    expect(catalogueNameKey('Puck Pro +'), isNot(catalogueNameKey('Puck Pro')));
  });

  test('resolve by exact names', () {
    expect(
      _catalogue.resolve(EquipmentType.computer, 'Shearwater', 'Perdix 2')?.id,
      'shearwater-perdix-2',
    );
  });

  test('resolve by alias and manufacturer alias, ignoring case and spaces', () {
    expect(
      _catalogue
          .resolve(EquipmentType.computer, 'shearwater research', 'perdix2')
          ?.id,
      'shearwater-perdix-2',
    );
  });

  test('resolve tells Puck Pro + from Puck Pro', () {
    expect(
      _catalogue.resolve(EquipmentType.computer, 'Mares', 'Puck Pro+')?.id,
      'mares-puck-pro-plus',
    );
  });

  test('resolve ignores a record of another type', () {
    expect(_catalogue.resolve(EquipmentType.computer, 'Lumo', 'Quad'), isNull);
    expect(
      _catalogue.resolve(EquipmentType.light, 'Lumo', 'Quad')?.id,
      'lumo-quad',
    );
  });

  test('resolve returns null when two records match', () {
    expect(_catalogue.resolve(EquipmentType.computer, 'Twin', 'Same'), isNull);
  });

  test('resolve returns null for a blank brand or model', () {
    expect(_catalogue.resolve(EquipmentType.computer, null, 'Teric'), isNull);
    expect(
      _catalogue.resolve(EquipmentType.computer, 'Shearwater', ' '),
      isNull,
    );
  });

  test('models lists a brand models for the type only', () {
    expect(
      _catalogue.models(EquipmentType.computer, 'mares').map((r) => r.model),
      ['Puck Pro', 'Puck Pro +', 'Quad'],
    );
    expect(_catalogue.models(EquipmentType.light, 'Mares'), isEmpty);
  });

  test('manufacturers lists main names once, for the type', () {
    expect(_catalogue.manufacturers(EquipmentType.computer), [
      'Mares',
      'Shearwater',
      'Twin',
    ]);
    expect(_catalogue.manufacturers(EquipmentType.light), ['Lumo']);
  });

  test('byId finds a record', () {
    expect(_catalogue.byId('mares-quad')?.model, 'Quad');
    expect(_catalogue.byId('nope'), isNull);
  });

  test('the empty catalogue has nothing', () {
    expect(EquipmentCatalogue.empty.generatedAt, isNull);
    expect(
      EquipmentCatalogue.empty.manufacturers(EquipmentType.computer),
      isEmpty,
    );
  });
}
