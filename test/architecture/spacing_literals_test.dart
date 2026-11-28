import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'spacing_literal_scanner.dart';

/// Folders whose spacing and radii come from `Spacing` / `Radii` in
/// `lib/core/theme/spacing.dart` or from named constants (issue #4971).
///
/// Features migrate one folder at a time, each in its own small PR, so the
/// work does not collide with open feature branches. A migration PR adds its
/// folder here.
final guardedRoots = [p.join('lib', 'shared', 'widgets')];

/// Guards the spacing scale and named radii (issue #4971).
///
/// Without a guard, every new widget writes its own `EdgeInsets.all(12)` and
/// `BorderRadius.circular(8)`, and the scale drifts the way it had before the
/// constants existed. A value that is deliberately off the scale is declared
/// once as a named constant with a doc comment saying why; the scanner does
/// not look inside top-level, `static` or enum constant declarations.
void main() {
  List<File> dartFilesUnder(String root) => Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  // A fixture rather than a count over lib/features: that count falls with
  // every feature migration, so a threshold on it would fail once the work
  // it guards is done.
  test('the scanner still matches a real widget file, so the guard cannot '
      'pass vacuously', () {
    final found = scanForSpacingLiterals(
      files: [
        File(p.join('test', 'architecture', 'spacing_literal_fixture.dart')),
      ],
      relativize: p.relative,
    );
    expect(
      [for (final literal in found) '${literal.call} ${literal.value}'],
      [
        'EdgeInsets.all 16',
        'BorderRadius.circular 12',
        'Column.spacing 4',
        'SizedBox.height 8',
        'EdgeInsetsDirectional.only 6',
        'Radius.circular 2',
      ],
    );
  });

  test('every guarded folder holds Dart files, so it is really scanned', () {
    for (final root in guardedRoots) {
      expect(dartFilesUnder(root), isNotEmpty, reason: root);
    }
  });

  test('guarded folders hold no spacing or radius literals', () {
    final found = scanForSpacingLiterals(
      files: [for (final root in guardedRoots) ...dartFilesUnder(root)],
      relativize: p.relative,
    );
    expect(
      found,
      isEmpty,
      reason:
          'Spacing and radius values written as bare numbers. Use Spacing '
          'or Radii from lib/core/theme/spacing.dart, or for a value that is '
          'deliberately off the scale, a named constant with a doc comment '
          'saying why (docs/developer/ui-conventions.md):\n\n'
          '${found.join('\n')}',
    );
  });
}
