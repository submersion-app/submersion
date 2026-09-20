/// A site's features inside one CSV cell (issue #2200).
///
/// The sites CSV is one row per site, and a site has many features, so they
/// ride in a single column the way an equipment row's attributes do: items
/// joined by `'; '` through [joinCsvList], each item a `key=value` list
/// joined by `'|'`.
///
/// Coordinates are written at the six decimals the Latitude and Longitude
/// columns use. Depth is metres whatever the row's other units are: the
/// cell has no header to hang a unit symbol on, so it carries the stored
/// value and says so here rather than guessing on the way back in.
///
/// A feature keeps the raw type name it was stored with, never the parsed
/// enum, so a type from a newer build survives a round trip through an
/// older one.
library;

import 'package:submersion/core/services/export/csv/codec/csv_list_codec.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';

const _pairSeparator = '|';
const _keyValueSeparator = '=';

String _escapePair(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll(_pairSeparator, r'\|');

String _unescapePair(String value) {
  if (!value.contains(r'\')) return value;
  final out = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    if (value[i] == r'\' && i + 1 < value.length) {
      out.write(value[i + 1]);
      i++;
    } else {
      out.write(value[i]);
    }
  }
  return out.toString();
}

/// Splits one feature's `key=value` pairs, honouring an escaped separator.
List<String> _splitPairs(String item) {
  final parts = <String>[];
  var start = 0;
  for (var i = 0; i < item.length; i++) {
    if (item[i] != _pairSeparator) continue;
    var backslashes = 0;
    for (var j = i - 1; j >= start && item[j] == r'\'; j--) {
      backslashes++;
    }
    if (backslashes.isOdd) continue;
    parts.add(item.substring(start, i));
    start = i + 1;
  }
  parts.add(item.substring(start));
  return parts;
}

/// [features] as the sites CSV writes them, or an empty cell for none.
String encodeSiteFeatures(List<SiteFeature> features) => joinCsvList([
  for (final feature in features)
    [
      'type$_keyValueSeparator${_escapePair(feature.typeName)}',
      if (feature.name.isNotEmpty)
        'name$_keyValueSeparator${_escapePair(feature.name)}',
      'lat$_keyValueSeparator${feature.latitude.toStringAsFixed(6)}',
      'lon$_keyValueSeparator${feature.longitude.toStringAsFixed(6)}',
      if (feature.bearingDeg != null)
        'bearing$_keyValueSeparator${feature.bearingDeg}',
      if (feature.depthMeters != null)
        'depth_m$_keyValueSeparator${feature.depthMeters}',
      if (feature.notes.isNotEmpty)
        'notes$_keyValueSeparator${_escapePair(feature.notes)}',
    ].join(_pairSeparator),
]);

/// [cell] back into the feature maps the importer restores, in the shape
/// the UDDF parser produces so one restore path serves both formats.
///
/// A feature without a type or without both coordinates is dropped rather
/// than restored at 0,0.
List<Map<String, dynamic>> decodeSiteFeatures(String cell) {
  final features = <Map<String, dynamic>>[];
  for (final item in splitCsvList(cell)) {
    final fields = <String, String>{};
    for (final pair in _splitPairs(unescapeCsvListItem(item))) {
      final at = pair.indexOf(_keyValueSeparator);
      if (at <= 0) continue;
      fields[pair.substring(0, at)] = _unescapePair(pair.substring(at + 1));
    }
    final typeName = fields['type']?.trim();
    final latitude = double.tryParse(fields['lat'] ?? '');
    final longitude = double.tryParse(fields['lon'] ?? '');
    if (typeName == null || typeName.isEmpty) continue;
    if (latitude == null || longitude == null) continue;
    features.add(
      <String, dynamic>{
        'typeName': typeName,
        'name': fields['name'] ?? '',
        'latitude': latitude,
        'longitude': longitude,
        'bearingDeg': double.tryParse(fields['bearing'] ?? ''),
        'depthMeters': double.tryParse(fields['depth_m'] ?? ''),
        'notes': fields['notes'] ?? '',
      }..removeWhere((_, value) => value == null),
    );
  }
  return features;
}
