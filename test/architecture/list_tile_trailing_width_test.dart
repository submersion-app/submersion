import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'list_tile_trailing_scanner.dart';

/// Guards the rule that only fixed-width widgets belong in
/// `ListTile.trailing` (issue #2717).
///
/// A ListTile lays its trailing widget out against the full tile width first
/// and gives the title column whatever is left. A chip or a text button there
/// grows with its label and its translation, so on a phone, or in German, the
/// title collapses to one fragment per line. It was fixed screen by screen in
/// #935 and #2692 before this guard existed.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList();

  final result = scanForTextBearingTrailing(
    files: dartFiles,
    relativize: p.relative,
  );

  test('the scan found the tiles, so it cannot pass vacuously', () {
    expect(dartFiles.length, greaterThan(1000));
    expect(result.tilesWithTrailing, greaterThanOrEqualTo(300));
  });

  test('no ListTile carries a chip or a text button in trailing', () {
    expect(
      result.violations,
      isEmpty,
      reason:
          'Text-bearing widgets in ListTile.trailing. Each one below takes '
          'its natural width before the title is laid out, so a longer '
          'translation squeezes the title to one fragment per line.\n\n'
          'Fix by moving the chip or button onto its own line in the '
          'subtitle, and keep only a fixed-width widget (IconButton, '
          'PopupMenuButton, Icon, Switch, Checkbox) in trailing:\n'
          '  subtitle: Column(\n'
          '    mainAxisSize: MainAxisSize.min,\n'
          '    crossAxisAlignment: CrossAxisAlignment.start,\n'
          '    children: [Text(status), Chip(...)],\n'
          '  ),\n\n'
          'A text action goes under the subtitle as a TileSubtitleAction '
          '(lib/shared/widgets/tile_subtitle_action.dart).\n\n'
          '${result.violations.join('\n')}',
    );
  });
}
