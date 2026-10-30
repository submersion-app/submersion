import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('DiveSite entry/exit methods', () {
    test('default to empty', () {
      const site = DiveSite(id: 's', name: 'S');
      expect(site.entryMethods, isEmpty);
      expect(site.exitMethods, isEmpty);
    });

    test('round-trip through the constructor', () {
      const site = DiveSite(
        id: 's',
        name: 'S',
        entryMethods: [EntryMethod.giantStride, EntryMethod.backRoll],
        exitMethods: [EntryMethod.ladder],
      );
      expect(site.entryMethods, [
        EntryMethod.giantStride,
        EntryMethod.backRoll,
      ]);
      expect(site.exitMethods, [EntryMethod.ladder]);
    });

    test('copyWith sets both fields', () {
      const site = DiveSite(id: 's', name: 'S');
      final updated = site.copyWith(
        entryMethods: const [EntryMethod.boat],
        exitMethods: const [EntryMethod.ladder],
      );
      expect(updated.entryMethods, [EntryMethod.boat]);
      expect(updated.exitMethods, [EntryMethod.ladder]);
    });

    test('copyWith preserves both fields when they are not passed', () {
      const site = DiveSite(
        id: 's',
        name: 'S',
        entryMethods: [EntryMethod.shore],
        exitMethods: [EntryMethod.shore],
      );
      final updated = site.copyWith(name: 'Renamed');
      expect(updated.entryMethods, [EntryMethod.shore]);
      expect(updated.exitMethods, [EntryMethod.shore]);
    });

    test('copyWith with an empty list clears the methods', () {
      const site = DiveSite(
        id: 's',
        name: 'S',
        entryMethods: [EntryMethod.shore],
      );
      expect(site.copyWith(entryMethods: const []).entryMethods, isEmpty);
    });

    test('soleEntryMethod is the method only when there is exactly one', () {
      expect(const DiveSite(id: 's', name: 'S').soleEntryMethod, isNull);
      expect(
        const DiveSite(
          id: 's',
          name: 'S',
          entryMethods: [EntryMethod.shore],
        ).soleEntryMethod,
        EntryMethod.shore,
      );
      expect(
        const DiveSite(
          id: 's',
          name: 'S',
          entryMethods: [EntryMethod.shore, EntryMethod.boat],
        ).soleEntryMethod,
        isNull,
      );
    });

    test('soleExitMethod is the method only when there is exactly one', () {
      expect(
        const DiveSite(
          id: 's',
          name: 'S',
          exitMethods: [EntryMethod.ladder],
        ).soleExitMethod,
        EntryMethod.ladder,
      );
      expect(
        const DiveSite(
          id: 's',
          name: 'S',
          exitMethods: [EntryMethod.ladder, EntryMethod.shore],
        ).soleExitMethod,
        isNull,
      );
    });

    test('sites with equal lists are equal', () {
      // Two distinct list instances, so equality must compare content.
      final a = DiveSite(
        id: 's',
        name: 'S',
        entryMethods: List.of(const [EntryMethod.shore, EntryMethod.boat]),
      );
      final b = DiveSite(
        id: 's',
        name: 'S',
        entryMethods: List.of(const [EntryMethod.shore, EntryMethod.boat]),
      );
      expect(a, equals(b));
    });

    test('equality distinguishes sites by entry methods', () {
      const a = DiveSite(id: 's', name: 'S', entryMethods: [EntryMethod.boat]);
      const b = DiveSite(
        id: 's',
        name: 'S',
        entryMethods: [EntryMethod.boat, EntryMethod.shore],
      );
      expect(a, isNot(equals(b)));
    });

    test('equality distinguishes sites by exit methods', () {
      const a = DiveSite(id: 's', name: 'S', exitMethods: [EntryMethod.ladder]);
      const b = DiveSite(
        id: 's',
        name: 'S',
        exitMethods: [EntryMethod.platform],
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('DiveSite persistence round-trip', () {
    late SiteRepository repository;
    late AppDatabase db;

    setUp(() async {
      db = await setUpTestDatabase();
      repository = SiteRepository();
    });

    tearDown(tearDownTestDatabase);

    Future<String?> storedEntry(String id) async {
      final row = await (db.select(
        db.diveSites,
      )..where((t) => t.id.equals(id))).getSingle();
      return row.entryMethod;
    }

    test('a site saved with both methods reads back with both', () async {
      final created = await repository.createSite(
        const DiveSite(
          id: '',
          name: 'Blue Hole',
          entryMethods: [EntryMethod.boat],
          exitMethods: [EntryMethod.ladder],
        ),
      );

      final loaded = await repository.getSiteById(created.id);
      expect(loaded!.entryMethods, [EntryMethod.boat]);
      expect(loaded.exitMethods, [EntryMethod.ladder]);
      expect(await storedEntry(created.id), 'boat');
    });

    test('several methods are stored joined in enum order', () async {
      final created = await repository.createSite(
        const DiveSite(
          id: '',
          name: 'Two Ways',
          entryMethods: [EntryMethod.boat, EntryMethod.shore],
        ),
      );

      expect(await storedEntry(created.id), 'shore,boat');
      final loaded = await repository.getSiteById(created.id);
      expect(loaded!.entryMethods, [EntryMethod.shore, EntryMethod.boat]);
    });

    test('an updated site persists changed entry methods', () async {
      final created = await repository.createSite(
        const DiveSite(id: '', name: 'Shore Spot'),
      );
      await repository.updateSite(
        created.copyWith(entryMethods: const [EntryMethod.shore]),
      );

      final loaded = await repository.getSiteById(created.id);
      expect(loaded!.entryMethods, [EntryMethod.shore]);
      expect(loaded.exitMethods, isEmpty);
    });

    test('a site saved with neither method stores null', () async {
      final created = await repository.createSite(
        const DiveSite(id: '', name: 'Unknown Access'),
      );

      final loaded = await repository.getSiteById(created.id);
      expect(loaded!.entryMethods, isEmpty);
      expect(loaded.exitMethods, isEmpty);
      expect(await storedEntry(created.id), isNull);
    });
  });
}
