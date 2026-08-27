// Standalone vector generator for the database-key HKDF derivation.
//
// Computes HKDF-SHA256(mlk, salt: empty, info: 'sdb:v1:dbkey', length: 32)
// with the cryptography package directly — deliberately NOT through
// Keyslots.deriveSubKey — so the test vector in
// test/core/services/security/database_security_service_test.dart is an
// independent check of the production derivation.
//
// Run: dart run tool/compute_db_key_vector.dart
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

Future<void> main() async {
  final mlk = SecretKey(List<int>.generate(32, (i) => i + 1));
  const hkdf = DartHkdf(hmac: DartHmac(DartSha256()), outputLength: 32);
  final key = await hkdf.deriveKey(
    secretKey: mlk,
    nonce: const <int>[],
    info: utf8.encode('sdb:v1:dbkey'),
  );
  final bytes = await key.extractBytes();
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  // ignore: avoid_print
  print(hex);
}
