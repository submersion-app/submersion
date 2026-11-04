import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/sqlite/raw_sqlite_web.dart';

/// The browser variant of the raw SQLite facade, imported directly.
void main() {
  test('RawSqlite is unavailable in a browser and every open throws', () {
    expect(RawSqlite.isAvailable, isFalse);
    expect(RawSqlite.openInMemory, throwsUnsupportedError);
    expect(() => RawSqlite.open('probe.db'), throwsUnsupportedError);
  });
}
