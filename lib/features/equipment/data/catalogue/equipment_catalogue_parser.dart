import 'dart:convert';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/catalogue/catalogue_attribute_keys.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_record.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';

/// The equipment catalogue format this build reads. A file of another
/// format is ignored whole: the app keeps the copy it has.
const int kSupportedEquipmentCatalogueFormat = 1;

/// Reads a catalogue file, or null when it is not JSON, not a catalogue or
/// of a format this build does not know.
///
/// A record that is not well formed is skipped and the rest kept, as the
/// site catalogue's parser does. Within a record, a link that is not https
/// and an attribute value the app's attribute catalogue would not hold for
/// that type are dropped; unknown keys are ignored, so a later format can
/// add fields without breaking this build.
EquipmentCatalogueFile? parseEquipmentCatalogue(String text) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  if (decoded['format'] != kSupportedEquipmentCatalogueFormat) return null;
  final generatedAt = _date(decoded['generatedAt']);
  final records = decoded['records'];
  if (generatedAt == null || records is! List) return null;

  final seen = <String>{};
  final parsed = <EquipmentCatalogueRecord>[];
  for (final raw in records) {
    final record = _record(raw);
    if (record != null && seen.add(record.id)) parsed.add(record);
  }
  return EquipmentCatalogueFile(
    format: kSupportedEquipmentCatalogueFormat,
    generatedAt: generatedAt,
    records: List.unmodifiable(parsed),
  );
}

EquipmentCatalogueRecord? _record(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  final id = _text(raw['id']);
  final manufacturer = _text(raw['manufacturer']);
  final model = _text(raw['model']);
  final type = EquipmentType.values.where(
    (t) => t.name == raw['equipmentType'],
  );
  if (id == null || manufacturer == null || model == null || type.isEmpty) {
    return null;
  }
  final links = raw['links'];
  return EquipmentCatalogueRecord(
    id: id,
    manufacturer: manufacturer,
    manufacturerAliases: _texts(raw['manufacturerAliases']),
    model: model,
    aliases: _texts(raw['aliases']),
    type: type.single,
    attributes: _attributes(type.single, raw['attributes']),
    links: links is Map<String, dynamic>
        ? EquipmentCatalogueLinks(
            product: _https(links['product']),
            manual: _https(links['manual']),
            support: _https(links['support']),
          )
        : const EquipmentCatalogueLinks(),
    firmwareId: _text(raw['firmwareId']),
    sources: [
      if (raw['sources'] case final List<dynamic> sources)
        for (final source in sources)
          if (_source(source) case final parsed?) parsed,
    ],
  );
}

Map<String, Object> _attributes(EquipmentType type, Object? raw) {
  if (raw is! Map<String, dynamic>) return const {};
  final defs = {for (final def in catalogueAttributeDefs(type)) def.key: def};
  return Map.unmodifiable({
    for (final MapEntry(:key, :value) in raw.entries)
      if (defs[key] case final def? when _fits(def, value))
        key: value as Object,
  });
}

bool _fits(EquipmentAttributeDef def, Object? value) => switch (def.kind) {
  AttributeKind.number => value is num,
  AttributeKind.flag => value is bool,
  AttributeKind.focalLength => value is num || value is String,
  AttributeKind.choice => value is String && def.choiceKeys.contains(value),
  _ => value is String && value.trim().isNotEmpty,
};

EquipmentCatalogueSource? _source(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  final url = _https(raw['url']);
  final publisher = CataloguePublisher.values.where(
    (p) => p.name == raw['publisher'],
  );
  if (url == null || publisher.isEmpty) return null;
  return EquipmentCatalogueSource(
    url: url,
    publisher: publisher.single,
    checked: _date(raw['checked']),
    fields: _texts(raw['fields']).toSet(),
  );
}

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _texts(Object? value) => [
  if (value is List)
    for (final item in value)
      if (_text(item) case final text?) text,
];

/// Only an https link with a host is kept: anything else could open a
/// local file, run script or reach a plain-text page.
String? _https(Object? value) {
  final text = _text(value);
  if (text == null) return null;
  final uri = Uri.tryParse(text);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  if (uri.userInfo.isNotEmpty) return null;
  return text;
}

/// A date-only value ("2026-11-27") is that calendar day in UTC.
DateTime? _date(Object? value) {
  final text = _text(value);
  if (text == null) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;
  return parsed.isUtc
      ? parsed
      : DateTime.utc(parsed.year, parsed.month, parsed.day);
}
