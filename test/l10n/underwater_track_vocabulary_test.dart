import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Keys that name an underwater track (spec 2026-10-02, "Vocabulary
/// (PR 2)"). A key is in scope by prefix; the four listed exact keys are the
/// 3D and import strings that live outside the nav-track prefixes.
const _prefixes = ['navTrack_', 'diveDetailSection_navTrack_'];
const _exact = {
  'universalImport_summary_importAsUnderwaterTrack',
  'dive3d_seascape_showUnderwaterTrack',
  'dive3d_spatial_recordedTrack',
  'dive3d_spatial_recordedTrackWithSource',
};

/// Each locale's word for "route", where it differs from its word for
/// "track". Hungarian, Hebrew and Arabic use one word for both, so they
/// have nothing to guard.
///
/// Bounded by "not a letter" rather than `\b`: Dart's `\b` is ASCII-only,
/// so it would find "Rota" inside Portuguese "Rotação".
RegExp _word(String pattern) => RegExp(
  '(?<!\\p{L})(?:$pattern)(?!\\p{L})',
  caseSensitive: false,
  unicode: true,
);

final _routeWords = <String, RegExp>{
  'en': _word('routes?'),
  'de': _word('Routen?'),
  'es': _word('rutas?'),
  'fr': _word('trajets?'),
  'it': _word('percors[oi]'),
  'nl': _word('routes?'),
  'pt': _word('rotas?'),
  'zh': RegExp('路线'),
};

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(
          File(
            p.join('lib', 'l10n', 'arb', 'app_$locale.arb'),
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

bool _inScope(String key) =>
    !key.startsWith('@') &&
    (_exact.contains(key) || _prefixes.any(key.startsWith));

void main() {
  for (final entry in _routeWords.entries) {
    test('${entry.key}: no underwater track string says route', () {
      final offenders = [
        for (final MapEntry(:key, :value) in _arb(entry.key).entries)
          if (_inScope(key) && entry.value.hasMatch('$value')) '$key: $value',
      ];
      expect(offenders, isEmpty);
    });
  }

  test('the renamed keys exist in every locale and the old ones are gone', () {
    const renamed = {
      'navTrack_section_title': 'navTrack_section_trackTitle',
      'navTrack_list_pendingChoice': 'navTrack_list_pendingTrackChoice',
      'dive3d_spatial_recordedPath': 'dive3d_spatial_recordedTrack',
      'universalImport_summary_importAsRoute':
          'universalImport_summary_importAsUnderwaterTrack',
    };
    for (final locale in [
      'ar',
      'de',
      'en',
      'es',
      'fr',
      'he',
      'hu',
      'it',
      'nl',
      'pt',
      'zh',
    ]) {
      final arb = _arb(locale);
      for (final MapEntry(key: old, value: renamedTo) in renamed.entries) {
        expect(arb.containsKey(old), isFalse, reason: '$locale still has $old');
        expect(
          arb.containsKey(renamedTo),
          isTrue,
          reason: '$locale lacks $renamedTo',
        );
      }
    }
  });
}
