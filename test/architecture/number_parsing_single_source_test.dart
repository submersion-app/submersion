import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Numeric text is read through `readNumber` and nowhere else.
///
/// Calling the parsers directly is how 192 call sites came to treat blank
/// and unreadable input alike, silently saving 0 or null for a mistyped
/// depth (#1900). `readNumber` returns a sealed result every caller must
/// switch on, so the blank and unreadable cases are always decided
/// explicitly.
void main() {
  /// Files permitted to call the parsers, with the reason.
  const allowed = <String, String>{
    'lib/core/utils/number_input.dart': 'defines the parsers',
    'lib/shared/widgets/forms/number_input_validation.dart':
        'the one reader, readNumber',
  };

  // Match the call, not the name: doc comments that mention a parser are
  // prose, not a second place reading numbers.
  final calls = RegExp(
    r'\b(parseUserDecimal|parseUserInt|smartParseUserDecimal|'
    r'smartParseUserInt)\s*\(',
  );

  test('only the shared layer calls the numeric parsers', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (allowed.containsKey(path)) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        if (calls.hasMatch(lines[i])) offenders.add('$path:${i + 1}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'read numeric text with readNumber (lib/shared/widgets/forms/'
          'number_input_validation.dart) and switch on its NumberRead, or '
          'use NumberField / numberValidator, so unreadable input is shown '
          'to the diver instead of silently becoming 0 or null',
    );
  });

  test('every allowlisted file exists and still calls a parser', () {
    // An allowlist entry that no longer applies is a stale exemption, and a
    // stale exemption is how a guard quietly stops guarding.
    for (final entry in allowed.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: '${entry.key} is missing');
      expect(
        calls.hasMatch(file.readAsStringSync()),
        isTrue,
        reason:
            '${entry.key} is allowlisted as "${entry.value}" but no longer '
            'calls a parser; remove it from the allowlist',
      );
    }
  });
}
