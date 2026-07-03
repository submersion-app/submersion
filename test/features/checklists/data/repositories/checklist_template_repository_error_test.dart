import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';

import '../../../../helpers/test_database.dart';

/// Mirrors tank_preset_repository_error_test.dart: close the database out
/// from under the repository so every try/catch's log+rethrow path runs for
/// real, instead of only ever being unit-tested via the happy path.
void main() {
  group('ChecklistTemplateRepository error handling', () {
    late ChecklistTemplateRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = ChecklistTemplateRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('methods rethrow when the database is unavailable', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      final now = DateTime.now();
      final template = ChecklistTemplate(
        id: 'tpl1',
        name: 'Packing',
        createdAt: now,
        updatedAt: now,
      );

      await expectLater(
        repository.getAllTemplates(diverId: 'diver1'),
        throwsA(anything),
      );
      await expectLater(repository.getTemplateById('tpl1'), throwsA(anything));
      await expectLater(
        repository.getItemsForTemplate('tpl1'),
        throwsA(anything),
      );
      await expectLater(repository.createTemplate(template), throwsA(anything));
      await expectLater(repository.updateTemplate(template), throwsA(anything));
      await expectLater(repository.deleteTemplate('tpl1'), throwsA(anything));
      await expectLater(
        repository.saveItems('tpl1', [
          ChecklistTemplateItem(
            id: 'x1',
            templateId: 'tpl1',
            title: 'Wetsuit',
            createdAt: now,
            updatedAt: now,
          ),
        ]),
        throwsA(anything),
      );
    });
  });
}
