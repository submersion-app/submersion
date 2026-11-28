import 'package:collection/collection.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_record.dart';

/// A name as the catalogue matches it: case, spaces and punctuation removed,
/// so "Perdix 2" and "perdix2" agree. A plus sign is a word: the Mares
/// "Puck Pro +" is not the "Puck Pro". The equipment catalogue repository's
/// validator normalises the same way.
String catalogueNameKey(String value) => value
    .toLowerCase()
    .replaceAll('+', 'plus')
    .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

/// A record with its names normalised once, when the copy is indexed.
class _Entry {
  _Entry(this.record)
    : makerKeys = {
        catalogueNameKey(record.manufacturer),
        for (final alias in record.manufacturerAliases) catalogueNameKey(alias),
      },
      modelKeys = {
        catalogueNameKey(record.model),
        for (final alias in record.aliases) catalogueNameKey(alias),
      };

  final EquipmentCatalogueRecord record;
  final Set<String> makerKeys;
  final Set<String> modelKeys;
}

/// The records of one catalogue copy, indexed for the gear editor: by
/// type, with every maker and model name and alias normalised once, so a
/// lookup on each keystroke compares keys and builds none (issue #5118).
class EquipmentCatalogue {
  EquipmentCatalogue(EquipmentCatalogueFile file)
    : generatedAt = file.generatedAt,
      _byId = {for (final r in file.records) r.id: r},
      _byType = groupBy(file.records.map(_Entry.new), (e) => e.record.type);

  EquipmentCatalogue._empty()
    : generatedAt = null,
      _byId = const {},
      _byType = const {};

  /// No catalogue: before one loads, and whenever none can be read.
  static final EquipmentCatalogue empty = EquipmentCatalogue._empty();

  final DateTime? generatedAt;
  final Map<String, EquipmentCatalogueRecord> _byId;
  final Map<EquipmentType, List<_Entry>> _byType;

  bool get isEmpty => _byId.isEmpty;

  EquipmentCatalogueRecord? byId(String id) => _byId[id];

  List<_Entry> _of(EquipmentType type) => _byType[type] ?? const [];

  /// The makers with a record of [type], each once by its own spelling,
  /// sorted.
  List<String> manufacturers(EquipmentType type) =>
      manufacturerKeys(type).keys.toList()..sort(compareTextForSort);

  /// Each maker with a record of [type], by its own spelling, with the
  /// normalised keys of that spelling and every alias it goes by.
  Map<String, Set<String>> manufacturerKeys(EquipmentType type) {
    final byMain = <String, String>{};
    final keys = <String, Set<String>>{};
    for (final entry in _of(type)) {
      final main = byMain.putIfAbsent(
        catalogueNameKey(entry.record.manufacturer),
        () => entry.record.manufacturer,
      );
      (keys[main] ??= <String>{}).addAll(entry.makerKeys);
    }
    return keys;
  }

  /// The records of [type] whose maker is [brand] (by name or alias),
  /// sorted by model.
  List<EquipmentCatalogueRecord> models(EquipmentType type, String brand) {
    final key = catalogueNameKey(brand);
    if (key.isEmpty) return const [];
    return [
      for (final entry in _of(type))
        if (entry.makerKeys.contains(key)) entry.record,
    ]..sort((a, b) => compareTextForSort(a.model, b.model));
  }

  /// The one record of [type] that [brand] and [model] name, by name or
  /// alias; null when none does, or when two do (the diver must not be
  /// offered a guess).
  EquipmentCatalogueRecord? resolve(
    EquipmentType type,
    String? brand,
    String? model,
  ) {
    final makerKey = catalogueNameKey(brand ?? '');
    final modelKey = catalogueNameKey(model ?? '');
    if (makerKey.isEmpty || modelKey.isEmpty) return null;
    EquipmentCatalogueRecord? found;
    for (final entry in _of(type)) {
      if (!entry.makerKeys.contains(makerKey) ||
          !entry.modelKeys.contains(modelKey)) {
        continue;
      }
      if (found != null) return null;
      found = entry.record;
    }
    return found;
  }
}
