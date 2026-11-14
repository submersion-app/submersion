import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../tool/demo_data/src/story/catalog.dart';

/// The demo logbook's trips are made of places people dive. The built-in
/// catalogue also holds charted wrecks and reef deployments by the
/// thousand; a demo trip must not be planned around those.
void main() {
  test('the demo catalogue reads dive sites and leaves register records '
      'out', () {
    final dir = Directory.systemTemp.createTempSync('demo_catalogue');
    addTearDown(() => dir.deleteSync(recursive: true));
    void write(String name, Object doc) =>
        File(p.join(dir.path, name)).writeAsStringSync(jsonEncode(doc));
    Map<String, Object?> site(String id, String name, [String? kind]) => {
      'id': id,
      'name': name,
      'lat': 12.0,
      'lon': -68.0,
      'country_code': 'BQ',
      'kind': ?kind,
    };
    write('site_catalogue.json', {
      'sites': [
        site('osm_node_1', 'Salt Pier'),
        site('ukho_1', 'HMS Exeter', 'register'),
        site('osm_node_2', 'Hilma Hooker', 'site'),
        site('usreef_al_x', 'Pmid 07-046', 'register'),
      ],
    });
    write('dive_centers.json', {'centers': <Object?>[]});
    write('species.json', {'species': <Object?>[]});

    final catalog = Catalog.load(dir.path);

    expect(catalog.sites.map((s) => s.id), ['osm_node_1', 'osm_node_2']);
    // Their names are not public vocabulary for the privacy check either.
    expect(catalog.publicStrings, isNot(contains('HMS Exeter')));
  });
}
