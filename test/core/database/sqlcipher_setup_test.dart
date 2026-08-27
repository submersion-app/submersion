import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:submersion/core/database/sqlcipher_setup.dart';

void main() {
  test('the linked sqlite3 is a SQLCipher build', () {
    // SQLCipher selection moved from a runtime, per-isolate loader override
    // to the sqlite3 build hook (`hooks: user_defines: sqlite3: source:
    // sqlcipher`). That makes it a build-time property with no Dart call site
    // to assert on, so assert the observable consequence instead: only a
    // SQLCipher build answers `PRAGMA cipher_version`.
    //
    // Guards the failure mode the hook config introduces -- silently building
    // against vanilla SQLite, where every encrypted database would fail to
    // open at runtime.
    final db = sqlite3.openInMemory();
    addTearDown(db.close);

    expect(db.select('PRAGMA cipher_version'), isNotEmpty);
  });

  test('cipherKeyPragma formats a raw 32-byte key as SQLCipher hex', () {
    final keyHex = 'ab' * 32;

    expect(cipherKeyPragma(keyHex), 'PRAGMA key = "x\'$keyHex\'"');
  });
}
