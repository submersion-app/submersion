import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';
import 'package:submersion/core/services/export/csv/dive_csv_columns.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/universal_import/data/csv/presets/built_in_presets.dart';
import 'package:submersion/features/universal_import/data/csv/presets/preset_registry.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/parsers/csv_import_parser.dart';

/// Round trip of Submersion's own dive CSV export through the CSV import
/// pipeline (#1814): export, detect, parse, compare.
void main() {
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 7,
    name: 'Probe dive',
    dateTime: DateTime(2026, 3, 28, 10, 15),
    bottomTime: const Duration(minutes: 45),
    runtime: const Duration(minutes: 50),
    maxDepth: 25.0,
    avgDepth: 14.0,
    waterTemp: 22,
    airTemp: 28,
    visibilityMeters: 15.0,
    visibility: Visibility.good,
    diveTypeIds: const ['night', 'deep_wreck'],
    buddy: 'Alex',
    diveMaster: 'Sam',
    rating: 4,
    notes: 'Turtle at the wall',
    site: const DiveSite(
      id: 'site-1',
      name: 'Blue Hole',
      city: 'Victoria',
      region: 'Gozo',
      country: 'Malta',
    ),
    tanks: const [
      DiveTank(
        id: 'tank-1',
        volume: 12,
        startPressure: 200,
        endPressure: 50,
        gasMix: GasMix(o2: 32),
      ),
    ],
    diveComputerModel: 'Perdix 2',
    diveComputerSerial: 'SN-123',
    diveComputerFirmware: '94',
    windSpeed: 5.0,
    windDirection: CurrentDirection.northEast,
    cloudCover: CloudCover.partlyCloudy,
    precipitation: Precipitation.lightRain,
    humidity: 70,
    weatherDescription: 'Sunny',
    customFields: const [
      DiveCustomField(id: 'cf-1', key: 'camera', value: 'GoPro'),
      // Starts with '=', so the export guards it against CSV injection.
      DiveCustomField(id: 'cf-2', key: 'formula', value: '=1+1', sortOrder: 1),
    ],
  );

  late String csv;
  late List<String> headers;

  List<String> headersOf(String content) => const CsvToListConverter()
      .convert(content)
      .first
      .map((h) => h.toString().trim())
      .toList();

  Future<ImportPayload> parse(String content) =>
      CsvImportParser().parse(Uint8List.fromList(utf8.encode(content)));

  setUp(() {
    csv = CsvExportService().generateDivesCsvContent([dive]);
    headers = headersOf(csv);
  });

  test('the export is detected as the Submersion preset', () {
    final matches = PresetRegistry(
      builtInPresets: builtInCsvPresets,
    ).detectPreset(headers);

    expect(matches, isNotEmpty);
    expect(matches.first.preset.id, 'submersion_native');
  });

  test('every exported dive column is mapped by the Submersion preset', () {
    final preset = builtInCsvPresets.firstWhere(
      (p) => p.id == 'submersion_native',
    );
    final mapped = preset.primaryMapping!.columns
        .map((c) => c.sourceColumn.toLowerCase())
        .toSet();

    // Location is display text; the site city, region and country columns
    // carry its data. Custom field columns are read by prefix, not mapping.
    final unmapped = headers
        .where((h) => h != DiveCsvColumns.location)
        .where((h) => !h.startsWith(DiveCsvColumns.customFieldPrefix))
        .where((h) => !mapped.contains(h.toLowerCase()))
        .toList();
    expect(unmapped, isEmpty, reason: 'Export columns with no mapping');

    final lowerHeaders = headers.map((h) => h.toLowerCase()).toSet();
    final missing = preset.signatureHeaders
        .where((s) => !lowerHeaders.contains(s.toLowerCase()))
        .toList();
    expect(missing, isEmpty, reason: 'Signature headers the export lacks');
  });

  test('parsing the export keeps every exported field', () async {
    final payload = await parse(csv);

    expect(payload.warnings, isEmpty);
    expect(payload.metadata['sourceApp'], SourceApp.submersion.name);

    final dives = payload.entitiesOf(ImportEntityType.dives);
    expect(dives, hasLength(1));
    final d = dives.single;

    expect(d['diveNumber'], 7);
    expect(d['name'], 'Probe dive');
    expect(d['dateTime'], DateTime.utc(2026, 3, 28, 10, 15));
    expect(d['duration'], const Duration(minutes: 45));
    expect(d['runtime'], const Duration(minutes: 50));
    expect(d['maxDepth'], 25.0);
    expect(d['avgDepth'], 14.0);
    expect(d['waterTemp'], 22.0);
    expect(d['airTemp'], 28.0);
    expect(d['visibilityMeters'], 15.0);
    expect(d['visibility'], 'good');
    expect(d['diveTypeIds'], ['night', 'deep_wreck']);
    // Buddies become linked buddy entities; the dive master is linked by
    // name with the dive guide role.
    final buddy = payload.entitiesOf(ImportEntityType.buddies).single;
    expect(buddy['name'], 'Alex');
    expect(d['buddyRefs'], [buddy['id']]);
    expect(d['unmatchedDiveGuideNames'], ['Sam']);
    expect(d['rating'], 4);
    expect(d['notes'], 'Turtle at the wall');
    expect(d['siteName'], 'Blue Hole');
    expect(d['diveComputerModel'], 'Perdix 2');
    expect(d['diveComputerSerial'], 'SN-123');
    expect(d['diveComputerFirmware'], '94');
    expect(d['windSpeed'], 5.0);
    expect(d['windDirection'], 'northEast');
    expect(d['cloudCover'], 'partlyCloudy');
    expect(d['precipitation'], 'lightRain');
    expect(d['humidity'], 70.0);
    expect(d['weatherDescription'], 'Sunny');
    expect(d['customFields'], [
      {'key': 'camera', 'value': 'GoPro'},
      {'key': 'formula', 'value': '=1+1'},
    ]);

    final tank = (d['tanks'] as List).single as Map<String, dynamic>;
    expect(tank['volume'], 12.0);
    expect(tank['startPressure'], 200.0);
    expect(tank['endPressure'], 50.0);
    expect(tank['o2Percent'], 32.0);
    // The importer reads the tank's gas from this key alone.
    expect(tank['gasMix'], const GasMix(o2: 32));

    final site = payload.entitiesOf(ImportEntityType.sites).single;
    expect(site['name'], 'Blue Hole');
    expect(site['city'], 'Victoria');
    expect(site['region'], 'Gozo');
    expect(site['country'], 'Malta');
    expect(d['siteId'], site['id']);

    final types = payload.entitiesOf(ImportEntityType.diveTypes);
    expect(types.map((t) => (t['id'], t['name'])), [
      ('night', 'Night'),
      ('deep_wreck', 'Deep wreck'),
    ]);
  });

  test('a pre-#1814 export without the site place columns still '
      'round-trips', () async {
    const placeColumns = {
      DiveCsvColumns.siteCity,
      DiveCsvColumns.siteRegion,
      DiveCsvColumns.siteCountry,
    };
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
    ).convert(csv);
    final legacy = const ListToCsvConverter().convert([
      for (final row in rows)
        [
          for (var i = 0; i < row.length; i++)
            if (!placeColumns.contains(headers[i])) row[i],
        ],
    ]);

    final matches = PresetRegistry(
      builtInPresets: builtInCsvPresets,
    ).detectPreset(headersOf(legacy));
    expect(matches.first.preset.id, 'submersion_native');

    final payload = await parse(legacy);
    final d = payload.entitiesOf(ImportEntityType.dives).single;
    expect(d['duration'], const Duration(minutes: 45));
    expect(d['runtime'], const Duration(minutes: 50));
    expect(d['name'], 'Probe dive');
  });
}
