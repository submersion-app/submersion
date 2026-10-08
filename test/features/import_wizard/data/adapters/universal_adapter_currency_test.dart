import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';

/// The wizard rebuilds the importer's input from the payload; certification
/// currency rows (issue #2267) ride in its metadata and must come back.
void main() {
  test('payloadToUddfResult carries the currency rows', () {
    final result = UniversalAdapter.payloadToUddfResult(
      const ImportPayload(
        entities: {},
        metadata: {
          ImportPayload.currencyRulesKey: [
            {'id': 'custom-1'},
          ],
          ImportPayload.currencyPrefsKey: [
            {'id': 'p1', 'certificationRef': 'cert_c1'},
          ],
          ImportPayload.currencyEventsKey: [
            {'id': 'e1', 'certificationRef': 'cert_c1'},
            'not a row',
          ],
        },
      ),
    );

    expect(result.currencyRules.single['id'], 'custom-1');
    expect(result.currencyPrefs.single['certificationRef'], 'cert_c1');
    expect(result.currencyEvents.map((e) => e['id']), ['e1']);
  });

  test('payloadToUddfResult is empty-handed without the metadata', () {
    final result = UniversalAdapter.payloadToUddfResult(
      const ImportPayload(entities: {}),
    );
    expect(result.currencyRules, isEmpty);
    expect(result.currencyPrefs, isEmpty);
    expect(result.currencyEvents, isEmpty);
  });
}
