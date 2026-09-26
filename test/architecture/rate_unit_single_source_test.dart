import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Presentation code must take every per-minute rate unit from `UnitFormatter`
/// (`depthRateSymbol`, `sacSymbol`, `rmvSymbol`, `formatDepthRate`, or
/// `UnitFormatter.perMinute` for any other base unit), never by writing
/// "/min" into a string itself.
///
/// Rate units used to be hand-built as `'${units.depthSymbol}/min'` in about
/// thirty places (issue #1932), so there was no single place that decided how
/// a rate unit reads. Every offender was converted; this scan is the ratchet.
void main() {
  /// Directories whose whole job is drawing the UI.
  const scannedRoots = ['lib/core/presentation', 'lib/shared', 'lib/features'];

  /// Only presentation code is scanned inside `lib/features`; parsers and
  /// codecs legitimately match a literal "m/min" in someone else's file.
  bool isScanned(String path) {
    if (!path.startsWith('lib/features/')) return true;
    return path.contains('/presentation/');
  }

  /// Files that still build a rate unit by hand, each with the reason.
  const allowed = <String, String>{
    // The SCR injection rate and VO2 fields hard-code litres whatever the
    // diver's volume unit; issue #1935 moves them onto `rmvSymbol`. Remove
    // this entry when that lands.
    'lib/features/dive_log/presentation/widgets/scr_settings_panel.dart':
        'volume unit tracked in #1935',
  };

  final perMinute = RegExp(r'/min\b');

  test('no presentation file builds a per-minute unit by hand', () {
    final offenders = <String>[];
    for (final root in scannedRoots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (!isScanned(path) || allowed.containsKey(path)) continue;
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
