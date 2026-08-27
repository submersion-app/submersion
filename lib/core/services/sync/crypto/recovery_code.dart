import 'dart:math';

import 'package:submersion/core/services/sync/crypto/eff_short_wordlist.dart';

/// 8 words from the EFF short wordlist: ~10.34 bits/word, ~82.7 bits total.
abstract final class RecoveryCode {
  static const int wordCount = 8;

  static String generate() {
    final random = Random.secure();
    return List.generate(
      wordCount,
      (_) => effShortWordlist[random.nextInt(effShortWordlist.length)],
    ).join('-');
  }

  /// Lowercase; any run of whitespace/hyphens becomes a single hyphen.
  static String normalize(String input) =>
      input.trim().toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '-');
}
