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
const guardedRoots = ['lib/shared/widgets'];

/// Guards the spacing scale and named radii (issue #4971).
///
/// Without a guard, every new widget writes its own `EdgeInsets.all(12)` and
/// `BorderRadius.circular(8)`, and the scale drifts the way it had before the
/// constants existed. A value that is deliberately off the scale is declared
/// once as a named constant with a doc comment saying why; the scanner does
/// not look inside top-level or field declarations.
void main() {
  List<File> dartFilesUnder(String root) => Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('the scanner still matches real code, so the guard cannot pass '
      'vacuously', () {
    final found = scanForSpacingLiterals(
      files: dartFilesUnder(p.join('lib', 'features')),
      relativize: p.relative,
    );
    expect(found.length, greaterThan(1000));
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
