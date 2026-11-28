import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';

/// Who published a fact in the equipment catalogue. A manufacturer's word
/// wins over the others (program rule 4).
enum CataloguePublisher { manufacturer, libdivecomputer, thirdParty }

/// A page a catalogue record's facts were read from, and which fields.
class EquipmentCatalogueSource extends Equatable {
  const EquipmentCatalogueSource({
    required this.url,
    required this.publisher,
    this.checked,
    this.fields = const {},
  });

  final String url;
  final CataloguePublisher publisher;

  /// When the page was read.
  final DateTime? checked;

  /// The record fields this page gives: `manufacturer`, `model`,
  /// `equipmentType`, `attributes.<key>` or `links.<kind>`.
  final Set<String> fields;

  @override
  List<Object?> get props => [url, publisher, checked, fields];
}

/// The maker's pages for a model. Only https links reach the app.
class EquipmentCatalogueLinks extends Equatable {
  const EquipmentCatalogueLinks({this.product, this.manual, this.support});

  final String? product;
  final String? manual;
  final String? support;

  bool get isEmpty => product == null && manual == null && support == null;

  @override
  List<Object?> get props => [product, manual, support];
}

/// One model in the built-in equipment catalogue (issue #5118).
class EquipmentCatalogueRecord extends Equatable {
  const EquipmentCatalogueRecord({
    required this.id,
    required this.manufacturer,
    required this.model,
    required this.type,
    this.manufacturerAliases = const [],
    this.aliases = const [],
    this.attributes = const {},
    this.links = const EquipmentCatalogueLinks(),
    this.firmwareId,
    this.sources = const [],
  });

  /// Permanent once published: an item linked to the record stores it.
  final String id;
  final String manufacturer;
  final List<String> manufacturerAliases;
  final String model;
  final List<String> aliases;
  final EquipmentType type;

  /// Curated attribute values in storage units: a [String] for text and
  /// choice keys, a [num] for numbers, a [bool] for flags.
  final Map<String, Object> attributes;
  final EquipmentCatalogueLinks links;

  /// The same model's id in submersion-app/firmware-catalogue.
  final String? firmwareId;
  final List<EquipmentCatalogueSource> sources;

  EquipmentCatalogueRecord copyWith({
    String? id,
    String? manufacturer,
    List<String>? manufacturerAliases,
    String? model,
    List<String>? aliases,
    EquipmentType? type,
    Map<String, Object>? attributes,
    EquipmentCatalogueLinks? links,
    String? firmwareId,
    List<EquipmentCatalogueSource>? sources,
  }) => EquipmentCatalogueRecord(
    id: id ?? this.id,
    manufacturer: manufacturer ?? this.manufacturer,
    manufacturerAliases: manufacturerAliases ?? this.manufacturerAliases,
    model: model ?? this.model,
    aliases: aliases ?? this.aliases,
    type: type ?? this.type,
    attributes: attributes ?? this.attributes,
    links: links ?? this.links,
    firmwareId: firmwareId ?? this.firmwareId,
    sources: sources ?? this.sources,
  );

  /// The record's value for [key] as the app stores an attribute, or null
  /// when the record has none.
  EquipmentAttribute? attributeFor(String key) {
    final value = attributes[key];
    if (value == null) return null;
    final kind = EquipmentAttributeCatalog.defFor(key)?.kind;
    return EquipmentAttribute(
      id: '',
      equipmentId: '',
      key: key,
      valueText: value is String ? value : null,
      valueNum: switch (value) {
        final bool flag => flag ? 1 : 0,
        final num number when kind != AttributeKind.text => number.toDouble(),
        _ => null,
      },
    );
  }

  @override
  List<Object?> get props => [
    id,
    manufacturer,
    manufacturerAliases,
    model,
    aliases,
    type,
    attributes,
    links,
    firmwareId,
    sources,
  ];
}

/// A whole catalogue file as the app reads it.
class EquipmentCatalogueFile extends Equatable {
  const EquipmentCatalogueFile({
    required this.format,
    required this.generatedAt,
    required this.records,
  });

  final int format;
  final DateTime generatedAt;
  final List<EquipmentCatalogueRecord> records;

  @override
  List<Object?> get props => [format, generatedAt, records];
}
