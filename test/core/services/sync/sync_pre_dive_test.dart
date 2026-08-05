import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_session_repository.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_template_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';

import '../../../helpers/test_database.dart';

void main() {
  group('Pre-dive checklist sync', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('user template + session survive export and JSON round-trip; '
        'built-ins are skipped', () async {
      final templateRepository = PreDiveTemplateRepository();
      final sessionRepository = PreDiveSessionRepository();

      final template = await templateRepository.createTemplate(
        PreDiveChecklistTemplate(
          id: '',
          name: 'My Buddy Check',
          strictOrder: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await templateRepository.saveItems(template.id, [
        PreDiveChecklistTemplateItem(
          id: '',
          templateId: template.id,
          title: 'Gas on',
          isRequired: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        PreDiveChecklistTemplateItem(
          id: '',
          templateId: template.id,
          title: 'Cell check',
          itemType: PreDiveItemType.value,
          valueLabel: 'Cell 1',
          valueUnit: 'mV',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);

      final session = await sessionRepository.startSession(
        template: template,
        items: [
          PreDiveSessionItem(
            id: '',
            sessionId: '',
            title: 'Gas on',
            isRequired: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      );
      final sessionItems = await sessionRepository.getItemsForSession(
        session.id,
      );
      await sessionRepository.updateItemState(
        sessionId: session.id,
        itemId: sessionItems.single.id,
        state: PreDiveItemState.done,
      );

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

      // User rows exported.
      expect(data.preDiveChecklistTemplates, hasLength(1));
      expect(data.preDiveChecklistTemplates.single['id'], template.id);
      expect(data.preDiveChecklistTemplateItems, hasLength(2));
      expect(data.preDiveSessions, hasLength(1));
      expect(data.preDiveSessionItems, hasLength(1));
      expect(data.preDiveSessionItems.single['state'], 'done');

      // Built-in templates (seeded in beforeOpen) and their items are
      // re-seeded identically on every device and must not export.
      final exportedTemplateIds = data.preDiveChecklistTemplates
          .map((r) => r['id'])
          .toSet();
      expect(
        exportedTemplateIds.any((id) => (id as String).startsWith('builtin-')),
        isFalse,
        reason: 'built-in templates must not export',
      );
      final exportedItemIds = data.preDiveChecklistTemplateItems
          .map((r) => r['id'])
          .toSet();
      expect(
        exportedItemIds.any((id) => (id as String).startsWith('builtin-')),
        isFalse,
        reason: 'built-in template items must not export',
      );

      // JSON round-trip preserves all four lists.
      final roundTripped = SyncData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
      );
      expect(roundTripped.preDiveChecklistTemplates, hasLength(1));
      expect(roundTripped.preDiveChecklistTemplateItems, hasLength(2));
      expect(roundTripped.preDiveSessions, hasLength(1));
      expect(roundTripped.preDiveSessionItems, hasLength(1));
      expect(roundTripped.preDiveSessions.single['id'], session.id);
    });
  });
}
