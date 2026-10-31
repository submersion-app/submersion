import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/services/payload_merger.dart';

/// A name held once on each side of a batch folds only when nothing says the
/// two are different places (#4015).
void main() {
  const merger = PayloadMerger();

  FilePayload file(String id, Map<String, dynamic> site) => FilePayload(
    fileId: id,
    fileName: '$id.csv',
    payload: ImportPayload(
      entities: {
        ImportEntityType.dives: [
          {
            'dateTime': DateTime.utc(2026, 1, 1, 10),
            'site': {'uddfId': 'site_1'},
          },
        ],
        ImportEntityType.sites: [
          {'uddfId': 'site_1', 'name': 'Blue Hole', ...site},
        ],
      },
    ),
  );

  test('two files placing a name in two countries keep both sites', () {
    final merged = merger.merge([
      file('a', {'country': 'Egypt'}),
      file('b', {'country': 'Belize'}),
    ]);

    final sites = merged.entitiesOf(ImportEntityType.sites);
    expect(sites.map((s) => s['country']), ['Egypt', 'Belize']);
    expect(merged.entitiesOf(ImportEntityType.dives).map((d) => d['site']), [
      {'uddfId': 'a:site_1'},
      {'uddfId': 'b:site_1'},
    ]);
  });

  test('a shared source id joins the namesake in the same place', () {
    // Every dives CSV numbers its sites from csv-site-0, so ids repeat across
    // files without meaning the same site.
    final merged = merger.merge([
      file('a', {'country': 'Egypt'}),
      file('b', {'country': 'Belize'}),
      file('c', {'country': 'Belize'}),
    ]);

    final sites = merged.entitiesOf(ImportEntityType.sites);
    expect(sites.map((s) => s['country']), ['Egypt', 'Belize']);
    expect(merged.entitiesOf(ImportEntityType.dives).last['site'], {
      'uddfId': 'b:site_1',
    });
  });

  test('both namesakes in two files pair by place, however each file '
      'numbered them', () {
    FilePayload both(String id, String first, String second) => FilePayload(
      fileId: id,
      fileName: '$id.csv',
      payload: ImportPayload(
        entities: {
          ImportEntityType.sites: [
            {'uddfId': 'csv-site-0', 'name': 'Blue Hole', 'country': first},
            {'uddfId': 'csv-site-1', 'name': 'Blue Hole', 'country': second},
          ],
        },
      ),
    );

    final merged = merger.merge([
      both('a', 'Egypt', 'Belize'),
      both('b', 'Belize', 'Egypt'),
    ]);

    expect(merged.entitiesOf(ImportEntityType.sites).map((s) => s['country']), [
      'Egypt',
      'Belize',
    ]);
  });

  test('namesakes that state no place do not pair on that', () {
    FilePayload unplaced(String id) => FilePayload(
      fileId: id,
      fileName: '$id.uddf',
      payload: ImportPayload(
        entities: {
          ImportEntityType.sites: [
            {'uddfId': '$id-1', 'name': 'Blue Hole'},
            {'uddfId': '$id-2', 'name': 'Blue Hole'},
          ],
        },
      ),
    );

    final merged = merger.merge([unplaced('a'), unplaced('b')]);

    expect(merged.entitiesOf(ImportEntityType.sites), hasLength(4));
  });

  test('the same place in two files still folds', () {
    final merged = merger.merge([
      file('a', {'country': 'Egypt'}),
      file('b', {'country': 'egypt', 'region': 'South Sinai'}),
    ]);

    final site = merged.entitiesOf(ImportEntityType.sites).single;
    expect(site['country'], 'Egypt');
    expect(site['region'], 'South Sinai');
  });

  test('a file that names no place folds into one that does', () {
    final merged = merger.merge([
      file('a', {}),
      file('b', {'country': 'Belize'}),
    ]);

    final site = merged.entitiesOf(ImportEntityType.sites).single;
    expect(site['country'], 'Belize');
  });

  test('other entity types still fold on the name alone', () {
    FilePayload buddyFile(String id, String country) => FilePayload(
      fileId: id,
      fileName: '$id.csv',
      payload: ImportPayload(
        entities: {
          ImportEntityType.buddies: [
            {'uddfId': 'b1', 'name': 'Ana', 'country': country},
          ],
        },
      ),
    );

    final merged = merger.merge([buddyFile('a', 'Egypt'), buddyFile('b', 'X')]);

    expect(merged.entitiesOf(ImportEntityType.buddies), hasLength(1));
  });
}
