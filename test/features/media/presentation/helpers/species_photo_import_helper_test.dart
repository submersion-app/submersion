import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/import_candidate.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/helpers/species_photo_import_helper.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';
import '../../data/repositories/species_photo_fixtures.dart';
import '../support/media_widget_harness.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10));
    await insertTestSpecies(id: 'sp_whale_shark', name: 'Whale Shark');
    await insertTestMedia(id: 'p1', diveId: 'd1');
    await insertTestMedia(id: 'p2', diveId: 'd1');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('ImportReviewResult defaults to no imported ids', () {
    const review = ImportReviewResult(linked: 0, skipped: 0);
    expect(review.importedIds, isEmpty);
  });

  // A species page in a sitting prepares the reviewed photos and holds them
  // until Save (issue #4527, phase 3): nothing is written here.
  group('prepareResolved', () {
    AssetInfo asset(String id) => AssetInfo(
      id: id,
      type: AssetType.image,
      createDateTime: DateTime(2024, 1, 10, 10),
      width: 10,
      height: 10,
    );

    PreparedMedia prepared(String id, {String? diveId, String? siteId}) => (
      item: testMediaItem(id: 'm-$id', diveId: diveId, siteId: siteId),
      enrichment: null,
    );

    test('prepares each photo for its dive or site and writes none', () async {
      final asked = <String>[];
      final result = await SpeciesPhotoImportHelper.prepareResolved(
        assets: [asset('a1'), asset('a2'), asset('a3')],
        targets: const {
          'a1': DiveAttachTarget('d1'),
          'a2': DiveAttachTarget('d1'),
          'a3': SiteAttachTarget('s1'),
        },
        prepareForDive: (diveId, assets) async {
          asked.add('dive $diveId ${assets.length}');
          return [for (final a in assets) prepared(a.id, diveId: diveId)];
        },
        prepareForSite: (siteId, assets) async {
          asked.add('site $siteId ${assets.length}');
          return [for (final a in assets) prepared(a.id, siteId: siteId)];
        },
      );

      expect(asked, ['dive d1 2', 'site s1 1']);
      expect(result.prepared.map((p) => p.item.id), ['m-a1', 'm-a2', 'm-a3']);
      expect(result.review.linked, 3);
      expect(result.review.failures, isEmpty);
    });

    test('a group that cannot be prepared is reported and left out', () async {
      final result = await SpeciesPhotoImportHelper.prepareResolved(
        assets: [asset('a1'), asset('a2')],
        targets: const {
          'a1': DiveAttachTarget('gone'),
          'a2': SiteAttachTarget('s1'),
        },
        prepareForDive: (diveId, assets) async =>
            throw StateError('dive $diveId no longer exists'),
        prepareForSite: (siteId, assets) async => [
          for (final a in assets) prepared(a.id, siteId: siteId),
        ],
      );

      expect(result.prepared.map((p) => p.item.id), ['m-a2']);
      expect(result.review.failures.keys, ['a1']);
    });

    test('a photo already linked there is counted as skipped', () async {
      final result = await SpeciesPhotoImportHelper.prepareResolved(
        assets: [asset('a1'), asset('a2')],
        targets: const {
          'a1': DiveAttachTarget('d1'),
          'a2': DiveAttachTarget('d1'),
        },
        prepareForDive: (diveId, assets) async => [prepared('a1')],
        prepareForSite: (siteId, assets) async => const [],
      );

      expect(result.review.linked, 1);
      expect(result.review.skipped, 1);
    });
  });

  test('photos that could not be prepared are said; none, nothing', () {
    final l = lookupAppLocalizations(const Locale('en'));

    expect(
      SpeciesPhotoImportHelper.speciesPrepareFailureMessage(l, 2),
      l.marineLife_speciesPhotos_importFailed(2),
    );
    expect(SpeciesPhotoImportHelper.speciesPrepareFailureMessage(l, 0), isNull);
  });
}
