import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/conflict_reference.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Unit coverage for [ConflictReferenceResolver] (#1031): the lookup step that
/// turns the foreign-key columns of a conflicting record into the referenced
/// rows' real-world anchors, so the Resolve Conflicts dialog can name a tag and
/// date a dive instead of printing two UUIDs.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;
  late ConflictReferenceResolver resolver;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    resolver = ConflictReferenceResolver(serializer);
  });
  tearDown(tearDownTestDatabase);

  Future<void> seedTag(String id, String name) => serializer.upsertRecord(
    'tags',
    {'id': id, 'name': name, 'createdAt': 1000, 'updatedAt': 1000},
  );

  Future<void> seedSite(String id, String name) =>
      serializer.upsertRecord('diveSites', {
        'id': id,
        'name': name,
        'description': '',
        'notes': '',
        'isShared': false,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

  Future<void> seedDive(String id, {String? siteId}) async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: id, diveNumber: 1),
    );
    if (siteId != null) {
      await db.customStatement('UPDATE dives SET site_id = ? WHERE id = ?', [
        siteId,
        id,
      ]);
    }
  }

  ConflictReference refFor(List<ConflictReference> refs, String field) =>
      refs.firstWhere((r) => r.field == field);

  test('resolves both foreign keys of a diveTags junction row', () async {
    await seedSite('site-1', 'Blue Hole');
    await seedDive('dive-1', siteId: 'site-1');
    await seedTag('tag-1', 'Wreck');

    final refs = await resolver.resolve('diveTags', {
      'id': 'junction-1',
      'diveId': 'dive-1',
      'tagId': 'tag-1',
      'createdAt': 1786556582600,
    });

    expect(refs, hasLength(2));

    final tag = refFor(refs, 'tagId');
    expect(tag.targetType, 'tags');
    expect(tag.recordId, 'tag-1');
    expect(tag.name, 'Wreck');
    expect(tag.isMissing, isFalse);

    final dive = refFor(refs, 'diveId');
    expect(dive.targetType, 'dives');
    expect(dive.name, 'Blue Hole', reason: 'a dive is named by its site');
    expect(dive.timestamp, DateTime(2026, 3, 28, 10, 0));
  });

  test('marks a reference whose row is absent locally as missing', () async {
    await seedDive('dive-1');

    final refs = await resolver.resolve('diveTags', {
      'id': 'junction-1',
      'diveId': 'dive-1',
      'tagId': 'tag-gone',
      'createdAt': 1000,
    });

    final tag = refFor(refs, 'tagId');
    expect(tag.isMissing, isTrue);
    expect(tag.name, isNull);
    expect(tag.recordId, 'tag-gone');
  });

  test('a dive with no site is still anchored by its date', () async {
    await seedDive('dive-1');

    final refs = await resolver.resolve('diveTags', {
      'diveId': 'dive-1',
      'tagId': 'tag-1',
    });

    final dive = refFor(refs, 'diveId');
    expect(dive.name, isNull);
    expect(dive.timestamp, DateTime(2026, 3, 28, 10, 0));
    expect(dive.isMissing, isFalse);
  });

  test("ignores the record's own id and non-reference fields", () async {
    await seedDive('dive-1');

    final refs = await resolver.resolve('qualityFindings', {
      'id': 'finding-1',
      'diveId': 'dive-1',
      'detectorId': 'depth_spike',
      'detectorVersion': 1,
      'params': '{"atSeconds":120}',
      'createdAt': 1000,
    });

    expect(refs.map((r) => r.field), ['diveId']);
  });

  test('skips null foreign keys', () async {
    await seedDive('dive-1');

    final refs = await resolver.resolve('qualityFindings', {
      'id': 'finding-1',
      'diveId': 'dive-1',
      'relatedDiveId': null,
      'computerId': null,
    });

    expect(refs.map((r) => r.field), ['diveId']);
  });

  test('resolves a nullable cross-dive reference when it is set', () async {
    await seedDive('dive-1');
    await seedSite('site-2', 'The Arch');
    await seedDive('dive-2', siteId: 'site-2');

    final refs = await resolver.resolve('qualityFindings', {
      'id': 'finding-1',
      'diveId': 'dive-1',
      'relatedDiveId': 'dive-2',
    });

    expect(refFor(refs, 'relatedDiveId').name, 'The Arch');
  });

  test('disambiguates templateId by the owning entity type', () async {
    await serializer.upsertRecord('preDiveChecklistTemplates', {
      'id': 'tpl-1',
      'name': 'Pre-dive buddy check',
      'createdAt': 1000,
      'updatedAt': 1000,
    });
    await serializer.upsertRecord('checklistTemplates', {
      'id': 'tpl-1',
      'name': 'Trip packing list',
      'createdAt': 1000,
      'updatedAt': 1000,
    });

    final preDive = await resolver.resolve('preDiveSessions', {
      'id': 'session-1',
      'templateId': 'tpl-1',
    });
    expect(
      refFor(preDive, 'templateId').targetType,
      'preDiveChecklistTemplates',
    );
    expect(refFor(preDive, 'templateId').name, 'Pre-dive buddy check');

    final trip = await resolver.resolve('checklistTemplateItems', {
      'id': 'item-1',
      'templateId': 'tpl-1',
    });
    expect(refFor(trip, 'templateId').targetType, 'checklistTemplates');
    expect(refFor(trip, 'templateId').name, 'Trip packing list');
  });

  test('resolves a species sighting by its common name', () async {
    await serializer.upsertRecord('species', {
      'id': 'sp-1',
      'commonName': 'Manta ray',
      'scientificName': 'Mobula birostris',
      'category': 'fish',
    });
    await seedDive('dive-1');

    final refs = await resolver.resolve('sightings', {
      'id': 'sighting-1',
      'diveId': 'dive-1',
      'speciesId': 'sp-1',
    });

    expect(refFor(refs, 'speciesId').name, 'Manta ray');
  });

  test('a row that exists is never reported as missing', () async {
    // diveTanks carries no name or date column, so "found no anchor" must not
    // be read as "row is gone" -- telling a user a record was deleted right
    // before they choose what to keep is worse than showing them an id.
    await seedDive('dive-1');
    await serializer.upsertRecord('diveTanks', {
      'id': 'tank-1',
      'diveId': 'dive-1',
      'o2Percent': 21.0,
      'hePercent': 0.0,
      'tankOrder': 0,
      'tankRole': 'primary',
    });

    final refs = await resolver.resolve('gasSwitches', {
      'id': 'gs-1',
      'diveId': 'dive-1',
      'tankId': 'tank-1',
    });

    expect(refFor(refs, 'tankId').isMissing, isFalse);
  });

  test('names a tank by its user-facing tank name', () async {
    await seedDive('dive-1');
    await serializer.upsertRecord('diveTanks', {
      'id': 'tank-1',
      'diveId': 'dive-1',
      'tankName': 'Primary AL80',
      'o2Percent': 21.0,
      'hePercent': 0.0,
      'tankOrder': 0,
      'tankRole': 'primary',
    });

    final refs = await resolver.resolve('gasSwitches', {
      'id': 'gs-1',
      'diveId': 'dive-1',
      'tankId': 'tank-1',
    });

    expect(refFor(refs, 'tankId').name, 'Primary AL80');
  });

  test('returns nothing for an entity with no foreign keys', () async {
    final refs = await resolver.resolve('tags', {
      'id': 'tag-1',
      'name': 'Wreck',
      'createdAt': 1000,
    });

    expect(refs, isEmpty);
  });
}
