import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/database_connection_setup.dart';

void main() {
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
