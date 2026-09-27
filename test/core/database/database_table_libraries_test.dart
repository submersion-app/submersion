import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Keeps code generation inside the CI runner's memory (issue #2502).
///
/// drift_dev reads every column getter through the build resolver, which
/// resolves the whole library that declares the getter, and the analyzer
/// keeps no cache of that result during a build. The cost of a cold build
/// is therefore the number of column getters multiplied by the size of the
/// library holding them. With all 108 tables inside `database.dart` that was
/// 1,516 resolutions of a 14,000 line library: 15 GB and almost 9 minutes on
/// the 16 GB CI runner. Split across the libraries under `tables/` it is
/// 3.5 GB and under 4 minutes, with byte-identical generated code.
void main() {
  final databaseDir = p.join(Directory.current.path, 'lib', 'core', 'database');
  final tableClass = RegExp(r'^class \w+ extends Table\b', multiLine: true);

  test('database.dart declares no table classes', () {
    final database = File(p.join(databaseDir, 'database.dart'));
    expect(
      database.existsSync(),
      isTrue,
      reason:
          'the check must read the real database.dart; a wrong working '
          'directory would make this test pass vacuously',
    );

    final declared = tableClass
        .allMatches(database.readAsStringSync())
        .map((match) => match.group(0))
        .toList();

    expect(
      declared,
      isEmpty,
      reason:
          'Declare tables in a library under lib/core/database/tables/ and '
          'list them in @DriftDatabase. A table declared in database.dart '
          'makes drift_dev resolve all of database.dart once per column, '
          'which is what exhausted the CI runner (issue #2502).',
    );
  });

  test('database.dart holds no migration code', () {
    final source = File(
      p.join(databaseDir, 'database.dart'),
    ).readAsStringSync();
    final migrationCode = RegExp(
      r'customStatement\(|customSelect\(|if \(from < \d+\)',
    );

    expect(
      migrationCode.allMatches(source).map((match) => match.group(0)).toSet(),
      isEmpty,
      reason:
          'Put rungs under lib/core/database/migrations/ladder/ and the '
          'helpers they call under migrations/helpers/. drift_dev resolves '
          'all of database.dart while it generates code, so migration code '
          'declared there is paid for on every build (issue #2502).',
    );
  });

  test('every table library stays small', () {
    const maxLines = 800;
    final libraries =
        Directory(p.join(databaseDir, 'tables'))
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    final tableCount = libraries
        .map((file) => tableClass.allMatches(file.readAsStringSync()).length)
        .fold<int>(0, (sum, count) => sum + count);
    expect(
      tableCount,
      greaterThan(100),
      reason:
          'the table libraries must hold the schema; finding almost no '
          'tables means this test is reading the wrong directory',
    );

    final oversized = [
      for (final file in libraries)
        if (file.readAsLinesSync().length > maxLines)
          '${p.basename(file.path)}: ${file.readAsLinesSync().length} lines',
    ];

    expect(
      oversized,
      isEmpty,
      reason:
          'Split these into smaller libraries. Each column getter costs one '
          'resolution of its whole library during code generation, so a '
          'large table library multiplies build memory (issue #2502).',
    );
  });
}
