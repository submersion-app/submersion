import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/firmware/domain/firmware_catalogue.dart';

/// The firmware catalogue's format 1 (issue #5104). The sample file is shared
/// byte for byte with submersion-app/firmware-catalogue, so this parser and
/// that repository's validator read the same contract.
void main() {
  late String sample;

  setUpAll(() {
    sample = File(
      p.join('test', 'fixtures', 'firmware_catalogue', 'sample.json'),
    ).readAsStringSync();
  });

  Map<String, dynamic> sampleJson() =>
      jsonDecode(sample) as Map<String, dynamic>;

  String withModel(Map<String, dynamic> model) => jsonEncode({
    'format': 1,
    'models': [model],
  });

  Map<String, dynamic> perdixJson() =>
      (sampleJson()['models'] as List).first as Map<String, dynamic>;

  test('parses the shared sample', () {
    final catalogue = FirmwareCatalogue.parse(sample)!;

    expect(catalogue.format, 1);
    expect(catalogue.generatedAt, DateTime.utc(2026, 11, 27));
    expect(catalogue.models, hasLength(2));

    final perdix = catalogue.models.first;
    expect(perdix.id, 'example-perdix-2');
    expect(perdix.manufacturer, 'Shearwater');
    expect(perdix.manufacturerAliases, ['Shearwater Research']);
    expect(perdix.model, 'Perdix 2');
    expect(perdix.aliases, ['Perdix2']);
    expect(perdix.equipmentTypes, {EquipmentType.computer});
    expect(perdix.firmwarePageUrl, 'https://example.com/perdix-2/firmware');
    expect(perdix.releases.map((r) => r.version), ['V95', 'V94', 'V92']);

    final latest = perdix.releases.first;
    expect(latest.reportedAs, ['95']);
    expect(latest.date, DateTime.utc(2026, 10, 1));
    expect(latest.safety, isTrue);
    expect(latest.notesUrl, 'https://example.com/perdix-2/v95-notes');
    expect(
      latest.instructionsUrl,
      'https://example.com/perdix-2/how-to-update',
    );
    expect(
      latest.summary,
      'Sample release used by tests in both repositories.',
    );
    expect(perdix.releases[1].safety, isFalse);
    expect(perdix.releases[2].notesUrl, isNull);

    final dpv = catalogue.models[1];
    expect(dpv.equipmentTypes, {EquipmentType.dpv});
    expect(dpv.manufacturerAliases, isEmpty);
    expect(dpv.aliases, isEmpty);
    expect(dpv.firmwarePageUrl, isNull);
  });

  test('ignores unknown keys', () {
    final json = sampleJson()..['somethingNew'] = {'nested': true};
    expect(FirmwareCatalogue.parse(jsonEncode(json)), isNotNull);
  });

  test('an unknown format returns null', () {
    expect(FirmwareCatalogue.parse('{"format":2,"models":[]}'), isNull);
    expect(FirmwareCatalogue.parse('{"models":[]}'), isNull);
  });

  test('a malformed file returns null rather than half of it', () {
    expect(FirmwareCatalogue.parse('not json'), isNull);
    expect(FirmwareCatalogue.parse('[]'), isNull);
    expect(FirmwareCatalogue.parse('{"format":1}'), isNull);

    final noReleases = perdixJson()..remove('releases');
    expect(FirmwareCatalogue.parse(withModel(noReleases)), isNull);

    final noVersion = perdixJson();
    ((noVersion['releases'] as List).first as Map).remove('version');
    expect(FirmwareCatalogue.parse(withModel(noVersion)), isNull);

    final badSafety = perdixJson();
    ((badSafety['releases'] as List).first as Map)['safety'] = 'yes';
    expect(FirmwareCatalogue.parse(withModel(badSafety)), isNull);
  });

  test('unknown equipment type names are dropped', () {
    final mixed = perdixJson()..['equipmentTypes'] = ['computer', 'jetpack'];
    expect(
      FirmwareCatalogue.parse(withModel(mixed))!.models.single.equipmentTypes,
      {EquipmentType.computer},
    );

    final none = perdixJson()..['equipmentTypes'] = ['jetpack'];
    expect(FirmwareCatalogue.parse(withModel(none))!.models, isEmpty);
  });

  test('links that are not web links are dropped', () {
    final json = perdixJson();
    ((json['releases'] as List).first as Map)['notesUrl'] =
        'javascript:alert(1)';
    json['firmwarePageUrl'] = 'file:///etc/passwd';
    final perdix = FirmwareCatalogue.parse(withModel(json))!.models.single;
    expect(perdix.releases.first.notesUrl, isNull);
    expect(perdix.firmwarePageUrl, isNull);
  });
}
