import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/firmware/data/firmware_catalogue_store.dart';

/// The last good catalogue, kept on disk between launches (issue #5104).
void main() {
  late Directory dir;
  late String sample;

  setUpAll(() {
    sample = File(
      p.join('test', 'fixtures', 'firmware_catalogue', 'sample.json'),
    ).readAsStringSync();
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('firmware_store_test');
    addTearDown(() => dir.delete(recursive: true));
  });

  test('an empty store has no catalogue and no fetch time', () async {
    final store = FirmwareCatalogueStore(dir);
    expect(await store.load(), isNull);
    expect(await store.lastFetchedAt(), isNull);
  });

  test('a saved file loads back with its fetch time', () async {
    final at = DateTime.utc(2026, 11, 27, 9, 30);
    await FirmwareCatalogueStore(dir).save(sample, at);

    final store = FirmwareCatalogueStore(dir);
    expect((await store.load())!.models, hasLength(2));
    expect(await store.lastFetchedAt(), at);
  });

  test('a corrupt file on disk loads as nothing', () async {
    final store = FirmwareCatalogueStore(dir);
    await store.save(sample, DateTime.utc(2026, 11, 27));
    await File(
      p.join(dir.path, 'firmware', 'firmware_catalogue.json'),
    ).writeAsString('{"format":1,"mod');
    await File(
      p.join(dir.path, 'firmware', 'firmware_catalogue.fetched'),
    ).writeAsString('yesterday');

    expect(await store.load(), isNull);
    expect(await store.lastFetchedAt(), isNull);
  });
}
