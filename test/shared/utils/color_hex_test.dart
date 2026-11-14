import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/utils/color_hex.dart';

/// The colour code helpers the custom colour dialog reads and writes
/// (issues #4384 and #4537).
void main() {
  group('parseColorHexInput', () {
    test('accepts six hex digits with or without a hash, in capitals', () {
      expect(parseColorHexInput(' #2e8b57 '), '#2E8B57');
      expect(parseColorHexInput('2E8B57'), '#2E8B57');
    });

    test('rejects anything else', () {
      for (final bad in [
        '#FFF',
        '#GGGGGG',
        '#2E8B571',
        '',
        '#-00001',
        '##2E8B57',
      ]) {
        expect(parseColorHexInput(bad), isNull, reason: bad);
      }
    });
  });

  test('colorHexOf writes capitals and drops alpha', () {
    expect(colorHexOf(const Color(0x80FF0000)), '#FF0000');
    expect(colorHexOf(const Color(0xFF2e8b57)), '#2E8B57');
  });
}
