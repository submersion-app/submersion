import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every `FlutterMap` must carry the map style switcher (`MapCornerControls`),
/// unless its file is listed below with the reason it skips the control.
///
/// The switcher was added to every full map at once (issue #3386). Without a
/// ratchet the next new map, or a refactor of an existing one, can ship
/// without it and the "every map" promise quietly stops being true. Each file
/// must hold at least as many controls as maps, so a file with two maps (a
/// mini preview and its fullscreen view) fails when either one loses its
/// control. Comments are ignored, so naming a widget in prose counts for
/// nothing.
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

  /// The file's code with `//` comments removed.
  String codeOf(String source) =>
      source.split('\n').map((line) => line.split('//').first).join('\n');

  int count(String code, String call) => call.allMatches(code).length;

  bool buildsMap(String source) => count(codeOf(source), 'FlutterMap(') > 0;

  test('every map file places the map style switcher', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (allowed.containsKey(path)) continue;
      final code = codeOf(entity.readAsStringSync());
      final maps = count(code, 'FlutterMap(');
      final controls = count(code, 'MapCornerControls(');
      if (controls < maps) {
        offenders.add('$path: $maps map(s), $controls MapCornerControls');
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
