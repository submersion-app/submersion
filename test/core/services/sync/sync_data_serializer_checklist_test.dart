import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart'
    as domain;
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart'
    as domain;
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../helpers/test_database.dart';

/// Round-trips the three checklist entity types (added in this PR) through
/// every per-entity switch in [SyncDataSerializer]: fetchRecord, the batched
/// fetchRecords, upsertRecord, recordIdsFor, and deleteRecord. Each row is
/// seeded through the real feature repositories so the JSON shape matches
/// what the app actually writes.
void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });

  tearDown(tearDownTestDatabase);

  test('checklistTemplates round-trips fetchRecord/fetchRecords/upsertRecord/'
      'recordIdsFor/deleteRecord', () async {
    final repo = ChecklistTemplateRepository();
    final created = await repo.createTemplate(
      domain.ChecklistTemplate(
        id: '',
        name: 'Packing',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final fetched = await serializer.fetchRecord(
      'checklistTemplates',
      created.id,
    );
    expect(fetched, isNotNull);
    expect(fetched!['name'], 'Packing');

    final batch = await serializer.fetchRecords('checklistTemplates', [
      created.id,
      'absent-id',
    ]);
    expect(batch.keys.toSet(), {created.id});
    expect(batch[created.id]!['name'], 'Packing');

    expect(
      await serializer.recordIdsFor('checklistTemplates'),
      contains(created.id),
    );

    // upsertRecord is the single-record write path (distinct from the
    // batched upsertRecords exercised elsewhere): feed the fetched JSON
    // back with a changed field and confirm it persists.
    await serializer.upsertRecord('checklistTemplates', {
      ...fetched,
      'name': 'Renamed',
    });
    expect(
      (await serializer.fetchRecord('checklistTemplates', created.id))?['name'],
      'Renamed',
    );

    await serializer.deleteRecord('checklistTemplates', created.id);
    expect(
      await serializer.fetchRecord('checklistTemplates', created.id),
      isNull,
    );
    expect(
      await serializer.recordIdsFor('checklistTemplates'),
      isNot(contains(created.id)),
    );
  });

  test('checklistTemplateItems round-trips fetchRecord/fetchRecords/'
      'upsertRecord/recordIdsFor/deleteRecord', () async {
    final templateRepo = ChecklistTemplateRepository();
    final template = await templateRepo.createTemplate(
      domain.ChecklistTemplate(
        id: '',
        name: 'Packing',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await templateRepo.saveItems(template.id, [
      domain.ChecklistTemplateItem(
        id: '',
        templateId: template.id,
        title: 'Wetsuit',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ]);
    final created = (await templateRepo.getItemsForTemplate(
      template.id,
    )).single;

    final fetched = await serializer.fetchRecord(
      'checklistTemplateItems',
      created.id,
    );
    expect(fetched, isNotNull);
    expect(fetched!['title'], 'Wetsuit');

    final batch = await serializer.fetchRecords('checklistTemplateItems', [
      created.id,
      'absent-id',
    ]);
    expect(batch.keys.toSet(), {created.id});

    expect(
      await serializer.recordIdsFor('checklistTemplateItems'),
      contains(created.id),
    );

    await serializer.upsertRecord('checklistTemplateItems', {
      ...fetched,
      'title': 'Drysuit',
    });
    expect(
      (await serializer.fetchRecord(
        'checklistTemplateItems',
        created.id,
      ))?['title'],
      'Drysuit',
    );

    await serializer.deleteRecord('checklistTemplateItems', created.id);
    expect(
      await serializer.fetchRecord('checklistTemplateItems', created.id),
      isNull,
    );
  });

  test('tripChecklistItems round-trips fetchRecord/fetchRecords/upsertRecord/'
      'recordIdsFor/deleteRecord', () async {
    final trip = await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Red Sea',
        startDate: DateTime(2026, 9, 10),
        endDate: DateTime(2026, 9, 17),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final created = await TripChecklistRepository().createItem(
      domain.TripChecklistItem(
        id: '',
        tripId: trip.id,
        title: 'Book flights',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final fetched = await serializer.fetchRecord(
      'tripChecklistItems',
      created.id,
    );
    expect(fetched, isNotNull);
    expect(fetched!['title'], 'Book flights');

    final batch = await serializer.fetchRecords('tripChecklistItems', [
      created.id,
      'absent-id',
    ]);
    expect(batch.keys.toSet(), {created.id});

    expect(
      await serializer.recordIdsFor('tripChecklistItems'),
      contains(created.id),
    );

    await serializer.upsertRecord('tripChecklistItems', {
      ...fetched,
      'title': 'Book hotel',
    });
    expect(
      (await serializer.fetchRecord(
        'tripChecklistItems',
        created.id,
      ))?['title'],
      'Book hotel',
    );

    await serializer.deleteRecord('tripChecklistItems', created.id);
    expect(
      await serializer.fetchRecord('tripChecklistItems', created.id),
      isNull,
    );
  });
}
