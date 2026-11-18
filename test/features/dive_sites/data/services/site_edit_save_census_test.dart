import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' hide DiveSite;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/site_edit_save_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

/// Columns of `dive_sites` that are not a value a sitting edits, with why.
const notASittingValue = <String, String>{
  'id': 'the key',
  'diver_id': 'the owner',
  'created_at': 'bookkeeping',
  'updated_at': 'bookkeeping',
  'hlc': 'sync bookkeeping',
  'catalogue_id': 'set by adoption, import and the catalogue fill only',
  'catalogue_answers': 'set by the catalogue fill only',
  'shared_library_id': 'set by the shared library only',
  'is_shared': 'written by the sharing held change (site_sharing_sitting)',
};

/// The columns each sitting field writes, by field id, where they differ
/// from the id in snake case.
const columnsOf = <String, List<String>>{
  'location': ['latitude', 'longitude'],
  'entryMethods': ['entry_method'],
  'exitMethods': ['exit_method'],
};

String _snake(String camel) =>
    camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

/// A site's sitting carries every column it does not change, and every
/// column a diver edits has a sitting field (issue #4527, phase 2).
void main() {
  late AppDatabase db;
  late SiteRepository sites;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    sites = SiteRepository();
    await insertDiver(db, 'me');
  });

  tearDown(tearDownTestDatabase);

  test('every editable column has a sitting field', () {
    final columns = {for (final c in db.diveSites.$columns) c.name};
    final covered = {
      for (final field in siteSittingFields)
        ...columnsOf[field.id] ?? [_snake(field.id)],
    };
    expect(columns.difference(notASittingValue.keys.toSet()), covered);
  });

  test('a sitting carries every column it does not change', () async {
    const first = DiveSite(
      id: 's1',
      diverId: 'me',
      name: 'Blue Hole',
      description: 'Wall',
      notes: 'Calm',
      location: GeoPoint(17.3, -87.5),
      minDepth: 5,
      maxDepth: 40,
      difficulty: SiteDifficulty.advanced,
      waterType: WaterType.salt,
      country: 'Belize',
      countryCode: 'BZ',
      region: 'Lighthouse Reef',
      city: 'Belize City',
      island: 'Ambergris',
      bodyOfWater: 'Caribbean Sea',
      rating: 4,
      hazards: 'Current',
      accessNotes: 'Boat only',
      mooringNumber: 'M12',
      parkingInfo: 'None',
      altitude: 3,
      entryMethods: [EntryMethod.backRoll],
      exitMethods: [EntryMethod.ladder],
    );
    await sites.createSite(first);
    // Every value changed underneath, as a sync would, after the sitting
    // began on [first].
    final second = first.copyWith(
      name: 'Great Blue Hole',
      description: 'Sinkhole',
      location: const GeoPoint(17.31, -87.53),
      minDepth: 6,
      maxDepth: 120,
      difficulty: SiteDifficulty.technical,
      waterType: WaterType.brackish,
      country: 'Mexico',
      countryCode: 'MX',
      region: 'Quintana Roo',
      city: 'Tulum',
      island: 'Cozumel',
      bodyOfWater: 'Gulf',
      rating: 5,
      hazards: 'Depth',
      accessNotes: 'Shore',
      mooringNumber: 'M13',
      parkingInfo: 'Lot',
      altitude: 4,
      entryMethods: [EntryMethod.shore],
      exitMethods: [EntryMethod.shore],
    );
    await sites.updateSite(second);

    await SiteEditSaveService(sites).save(
      siteId: 's1',
      // The sitting changed the notes only.
      apply: (stored) => stored.copyWith(notes: 'Choppy'),
      changedCardIds: const ['notes'],
    );

    expect(await sites.getSiteById('s1'), second.copyWith(notes: 'Choppy'));
  });
}
