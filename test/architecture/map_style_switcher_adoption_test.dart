import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every `FlutterMap` that a diver can pan or zoom must carry the map style
/// switcher (`MapCornerControls`), and every map that is always locked must
/// not, unless its file is listed below with the reason it is an exception.
///
/// The switcher was added to every full map at once (issue #3386). Without a
/// ratchet the next new map, or a refactor of an existing one, can ship
/// without it and the "every map" promise quietly stops being true.
///
/// Small previews that take no gestures at all (a dashboard card, a detail
/// page strip, a story card) skip it (issue #3473): they open a fullscreen
/// map that has one, and on a strip that size the button only crowds it. A
/// map is always locked when it is built with
/// `interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)`.
/// A map that is locked only sometimes (its flags chosen by a condition)
/// still needs a control, gated on the same condition.
///
/// Each file must hold exactly as many controls as maps that are not always
/// locked, so a file with two maps (a locked preview and its fullscreen view)
/// fails when the fullscreen one loses its control or the preview gains one.
/// Comments are ignored, so naming a widget in prose counts for nothing.
void main() {
  /// Maps that deliberately skip the switcher, each with the reason.
  const allowed = <String, String>{
    'lib/features/gps_log/presentation/widgets/gps_track_empty_map.dart':
        'empty-state backdrop with nothing to look at',
  };

  /// The file's code with `//` comments removed.
  String codeOf(String source) =>
      source.split('\n').map((line) => line.split('//').first).join('\n');

  int count(String code, String call) => call.allMatches(code).length;

  /// A map whose interaction options turn every gesture off unconditionally:
  /// `InteractionOptions(...)` (const or not, other arguments allowed) with
  /// `flags: InteractiveFlag.none`. A condition before `InteractionOptions`
  /// or inside `flags:` does not match, so a sometimes-locked map still
  /// counts as interactive. `[^()]` keeps the match inside one argument list.
  final alwaysLocked = RegExp(
    r'interactionOptions:\s*(?:const\s+)?InteractionOptions\([^()]*?'
    r'\bflags:\s*InteractiveFlag\.none\s*[,)]',
  );

  bool buildsMap(String source) => count(codeOf(source), 'FlutterMap(') > 0;

  test('every map file places the map style switcher', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (allowed.containsKey(path)) continue;
      final code = codeOf(entity.readAsStringSync());
      final maps = count(code, 'FlutterMap(');
      // A file without a map (the control's own definition among them) has
      // nothing to check.
      if (maps == 0) continue;
      final locked = alwaysLocked.allMatches(code).length;
      final controls = count(code, 'MapCornerControls(');
      if (controls != maps - locked) {
        offenders.add(
          '$path: $maps map(s), $locked always locked, '
          '$controls MapCornerControls',
        );
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Place MapCornerControls on each map a diver can pan or zoom (with '
          'the map controller when the map rotates) and on no map that is '
          'always locked, or add the file to the allowlist with the reason it '
          'is an exception:\n${offenders.join('\n')}',
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
