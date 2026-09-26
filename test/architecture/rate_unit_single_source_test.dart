import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every per-minute rate unit the app shows must come from `UnitFormatter`
/// (`depthRateSymbol`, `sacSymbol`, `rmvSymbol`, `formatDepthRate`, or
/// `UnitFormatter.perMinute` for any other base unit), never from code that
/// writes "/min" into a string itself.
///
/// Rate units used to be hand-built as `'${units.depthSymbol}/min'` in about
/// thirty places (issue #1932), so there was no single place that decided how
/// a rate unit reads. Those sites were not all presentation code (the chart
/// axes in `lib/core/utils` and the 3D view's `application` layer built them
/// too), so the whole of `lib/` is scanned. Every offender was converted;
/// this scan is the ratchet.
void main() {
  /// Generated code, which no one edits by hand. The l10n classes mirror the
  /// ARB files, which carry their own review.
  bool isGenerated(String path) =>
      path.startsWith('lib/l10n/') || path.endsWith('.g.dart');

  /// Files that write "/min" on purpose, each with the reason.
  const allowed = <String, String>{
    // The one place a rate unit is built.
    'lib/core/utils/unit_formatter.dart': 'defines UnitFormatter.perMinute',
    // Column headers in other apps' CSV files, matched as they are written.
    'lib/core/services/export/csv/codec/csv_attribute_codec.dart':
        'parses m/min and ft/min CSV headers',
    'lib/features/universal_import/data/csv/presets/built_in_presets.dart':
        'matches a "sac [l/min]" CSV header',
    'lib/features/universal_import/data/services/format_detector.dart':
        'matches a "sac [l/min]" CSV header',
    // An ArgumentError message for developers, never shown to a diver.
    'lib/features/planner/domain/services/recreational_ndl_solver.dart':
        'developer error message',
    // The SCR injection rate and VO2 fields hard-code litres whatever the
    // diver's volume unit; issue #1935 moves them onto `rmvSymbol`. Remove
    // this entry when that lands.
    'lib/features/dive_log/presentation/widgets/scr_settings_panel.dart':
        'volume unit tracked in #1935',
  };

  final perMinute = RegExp(r'/min\b');

  test('no file outside UnitFormatter builds a per-minute unit by hand', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (isGenerated(path) || allowed.containsKey(path)) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Comments may name units ("stored in m/min") freely.
        final code = line.split('//').first;
        if (perMinute.hasMatch(code)) {
          offenders.add('$path:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Use UnitFormatter.depthRateSymbol / sacSymbol / rmvSymbol / '
          'formatDepthRate (or UnitFormatter.perMinute) instead:\n'
          '${offenders.join('\n')}',
    );
  });

  test('every allowlisted file still exists', () {
    for (final path in allowed.keys) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });
}
