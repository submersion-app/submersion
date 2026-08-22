import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as cryptography;

/// Request-signing for the undocumented Suunto/Sports-Tracker cloud API
/// (api.sports-tracker.com).
///
/// A Dart port of the reverse-engineered scheme published in the MIT-licensed
/// https://github.com/tajchert/suuntool (key material there is credited as
/// extracted from APK com.stt.android.suunto v6.8.13), itself ported to C++
/// in https://github.com/dotanalon/suunto2subsurface. Using this against
/// your own Suunto account may violate Suunto's Terms of Service -- use only
/// with your own account and your own data.
class SuuntoCrypto {
  const SuuntoCrypto._();

  static const String _packageName = 'com.stt.android.suunto';
  static const String _totpObfuscationKey = 'Bh8nsTyCeC0Ql2drMen78awk84AE3ZxW';

  // Base64-encoded, XOR-obfuscated key material (see _deriveObfuscatedSecret
  // below). Source: github.com/tajchert/suuntool internal/auth/keys.go
  static const String _loginKeyParts =
      'FBkubDYmN28bWVQLLTsWFxcmaRB'
      'fN2AqIBc/IRAoNgshbxgnOGUVGlU3LC0xL0AuXXXXMXY'
      'RWQ4zIi0PWz4hekc1QGNTPlciNhEKV1teYSIkDGYY';
  static const String _totpKeyParts =
      'FBkubDYmN28bWVQLLTsWWhI+NAtILCNlPQc5Y'
      'BgiMRYjKA99Jj4HHFIqLmomOFttBQchNzcZU0QrODcDWz4hekc1QGNTPlciNhEKGl5GPDkzFyVX';

  static String deriveLoginSecret() =>
      _deriveObfuscatedSecret(_loginKeyParts, utf8.encode(_packageName));

  static String deriveTotpMasterSecret() =>
      _deriveObfuscatedSecret(_totpKeyParts, utf8.encode(_totpObfuscationKey));

  /// Reverses the base64 + lenient-UTF8-round-trip + XOR-cycle obfuscation
  /// applied to the embedded key material.
  ///
  /// Mirrors Go's `utf8.DecodeRune`-based replacement of invalid UTF-8
  /// sequences with U+FFFD: Dart's `utf8.decode(..., allowMalformed: true)`
  /// follows the same Unicode "maximal subpart" recommended practice, so this
  /// matches byte-for-byte.
  static String _deriveObfuscatedSecret(String base64Parts, List<int> key) {
    final raw = base64.decode(base64Parts);
    final mid = utf8.encode(utf8.decode(raw, allowMalformed: true));
    final xored = _xorCycle(mid, key);
    return utf8.decode(xored, allowMalformed: true);
  }

  static Uint8List _xorCycle(List<int> data, List<int> key) {
    final out = Uint8List(data.length);
    for (var i = 0; i < data.length; i++) {
      out[i] = data[i] ^ key[i % key.length];
    }
    return out;
  }

  /// Signs the `login2` request body.
  ///
  /// [params] must be in the same order as the form body the caller sends.
  static String signParams(String path, List<MapEntry<String, String>> params) {
    final buffer = StringBuffer('POST&$path');
    for (final param in params) {
      buffer.write('&${param.key}=${param.value}');
    }
    buffer.write('&secret=${deriveLoginSecret()}');

    final digest = sha256.convert(utf8.encode(buffer.toString()));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Generates the current TOTP code for [salt] (typically the account
  /// email).
  ///
  /// [nowMs] and [offsetMs] let tests pin the 30-second time step
  /// deterministically; [nowMs] defaults to the real current time.
  static Future<String> generateTotp(
    String salt, {
    int? nowMs,
    int offsetMs = 0,
  }) async {
    final master = deriveTotpMasterSecret();

    // Go ranges over the string as Unicode code points ("runes"), not raw
    // bytes -- iterating the UTF-16 code units of a Dart String matches that
    // here since the master secret only ever contains BMP code points.
    final pwd = Uint8List.fromList([
      for (var i = 0; i < master.length; i++) master.codeUnitAt(i) & 0xFF,
    ]);

    final pbkdf2 = cryptography.Pbkdf2(
      macAlgorithm: cryptography.Hmac.sha1(),
      iterations: 100,
      bits: 256,
    );
    final derivedKey = await pbkdf2.deriveKey(
      secretKey: cryptography.SecretKey(pwd),
      nonce: utf8.encode(salt),
    );
    final key = await derivedKey.extractBytes();

    final counter =
        ((nowMs ?? DateTime.now().millisecondsSinceEpoch) + offsetMs) ~/ 30000;
    final counterBytes = ByteData(8)..setInt64(0, counter, Endian.big);

    final mac = Hmac(sha1, key).convert(counterBytes.buffer.asUint8List());
    final digest = mac.bytes;

    final offset = digest[digest.length - 1] & 0x0f;
    final code =
        ((digest[offset] & 0x7f) << 24) |
        ((digest[offset + 1] & 0xff) << 16) |
        ((digest[offset + 2] & 0xff) << 8) |
        (digest[offset + 3] & 0xff);

    return (code % 1000000).toString().padLeft(6, '0');
  }
}
