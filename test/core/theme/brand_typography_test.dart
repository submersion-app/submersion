import 'dart:convert';

import 'package:flutter/foundation.dart' show LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/theme/brand_typography.dart';

/// Issue #5014: the app name beside the icon is set in the logo's font,
/// Inter Display ExtraBold, the face the brand wordmark is drawn in
/// (scripts/brand/README.md), rather than whatever the theme's headline uses.
void main() {
  group('BrandTypography.wordmark', () {
    test('sets the logo family and weight over the theme font', () {
      const base = TextStyle(
        fontFamily: 'Nunito',
        fontWeight: FontWeight.w400,
        fontSize: 24,
        color: Color(0xFF123456),
      );

      final style = BrandTypography.wordmark(base);

      expect(style.fontFamily, BrandTypography.wordmarkFamily);
      expect(style.fontWeight, FontWeight.w800);
      // Size and colour stay the caller's: only the face changes.
      expect(style.fontSize, 24);
      expect(style.color, const Color(0xFF123456));
    });

    test('drops a theme fallback list, so a missing glyph falls back to '
        'the platform font rather than a theme face', () {
      const base = TextStyle(
        fontFamily: 'JetBrains Mono',
        fontFamilyFallback: ['JetBrains Mono'],
      );

      final style = BrandTypography.wordmark(base);

      expect(style.fontFamilyFallback, isEmpty);
    });

    test('builds a style from nothing when the theme has no slot', () {
      final style = BrandTypography.wordmark(null);

      expect(style.fontFamily, BrandTypography.wordmarkFamily);
      expect(style.fontWeight, FontWeight.w800);
    });
  });

  test('the logo family is bundled with the app', () async {
    // A family name the font manifest does not declare renders in the
    // platform font without any error, so the name is checked against the
    // manifest pubspec.yaml produces.
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    final families = manifest
        .map((e) => (e as Map<String, dynamic>)['family'] as String)
        .toList();

    expect(families, contains(BrandTypography.wordmarkFamily));
  });

  test('registers the SIL Open Font License the bundled font ships '
      'under', () async {
    LicenseRegistry.reset();
    addTearDown(LicenseRegistry.reset);

    BrandTypography.registerLicense();
    final entries = await LicenseRegistry.licenses.toList();
    final entry = entries.singleWhere(
      (e) => e.packages.contains(BrandTypography.wordmarkFamily),
    );
    final text = entry.paragraphs.map((p) => p.text).join(' ');

    expect(text, contains('The Inter Project Authors'));
    expect(text, contains('SIL OPEN FONT LICENSE Version 1.1'));
  });
}
