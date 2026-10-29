import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../helpers/test_database.dart';
import '../../../tool/demo_data/src/checks/privacy_check.dart';
import '../../../tool/demo_data/src/harvest/harvester.dart';
import '../../../tool/demo_data/src/shape/dive_shape.dart';
import '../../../tool/demo_data/src/shape/reshaper.dart';
import '../../../tool/demo_data/src/shape/shape_extractor.dart';
import 'reshaper_test.dart' show source;
import 'shape_extractor_test.dart' show decoDive, pressures;

void main() {
  test('an unreshaped copy is at distance zero and rejected', () {
    final s = source();

    expect(PrivacyCheck.distance(s, s), 0);
    expect(PrivacyCheck.tooClose(s, s), isTrue);
  });

  test('a reshaped dive is far enough from its source', () {
    for (var seed = 0; seed < 50; seed++) {
      final out = Reshaper(Random(seed)).reshape(source());
      expect(
        PrivacyCheck.distance(out, source()),
        greaterThan(PrivacyCheck.similarityThreshold),
        reason: '$seed',
      );
    }
  });

  group('run', () {
    late AppDatabase db;

    setUp(() async => db = await setUpTestDatabase());
    tearDown(() async => tearDownTestDatabase());

    Future<List<PrivacyViolation>> run({
      List<DiveShape>? sources,
      Set<String> hashes = const {},
      Set<String> publicStrings = const {},
    }) => PrivacyCheck.run(
      demoDb: db,
      sources: sources ?? [source()],
      sourceStringHashes: hashes,
      salt: 'pepper',
      publicStrings: publicStrings,
    );

    test('a demo dive copied from a source is a profile violation', () async {
      await DiveRepository().createDive(decoDive());
      final copied = ShapeExtractor().fromDive(decoDive(), pressures);

      final violations = await run(sources: [copied]);

      expect(violations.map((v) => v.kind), contains('profile'));
    });

    test('a text cell equal to a source string is a text violation', () async {
      await db.customStatement(
        'INSERT INTO divers (id, name, created_at, updated_at) '
        "VALUES ('d1', 'Jane Diver', 0, 0)",
      );

      final violations = await run(
        hashes: {Harvester.hashString('pepper', 'jane diver')},
      );

      expect(violations.single.kind, 'text');
      expect(violations.single.where, contains('divers.name'));
      // The demo's own value, so the maintainer can see what to change.
      expect(violations.single.where, contains('Jane Diver'));
    });

    test(
      'a public catalogue string is allowed even when a source has it',
      () async {
        await db.customStatement(
          'INSERT INTO divers (id, name, created_at, updated_at) '
          "VALUES ('d1', 'Blue Hole', 0, 0)",
        );

        final violations = await run(
          hashes: {Harvester.hashString('pepper', 'Blue Hole')},
          publicStrings: {'Blue Hole'},
        );

        expect(violations, isEmpty);
      },
    );

    test(
      'enum-like values in non-personal columns are never compared',
      () async {
        await db.customStatement(
          'INSERT INTO divers (id, name, created_at, updated_at) '
          "VALUES ('d1', 'Alex Example', 0, 0)",
        );
        await db.customStatement(
          'INSERT INTO diver_settings (id, diver_id, depth_unit, created_at, '
          "updated_at) VALUES ('s1', 'd1', 'meters', 0, 0)",
        );

        final violations = await run(
          hashes: {Harvester.hashString('pepper', 'meters')},
        );

        expect(violations, isEmpty);
      },
    );
  });
}
