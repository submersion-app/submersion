import 'package:collection/collection.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_record.dart';

/// A name as the catalogue matches it: case, spaces and punctuation removed,
/// so "Perdix 2" and "perdix2" agree. A plus sign is a word: the Mares
/// "Puck Pro +" is not the "Puck Pro". The equipment catalogue repository's
/// validator normalises the same way.
String catalogueNameKey(String value) => value
    .toLowerCase()
    .replaceAll('+', 'plus')
    .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

/// The records of one catalogue copy, indexed for the gear editor: by
/// type, then by normalised maker name and alias, then by model name and
/// alias (issue #5118).
class EquipmentCatalogue {
  EquipmentCatalogue(EquipmentCatalogueFile file)
    : generatedAt = file.generatedAt,
      _byId = {for (final r in file.records) r.id: r},
      _byType = groupBy(file.records, (r) => r.type);

  EquipmentCatalogue._empty()
    : generatedAt = null,
      _byId = const {},
      _byType = const {};

  /// No catalogue: before one loads, and whenever none can be read.
  static final EquipmentCatalogue empty = EquipmentCatalogue._empty();

  final DateTime? generatedAt;
  final Map<String, EquipmentCatalogueRecord> _byId;
  final Map<EquipmentType, List<EquipmentCatalogueRecord>> _byType;

  bool get isEmpty => _byId.isEmpty;

  EquipmentCatalogueRecord? byId(String id) => _byId[id];

  /// The makers with a record of [type], each once by its own spelling,
  /// sorted.
  List<String> manufacturers(EquipmentType type) {
    final byKey = <String, String>{};
    for (final record in _byType[type] ?? const <EquipmentCatalogueRecord>[]) {
      byKey.putIfAbsent(
        catalogueNameKey(record.manufacturer),
        () => record.manufacturer,
      );
    }
    return byKey.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// The records of [type] whose maker is [brand] (by name or alias),
  /// sorted by model.
  List<EquipmentCatalogueRecord> models(EquipmentType type, String brand) {
    final key = catalogueNameKey(brand);
    if (key.isEmpty) return const [];
    return [
      for (final record in _byType[type] ?? const <EquipmentCatalogueRecord>[])
        if (_makerKeys(record).contains(key)) record,
    ]..sort((a, b) => a.model.toLowerCase().compareTo(b.model.toLowerCase()));
  }

  /// The one record of [type] that [brand] and [model] name, by name or
  /// alias; null when none does, or when two do (the diver must not be
  /// offered a guess).
  EquipmentCatalogueRecord? resolve(
    EquipmentType type,
    String? brand,
    String? model,
  ) {
    final modelKey = catalogueNameKey(model ?? '');
    if (modelKey.isEmpty) return null;
    final matches = [
      for (final record in models(type, brand ?? ''))
        if (_modelKeys(record).contains(modelKey)) record,
    ];
    return matches.length == 1 ? matches.single : null;
  }

  static Set<String> _makerKeys(EquipmentCatalogueRecord r) => {
    catalogueNameKey(r.manufacturer),
    for (final alias in r.manufacturerAliases) catalogueNameKey(alias),
  };

  static Set<String> _modelKeys(EquipmentCatalogueRecord r) => {
    catalogueNameKey(r.model),
    for (final alias in r.aliases) catalogueNameKey(alias),
  };
}
