import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../helpers/test_database.dart';

void main() {
  group('Checklist sync round trip', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('trip + template + trip checklist items survive export and JSON '
        'round-trip', () async {
      // 1. Create a trip, a template with 2 items, and 2 trip checklist
      //    items (one done) through the real repositories.
      final tripRepository = TripRepository();
      final templateRepository = ChecklistTemplateRepository();
      final tripChecklistRepository = TripChecklistRepository();

      final trip = await tripRepository.createTrip(
        Trip(
          id: '',
          name: 'Red Sea Liveaboard',
          startDate: DateTime(2026, 9, 10),
          endDate: DateTime(2026, 9, 17),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final template = await templateRepository.createTemplate(
        ChecklistTemplate(
          id: '',
          name: 'Liveaboard Packing',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await templateRepository.saveItems(template.id, [
        ChecklistTemplateItem(
          id: '',
          templateId: template.id,
          title: 'Wetsuit',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ChecklistTemplateItem(
          id: '',
          templateId: template.id,
          title: 'Regulator',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);

      final pendingItem = await tripChecklistRepository.createItem(
        TripChecklistItem(
          id: '',
          tripId: trip.id,
          title: 'Book flights',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final doneItem = await tripChecklistRepository.createItem(
        TripChecklistItem(
          id: '',
          tripId: trip.id,
          title: 'Confirm nitrox certification',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await tripChecklistRepository.toggleDone(doneItem.id, isDone: true);

      // 2. Export a full SyncData via the serializer (hlcSince: null).
      final serializer = SyncDataSerializer();
      final syncRepository = SyncRepository();
      final deviceId = await syncRepository.getDeviceId();
      final deletions = await syncRepository.getAllDeletions();

      final payload = await serializer.exportData(
        deviceId: deviceId,
        lastSyncTimestamp: null,
        deletions: deletions,
      );
      final data = payload.data;

      // 3. Assert record counts and that is-done round-trips truthy.
      expect(data.checklistTemplates, hasLength(1));
      expect(data.checklistTemplateItems, hasLength(2));
      expect(data.tripChecklistItems, hasLength(2));

      expect(
        data.checklistTemplates.single['id'],
        template.id,
        reason: 'the exported template must be the one just created',
      );

      final exportedDoneItem = data.tripChecklistItems.singleWhere(
        (row) => row['id'] == doneItem.id,
      );
      final exportedPendingItem = data.tripChecklistItems.singleWhere(
        (row) => row['id'] == pendingItem.id,
      );
      expect(
        exportedDoneItem['isDone'],
        isTrue,
        reason: 'the toggled-done trip checklist item must export as done',
      );
      expect(
        exportedPendingItem['isDone'],
        isFalse,
        reason: 'the untouched trip checklist item must export as pending',
      );

      // 4. SyncData.fromJson(jsonDecode(jsonEncode(data.toJson()))) must
      //    preserve all three lists (lengths and record ids).
      final roundTripped = SyncData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
      );

      expect(roundTripped.checklistTemplates, hasLength(1));
      expect(roundTripped.checklistTemplateItems, hasLength(2));
      expect(roundTripped.tripChecklistItems, hasLength(2));

      expect(
        roundTripped.checklistTemplates.map((r) => r['id']).toSet(),
        data.checklistTemplates.map((r) => r['id']).toSet(),
      );
      expect(
        roundTripped.checklistTemplateItems.map((r) => r['id']).toSet(),
        data.checklistTemplateItems.map((r) => r['id']).toSet(),
      );
      expect(
        roundTripped.tripChecklistItems.map((r) => r['id']).toSet(),
        data.tripChecklistItems.map((r) => r['id']).toSet(),
      );

      final roundTrippedDoneItem = roundTripped.tripChecklistItems.singleWhere(
        (row) => row['id'] == doneItem.id,
      );
      expect(
        roundTrippedDoneItem['isDone'],
        isTrue,
        reason: 'is-done must still be truthy after a JSON round-trip',
      );
    });
  });
}
