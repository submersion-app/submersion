import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
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
  final databaseFile = File(p.join(databaseDir, 'database.dart'));

  CompilationUnit parseDatabase() {
    expect(
      databaseFile.existsSync(),
      isTrue,
      reason:
          'the check must read the real database.dart; a wrong working '
          'directory would make this test pass vacuously',
    );
    return parseString(
      content: databaseFile.readAsStringSync(),
      path: databaseFile.path,
    ).unit;
  }

  test('database.dart declares nothing at top level but AppDatabase', () {
    const allowed = {
      'AppDatabase',
      'kLegacyDataSourceIdPrefix',
      'legacyDataSourceId',
    };
    final unit = parseDatabase();

    final names = [
      for (final declaration in unit.declarations)
        switch (declaration) {
          ClassDeclaration(:final namePart) => namePart.typeName.lexeme,
          FunctionDeclaration(:final name) => name.lexeme,
          TopLevelVariableDeclaration(:final variables) =>
            variables.variables.map((v) => v.name.lexeme).join(', '),
          _ => declaration.toSource().split('\n').first,
        },
    ];

    expect(names, contains('AppDatabase'));
    expect(
      names.where((name) => !allowed.contains(name)).toList(),
      isEmpty,
      reason:
          'Declare tables and their seed SQL in a library under '
          'lib/core/database/tables/ and list the tables in @DriftDatabase. '
          'drift_dev resolves all of database.dart once per column declared '
          'there, which is what exhausted the CI runner (issue #2502).',
    );
  });

  test('AppDatabase holds no migration code', () {
    const allowed = {
      '<constructor>',
      'onMigrationProgress',
      'currentSchemaVersion',
      'minimumCompatibleSchemaVersion',
      'migrationVersions',
      'migrationStepCount',
      'schemaVersion',
      'migration',
    };
    final unit = parseDatabase();
    final appDatabase = unit.declarations
        .whereType<ClassDeclaration>()
        .singleWhere((c) => c.namePart.typeName.lexeme == 'AppDatabase');

    final members = [
      for (final member in (appDatabase.body as BlockClassBody).members)
        switch (member) {
          ConstructorDeclaration() => '<constructor>',
          MethodDeclaration(:final name) => name.lexeme,
          FieldDeclaration(:final fields) =>
            fields.variables.map((v) => v.name.lexeme).join(', '),
          _ => member.toSource().split('\n').first,
        },
    ];

    expect(members, contains('migration'));
    expect(
      members.where((name) => !allowed.contains(name)).toList(),
      isEmpty,
      reason:
          'Put rungs under lib/core/database/migrations/ladder/ and the '
          'helpers they call, test hooks included, under migrations/helpers/ '
          'as public extension members; database.dart exports them. drift_dev '
          'resolves all of database.dart while it generates code, so code '
          'declared there is paid for on every build (issue #2502).',
    );
  });

  test('every table and migration file stays under 800 lines', () {
    const maxLines = 800;
    final files =
        [
              ...Directory(p.join(databaseDir, 'tables')).listSync(),
              ...Directory(
                p.join(databaseDir, 'migrations'),
              ).listSync(recursive: true),
            ]
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final lines = {for (final file in files) file: file.readAsLinesSync()};

    final tableClass = RegExp(r'^class \w+ extends Table\b');
    final tableCount = lines.values
        .expand((fileLines) => fileLines)
        .where(tableClass.hasMatch)
        .length;
    expect(
      tableCount,
      greaterThan(100),
      reason:
          'the table libraries must hold the schema; finding almost no '
          'tables means this test is reading the wrong directory',
    );

    final oversized = [
      for (final MapEntry(key: file, value: fileLines) in lines.entries)
        if (fileLines.length > maxLines)
          '${p.relative(file.path, from: databaseDir)}: '
              '${fileLines.length} lines',
    ];

    expect(
      oversized,
      isEmpty,
      reason:
          'Split these files. A table library costs one resolution of the '
          'whole library per column during code generation, so a large one '
          'multiplies build memory (issue #2502). A ladder file that is full '
          'is closed and a new onward file started, as '
          'docs/developer/database.md describes.',
    );
  });
}
