import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:submersion/core/database/sqlcipher_setup.dart';

void main() {
  // Databases in the field were encrypted by sqlcipher_flutter_libs 0.6.8,
  // which bundled SQLCipher 4.10.0; the sqlite3 build hook now supplies
  // 4.17.0. A file only opens under a different SQLCipher build when the
  // on-disk parameters match, so pin the ones that define the format.
  //
  // The app keys connections with a RAW key (`PRAGMA key = "x'<64 hex>'"`,
  // see cipherKeyPragma), which bypasses the KDF, so kdf_iter is not part of
  // the on-disk compatibility surface -- page size, HMAC and cipher are.
  test('SQLCipher 4 on-disk defaults are unchanged', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);

    // SQLCipher reports its cipher settings only on a keyed connection, so key
    // this one exactly the way the app does -- with a raw 32-byte key.
    db.execute(cipherKeyPragma('ab' * 32));

    String pragma(String name) =>
        db.select('PRAGMA $name').first.values.first.toString();

    expect(pragma('cipher_page_size'), '4096');
    expect(pragma('cipher_hmac_algorithm'), 'HMAC_SHA512');
    expect(pragma('cipher_kdf_algorithm'), 'PBKDF2_HMAC_SHA512');
    expect(
      pragma('cipher_version'),
      startsWith('4.'),
      reason: 'a SQLCipher 3.x build could not read 4.x databases at all',
    );
  });
}
