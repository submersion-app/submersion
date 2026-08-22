import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_crypto.dart';

/// Expected values were independently computed from a Python port of the
/// same algorithm (base64 decode -> lenient-UTF8 round trip -> XOR cycle ->
/// lenient UTF8 decode) and cross-checked byte-for-byte against this Dart
/// implementation's output before being hardcoded here, so these are a
/// regression guard against the obfuscation/signing/TOTP math silently
/// drifting, not just a "produces something" smoke test.
void main() {
  group('deriveLoginSecret', () {
    test('is deterministic and matches the reference derivation', () {
      final secret = SuuntoCrypto.deriveLoginSecret();
      expect(secret, SuuntoCrypto.deriveLoginSecret());
      expect(secret.length, 86);
      // Index 50-52 are the U+FFFD replacement runs produced by the lenient
      // UTF-8 round trip over the obfuscated key material.
      expect(secret.codeUnits.sublist(50, 53), [0xfffd, 0xfffd, 0xfffd]);
    });
  });

  group('deriveTotpMasterSecret', () {
    test('is deterministic and has no replacement characters', () {
      final secret = SuuntoCrypto.deriveTotpMasterSecret();
      expect(secret, SuuntoCrypto.deriveTotpMasterSecret());
      expect(secret.length, 84);
      expect(secret.codeUnits, isNot(contains(0xfffd)));
    });
  });

  group('signParams', () {
    test('produces the expected base64url signature for a known request', () {
      final signature = SuuntoCrypto.signParams('login2', [
        const MapEntry('l', 'diver@example.com'),
        const MapEntry('p', 'hunter2'),
        const MapEntry('totp', '123456'),
      ]);

      expect(signature, 'cJdill7KhsjwYmuWMKwtpTsa5uFMexd6LicaJKHhaRo');
      // A 256-bit SHA-256 digest, base64url-encoded with padding stripped.
      expect(signature.length, 43);
      expect(signature, isNot(contains('=')));
      expect(signature, isNot(contains('+')));
      expect(signature, isNot(contains('/')));
    });

    test('changes when any parameter changes', () {
      final base = SuuntoCrypto.signParams('login2', [
        const MapEntry('l', 'diver@example.com'),
        const MapEntry('p', 'hunter2'),
      ]);
      final differentPassword = SuuntoCrypto.signParams('login2', [
        const MapEntry('l', 'diver@example.com'),
        const MapEntry('p', 'hunter3'),
      ]);
      expect(base, isNot(differentPassword));
    });
  });

  group('generateTotp', () {
    test('produces the expected 6-digit code for a fixed instant', () async {
      final code = await SuuntoCrypto.generateTotp(
        'diver@example.com',
        nowMs: 1700000000000,
      );
      expect(code, '953479');
      expect(code.length, 6);
    });

    test('is stable within the same 30-second window', () async {
      // 1699999980000 is exactly divisible by 30000, so +15000 lands in the
      // same window as the base instant used by the other tests above
      // (1700000000000, which is 20s into that same window).
      const windowStart = 1699999980000;
      final start = await SuuntoCrypto.generateTotp(
        'diver@example.com',
        nowMs: windowStart,
      );
      final midWindow = await SuuntoCrypto.generateTotp(
        'diver@example.com',
        nowMs: windowStart + 15000,
      );
      expect(start, '953479');
      expect(midWindow, start);
    });

    test('changes in the next 30-second window', () async {
      const windowStart = 1699999980000;
      final thisWindow = await SuuntoCrypto.generateTotp(
        'diver@example.com',
        nowMs: windowStart,
      );
      final nextWindow = await SuuntoCrypto.generateTotp(
        'diver@example.com',
        nowMs: windowStart + 30000,
      );
      expect(nextWindow, isNot(thisWindow));
      expect(nextWindow, '756695');
    });

    test('depends on the salt (account email)', () async {
      final a = await SuuntoCrypto.generateTotp(
        'diver-a@example.com',
        nowMs: 1700000000000,
      );
      final b = await SuuntoCrypto.generateTotp(
        'diver-b@example.com',
        nowMs: 1700000000000,
      );
      expect(a, isNot(b));
    });

    test('always pads to 6 digits', () async {
      // Sweep a range of instants and confirm the code is always exactly
      // 6 numeric characters -- the modulo-1e6 result can be small enough
      // to need leading-zero padding.
      for (var i = 0; i < 50; i++) {
        final code = await SuuntoCrypto.generateTotp(
          'diver@example.com',
          nowMs: 1700000000000 + i * 30000,
        );
        expect(code.length, 6);
        expect(int.tryParse(code), isNotNull);
      }
    });
  });
}
