import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_dives_writer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_dives_csv_parser.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

Dive _diveAt(String id, DiveSite site, {int day = 1}) =>
    Dive(id: id, dateTime: DateTime.utc(2026, 1, day, 10), site: site);

Future<ImportPayload> _roundTrip(List<Dive> dives) {
  final csv = CsvDivesWriter(CsvExportUnits.metric).write(dives);
  return const SubmersionDivesCsvParser().parse(_bytes(csv));
}

Object? _siteRef(Map<String, dynamic> dive) =>
    (dive['site'] as Map<String, dynamic>)['uddfId'];

/// A site's name says nothing about which place it is (#4015).
void main() {
  const dahab = DiveSite(
    id: 's1',
    name: 'Blue Hole',
    city: 'Dahab',
    country: 'Egypt',
  );
  const belize = DiveSite(
    id: 's2',
    name: 'Blue Hole',
    city: 'Lighthouse Reef',
    country: 'Belize',
  );

  test('same-name sites in two countries stay two sites', () async {
    final payload = await _roundTrip([
      _diveAt('d1', dahab),
      _diveAt('d2', belize, day: 2),
    ]);

    final sites = payload.entitiesOf(ImportEntityType.sites);
    final dives = payload.entitiesOf(ImportEntityType.dives);
    expect(sites.map((s) => s['country']), ['Egypt', 'Belize']);
    expect(sites.map((s) => s['city']), ['Dahab', 'Lighthouse Reef']);
    expect(sites.map((s) => s['uddfId']).toSet(), hasLength(2));
    expect(_siteRef(dives.first), sites.first['uddfId']);
    expect(_siteRef(dives.last), sites.last['uddfId']);
    expect(payload.warnings, isEmpty);
  });

  test('a difference in any one place field keeps sites apart', () async {
    const base = DiveSite(
      id: 'a',
      name: 'Reef',
      city: 'City',
      island: 'Island',
      region: 'Region',
      country: 'Country',
    );
    final payload = await _roundTrip([
      _diveAt('d0', base),
      _diveAt('d1', base.copyWith(id: 'b', city: 'Other city')),
      _diveAt('d2', base.copyWith(id: 'c', island: 'Other island')),
      _diveAt('d3', base.copyWith(id: 'd', region: 'Other region')),
      _diveAt('d4', base.copyWith(id: 'e', country: 'Other country')),
    ]);

    expect(payload.entitiesOf(ImportEntityType.sites), hasLength(5));
  });

  test('a site with no place stays apart from its placed namesake', () async {
    // One site writes the same cells on every dive, so a blank is a site the
    // diver left unplaced, not a gap in the row.
    final payload = await _roundTrip([
      _diveAt('d1', dahab),
      _diveAt('d2', const DiveSite(id: 's3', name: 'Blue Hole'), day: 2),
    ]);

    expect(
      payload.entitiesOf(ImportEntityType.sites).map((s) => s['country']),
      ['Egypt', null],
    );
  });

  test('every dive at one site still shares it', () async {
    final payload = await _roundTrip([
      _diveAt('d1', dahab),
      _diveAt('d2', belize, day: 2),
      _diveAt('d3', dahab, day: 3),
    ]);

    final sites = payload.entitiesOf(ImportEntityType.sites);
    final dives = payload.entitiesOf(ImportEntityType.dives);
    expect(sites, hasLength(2));
    expect(_siteRef(dives[2]), _siteRef(dives[0]));
  });

  test('a file without the place columns splits on Location', () async {
    final payload = await const SubmersionDivesCsvParser().parse(
      _bytes(
        'Dive Number,Date,Time,Site,Location\n'
        '1,2026-01-01,10:00,Blue Hole,"Dahab, Egypt"\n'
        '2,2026-01-02,10:00,Blue Hole,"Lighthouse Reef, Belize"\n'
        '3,2026-01-03,10:00,Blue Hole,"Dahab, Egypt"\n',
      ),
    );

    final sites = payload.entitiesOf(ImportEntityType.sites);
    expect(sites.map((s) => s['country']), ['Egypt', 'Belize']);
    expect(sites.map((s) => s['region']), ['Dahab', 'Lighthouse Reef']);
  });

  test('a name with no place to go on stays one site', () async {
    final payload = await const SubmersionDivesCsvParser().parse(
      _bytes(
        'Dive Number,Date,Time,Site\n'
        '1,2026-01-01,10:00,Blue Hole\n'
        '2,2026-01-02,10:00,Blue Hole\n',
      ),
    );

    expect(payload.entitiesOf(ImportEntityType.sites), hasLength(1));
  });
}
