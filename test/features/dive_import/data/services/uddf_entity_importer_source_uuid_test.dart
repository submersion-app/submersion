import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';

void main() {
  test('UddfEntityImportResult defaults sourceUuidToDiveId to empty', () {
    const result = UddfEntityImportResult();
    expect(result.sourceUuidToDiveId, isEmpty);
  });

  test('UddfEntityImportResult carries sourceUuidToDiveId', () {
    const result = UddfEntityImportResult(
      dives: 2,
      diveIds: ['db-1', 'db-2'],
      sourceUuidToDiveId: {'src-1': 'db-1', 'src-2': 'db-2'},
    );
    expect(result.sourceUuidToDiveId, {'src-1': 'db-1', 'src-2': 'db-2'});
    expect(result.diveIds, ['db-1', 'db-2']);
  });
}
