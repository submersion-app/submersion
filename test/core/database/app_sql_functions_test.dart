import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/database_connection_setup.dart';
import 'package:submersion/core/text/fuzzy_match.dart' show foldForSearch;
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_name_key.dart';

void main() {
  group('catalogue_name_key', () {
    late sqlite3.Database db;

    setUp(() {
      db = sqlite3.sqlite3.openInMemory();
      registerAppSqlFunctions(db);
    });

    tearDown(() => db.close());

    Object? key(Object? value) => db.select(
      'SELECT $kCatalogueNameKeyFunction(?) AS v',
      [value],
    ).first['v'];

    test('is the name key the Dart side compares with', () {
      for (final name in ['Salt-Pier (South)', 'Cancún', '  Blue  Hole ']) {
        expect(key(name), catalogueNameKey(name), reason: name);
      }
      expect(key('Salt-Pier (South)'), 'salt pier south');
    });

    test('NULL stays NULL and a name of punctuation is empty', () {
      expect(key(null), isNull);
      expect(key('?!'), '');
    });
  });

  group('unicode_lower', () {
    late sqlite3.Database db;

    setUp(() {
      db = sqlite3.sqlite3.openInMemory();
      registerAppSqlFunctions(db);
    });

    tearDown(() => db.close());

    Object? lower(Object? value) =>
        db.select('SELECT $kUnicodeLowerFunction(?) AS v', [value]).first['v'];

    test('folds a non-ASCII capital, which LOWER() leaves alone (#3032)', () {
      expect(
        db.select("SELECT LOWER('Éponge') AS v").first['v'],
        'Éponge',
        reason: 'the built-in is the reason this function exists',
      );
      expect(lower('Éponge Pinceau'), 'éponge pinceau');
      expect(lower('ÖRNFISK ÀÉÎÕÜ'), 'örnfisk àéîõü');
    });

    test('agrees with Dart toLowerCase across scripts', () {
      for (final s in ['Ελλάδα', 'МОРЕ', 'Fesse d\'Éléphant', 'İzmir']) {
        expect(lower(s), s.toLowerCase(), reason: s);
      }
    });

    test('passes NULL through as NULL', () {
      expect(lower(null), isNull);
    });

    test('returns a blob unchanged', () {
      expect(lower(Uint8List.fromList([0x41, 0xC9])), [0x41, 0xC9]);
    });

    test('renders a number as text, as LOWER() does', () {
      expect(lower(42), '42');
      expect(lower(1.5), '1.5');
    });
  });

  group('search_fold', () {
    late sqlite3.Database db;

    setUp(() {
      db = sqlite3.sqlite3.openInMemory();
      registerAppSqlFunctions(db);
    });

    tearDown(() => db.close());

    Object? fold(Object? value) =>
        db.select('SELECT $kSearchFoldFunction(?) AS v', [value]).first['v'];

    test('folds case and accents, so "jeremie" finds "Jérémie" (#4498)', () {
      expect(fold('Jérémie'), 'jeremie');
      expect(
        db.select('SELECT $kSearchFoldFunction(?) LIKE ? AS v', [
          'Jérémie Dupont',
          '%${foldForSearch('jeremie')}%',
        ]).first['v'],
        1,
      );
    });

    test('is the fold the Dart side applies to the needle', () {
      for (final s in ['Łukasz', 'Straße', 'Cancún', 'Ελλάδα']) {
        expect(fold(s), foldForSearch(s), reason: s);
      }
    });

    test('passes NULL through, a number as text, a blob unchanged', () {
      expect(fold(null), isNull);
      expect(fold(42), '42');
      expect(fold(Uint8List.fromList([0x41, 0xC9])), [0x41, 0xC9]);
    });
  });

  group('row_digest', () {
    late sqlite3.Database db;

    setUp(() {
      db = sqlite3.sqlite3.openInMemory();
      registerAppSqlFunctions(db);
    });

    tearDown(() => db.close());

    Object? digest(List<Object?> values) => db
        .select(
          'SELECT $kRowDigestFunction(${values.map((_) => '?').join(', ')}) AS v',
          values,
        )
        .first['v'];

    test('gives equal values equal digests', () {
      expect(digest(['a', 1, 1.5, null]), digest(['a', 1, 1.5, null]));
    });

    test('tells apart a change in any position', () {
      final base = digest(['a', 1, 1.5, null]);
      expect(digest(['b', 1, 1.5, null]), isNot(base));
      expect(digest(['a', 2, 1.5, null]), isNot(base));
      expect(digest(['a', 1, 2.5, null]), isNot(base));
      expect(digest(['a', 1, 1.5, 0]), isNot(base));
    });

    test('depends on the order of its values', () {
      expect(digest(['a', 'b']), isNot(digest(['b', 'a'])));
    });
  });

  test('applyConnectionBasics registers the functions', () {
    final db = sqlite3.sqlite3.openInMemory();
    try {
      applyConnectionBasics(db);
      expect(
        db.select("SELECT $kUnicodeLowerFunction('À') AS v").first['v'],
        'à',
      );
    } finally {
      db.close();
    }
  });

  test(
    'the drift expression filters through the registered function',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(setup: registerAppSqlFunctions),
      );
      try {
        await db
            .into(db.species)
            .insert(
              SpeciesCompanion.insert(
                id: 'sp-1',
                commonName: 'Écueil rouge',
                category: 'other',
              ),
            );
        final rows =
            await (db.select(db.species)..where(
                  (t) => t.commonName.unicodeLower().equals('écueil rouge'),
                ))
                .get();
        expect(rows.map((r) => r.id), ['sp-1']);
      } finally {
        await db.close();
      }
    },
  );
}
