import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Keys a diver reads on the Tracks destination or about an underwater
/// track (spec 2026-10-02, "Vocabulary (PR 2)"). The GPS and Tracks-page
/// prefixes are in scope because GPS and underwater tracks share one page,
/// map and filter, so a stray route word there breaks the same vocabulary.
/// The exact keys are the nav label and the 3D and import strings that live
/// outside those prefixes.
const _prefixes = [
  'navTrack_',
  'diveDetailSection_navTrack_',
  'gpsTrack_',
  'gpsLogger_',
  'tracks_',
];
const _exact = {
  'nav_tracks',
  'nav_tracksSubtitle',
  'universalImport_summary_importAsUnderwaterTrack',
  'dive3d_seascape_showUnderwaterTrack',
  'dive3d_spatial_recordedTrack',
  'dive3d_spatial_recordedTrackWithSource',
};

/// Each locale's words for a track other than the one its Tracks
/// destination uses: its word for "route", plus synonyms a translator might
/// reach for (Spanish "recorrido", Portuguese "trajeto"). Hebrew and Arabic
/// use one word for route and track, so they have nothing to guard.
/// Hungarian says "nyomvonal" for a track and keeps "útvonal" for a route
/// (the planner, a trip's voyage), with its case suffixes.
///
/// Bounded by "not a letter" rather than `\b`: Dart's `\b` is ASCII-only,
/// so it would find "Rota" inside Portuguese "Rotação".
RegExp _word(String pattern) => RegExp(
  '(?<!\\p{L})(?:$pattern)(?!\\p{L})',
  caseSensitive: false,
  unicode: true,
);

final _offWords = <String, RegExp>{
  'en': _word('routes?'),
  'de': _word('Routen?|Spur(?:en)?'),
  'es': _word('rutas?|recorridos?|trazas?'),
  'fr': _word('trajets?|parcours|pistes?'),
  'it': _word('percors[oi]|piste?'),
  'nl': _word('routes?|spoor|sporen'),
  'pt': _word('rotas?|trajetos?|percursos?|rastros?'),
  'hu': _word('útvonal\\p{L}*'),
  'zh': RegExp('路线|路径|航迹'),
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
  for (final entry in _offWords.entries) {
    test('${entry.key}: Tracks strings use one word for a track', () {
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

  test('plural counts render in every locale', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final n in [1, 2, 5]) {
        expect(
          l10n.navTrack_list_pendingTrackChoice(n),
          isNotEmpty,
          reason: '$locale $n',
        );
        expect(
          l10n.navTrack_section_trackCount(n),
          isNotEmpty,
          reason: '$locale $n',
        );
      }
    }
    final en = lookupAppLocalizations(const Locale('en'));
    expect(
      en.navTrack_list_pendingTrackChoice(1),
      '1 underwater track needs your choice',
    );
    expect(
      en.navTrack_list_pendingTrackChoice(2),
      '2 underwater tracks need your choice',
    );
    expect(en.navTrack_section_trackCount(2), '2 tracks');
  });

  // A plural branch a translation drops falls back to `other` without an
  // error, so each category must still produce its own wording. Counts are
  // masked first: 3 and 100 differ by digits alone even in the same branch.
  test('Arabic and Hebrew keep every plural category', () {
    final digits = RegExp(r'\p{Nd}+', unicode: true);
    List<String> shapes(String Function(int) render, List<int> counts) => [
      for (final n in counts) render(n).replaceAll(digits, '#'),
    ];
    final ar = lookupAppLocalizations(const Locale('ar'));
    final he = lookupAppLocalizations(const Locale('he'));
    // Arabic: one (1), two (2), few (3), other (100).
    for (final render in [
      ar.navTrack_list_pendingTrackChoice,
      ar.navTrack_section_trackCount,
    ]) {
      final arShapes = shapes(render, [1, 2, 3, 100]);
      expect(arShapes.toSet(), hasLength(4), reason: '$arShapes');
    }
    // Hebrew: one (1), two (2), other (5).
    for (final render in [
      he.navTrack_list_pendingTrackChoice,
      he.navTrack_section_trackCount,
    ]) {
      final heShapes = shapes(render, [1, 2, 5]);
      expect(heShapes.toSet(), hasLength(3), reason: '$heShapes');
    }
  });
}
