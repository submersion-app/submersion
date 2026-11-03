import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/web_database_status.dart';

void main() {
  tearDown(WebDatabaseStatusHolder.clear);

  test('only in-memory storage does not persist', () {
    for (final storage in WebDatabaseStorage.values) {
      expect(
        WebDatabaseStatus(storage: storage).persists,
        storage != WebDatabaseStorage.inMemory,
        reason: storage.name,
      );
    }
  });

  test('storage names map to drift names and unknown otherwise', () {
    expect(
      WebDatabaseStorage.fromName('opfsShared'),
      WebDatabaseStorage.opfsShared,
    );
    expect(
      WebDatabaseStorage.fromName('opfsLocks'),
      WebDatabaseStorage.opfsLocks,
    );
    expect(
      WebDatabaseStorage.fromName('inMemory'),
      WebDatabaseStorage.inMemory,
    );
    expect(WebDatabaseStorage.fromName('martian'), WebDatabaseStorage.unknown);
  });

  test('the provider follows the holder', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(webDatabaseStatusProvider), isNull);
    const status = WebDatabaseStatus(
      storage: WebDatabaseStorage.opfsShared,
      missingFeatures: {'sharedArrayBuffers'},
    );
    WebDatabaseStatusHolder.record(status);
    expect(container.read(webDatabaseStatusProvider), status);
    expect(
      container.read(webDatabaseStatusProvider)!.missingFeatures,
      contains('sharedArrayBuffers'),
    );
  });
}
