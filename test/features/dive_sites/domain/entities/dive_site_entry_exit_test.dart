import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('DiveSite entry/exit method', () {
    test('defaults to null', () {
      const site = DiveSite(id: 's', name: 'S');
      expect(site.entryMethod, isNull);
      expect(site.exitMethod, isNull);
    });

    test('round-trips through the constructor', () {
      const site = DiveSite(
        id: 's',
        name: 'S',
        entryMethod: EntryMethod.giantStride,
        exitMethod: EntryMethod.ladder,
      );
      expect(site.entryMethod, EntryMethod.giantStride);
      expect(site.exitMethod, EntryMethod.ladder);
    });

    test('copyWith sets both fields', () {
      const site = DiveSite(id: 's', name: 'S');
      final updated = site.copyWith(
        entryMethod: EntryMethod.boat,
        exitMethod: EntryMethod.ladder,
      );
      expect(updated.entryMethod, EntryMethod.boat);
      expect(updated.exitMethod, EntryMethod.ladder);
    });

    test('copyWith preserves both fields when they are not passed', () {
      const site = DiveSite(
        id: 's',
        name: 'S',
        entryMethod: EntryMethod.shore,
        exitMethod: EntryMethod.shore,
      );
      final updated = site.copyWith(name: 'Renamed');
      expect(updated.entryMethod, EntryMethod.shore);
      expect(updated.exitMethod, EntryMethod.shore);
    });

    test('equality distinguishes sites by entry method', () {
      const a = DiveSite(id: 's', name: 'S', entryMethod: EntryMethod.boat);
      const b = DiveSite(id: 's', name: 'S', entryMethod: EntryMethod.shore);
      expect(a, isNot(equals(b)));
    });

    test('equality distinguishes sites by exit method', () {
      const a = DiveSite(id: 's', name: 'S', exitMethod: EntryMethod.ladder);
      const b = DiveSite(id: 's', name: 'S', exitMethod: EntryMethod.platform);
      expect(a, isNot(equals(b)));
    });
  });

  group('DiveSite persistence round-trip', () {
    late SiteRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = SiteRepository();
    });

    tearDown(tearDownTestDatabase);

    test('a site saved with both methods reads back with both', () async {
      final created = await repository.createSite(
        const DiveSite(
          id: '',
          name: 'Blue Hole',
          entryMethod: EntryMethod.boat,
          exitMethod: EntryMethod.ladder,
        ),
      );

      final loaded = await repository.getSiteById(created.id);
      expect(loaded!.entryMethod, EntryMethod.boat);
      expect(loaded.exitMethod, EntryMethod.ladder);
    });

    test('an updated site persists a changed entry method', () async {
      final created = await repository.createSite(
        const DiveSite(id: '', name: 'Shore Spot'),
      );
      await repository.updateSite(
        created.copyWith(entryMethod: EntryMethod.shore),
      );

      final loaded = await repository.getSiteById(created.id);
      expect(loaded!.entryMethod, EntryMethod.shore);
      expect(loaded.exitMethod, isNull);
    });

    test('a site saved with neither method reads back with neither', () async {
      final created = await repository.createSite(
        const DiveSite(id: '', name: 'Unknown Access'),
      );

      final loaded = await repository.getSiteById(created.id);
      expect(loaded!.entryMethod, isNull);
      expect(loaded.exitMethod, isNull);
    });
  });
}
