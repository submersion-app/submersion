import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every file that builds a `FlutterMap` must also place the map style
/// switcher (`MapCornerControls`) on it, unless it is listed below with the
/// reason it skips the control.
///
/// The switcher was added to every full map at once (issue #3386). Without a
/// ratchet the next new map, or a refactor of an existing one, can ship
/// without it and the "every map" promise quietly stops being true. The check
/// is per file, not per map: a file with two maps (a mini preview and its
/// fullscreen view) passes once either carries the control, so review still
/// owns the second one.
void main() {
  /// Maps that deliberately skip the switcher, each with the reason.
  const allowed = <String, String>{
    'lib/features/dive_sites/presentation/widgets/site_list_tile.dart':
        'list row thumbnail',
    'lib/features/gps_log/presentation/widgets/gps_track_thumbnail.dart':
        'list row thumbnail',
    'lib/features/gps_log/presentation/widgets/gps_track_empty_map.dart':
        'empty-state backdrop with nothing to look at',
  };

  bool buildsMap(String code) => code.contains('FlutterMap(');

  test('every map file places the map style switcher', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (allowed.containsKey(path)) continue;
      final code = entity.readAsStringSync();
      if (buildsMap(code) && !code.contains('MapCornerControls(')) {
        offenders.add(path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Place MapCornerControls on these maps (with the map controller '
          'when the map rotates), or add them to the allowlist with the '
          'reason they skip it:\n${offenders.join('\n')}',
    );
  });

  test('the allowlist names only files that still build a map', () {
    final stale = [
      for (final path in allowed.keys)
        if (!File(path).existsSync() ||
            !buildsMap(File(path).readAsStringSync()))
          path,
    ];
    expect(
      stale,
      isEmpty,
      reason: 'Remove these allowlist entries: ${stale.join(', ')}',
    );
  });
}
