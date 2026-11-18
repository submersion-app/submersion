import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';

/// The wizard rebuilds the importer's input from the payload; a UDDF file's
/// species catalogue (issue #4578) rides in its metadata and must come back,
/// or a custom species no dive sighted is lost on restore.
void main() {
  test('payloadToUddfResult carries the species catalogue', () {
    final result = UniversalAdapter.payloadToUddfResult(
      const ImportPayload(
        entities: {},
        metadata: {
          ImportPayload.speciesKey: [
            {'uddfId': 'species_s1', 'commonName': 'My Own Slug'},
            'not a row',
          ],
        },
      ),
    );

    expect(result.species.map((s) => s['commonName']), ['My Own Slug']);
  });

  test('payloadToUddfResult has no species without the metadata', () {
    final result = UniversalAdapter.payloadToUddfResult(
      const ImportPayload(entities: {}),
    );
    expect(result.species, isEmpty);
  });
}
