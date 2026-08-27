import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';

void main() {
  test('CloudProviderType has an s3 variant whose persisted name is s3', () {
    // SyncInitializer persists provider.name to SharedPreferences and
    // sync_metadata.sync_provider; this pins the wire string.
    expect(
      CloudProviderType.values.map((p) => p.name),
      containsAll(['icloud', 'googledrive', 's3']),
    );
  });
}
