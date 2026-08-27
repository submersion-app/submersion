/// SQLCipher helpers.
///
/// There is no loader setup to do any more. sqlite3 3.x selects the native
/// library through its build hook (`hooks: user_defines: sqlite3: source:
/// sqlcipher` in pubspec.yaml), so SQLCipher is linked at build time for every
/// isolate. The old `setupSqlcipher()` override existed only because sqlite3
/// 2.x resolved the library at runtime, per isolate, via
/// `package:sqlite3/open.dart` -- an API 3.x removed.
library;

/// The PRAGMA that keys a SQLCipher connection with a raw (already
/// KDF-stretched) 32-byte key, given as 64 hex chars. Must be the first
/// statement executed on the connection.
///
/// Top-level here (not on DatabaseService) so the drift worker isolate and
/// the encryption migrator can build it without importing
/// database_service.dart -- that file imports both of them.
String cipherKeyPragma(String keyHex) => 'PRAGMA key = "x\'$keyHex\'"';
