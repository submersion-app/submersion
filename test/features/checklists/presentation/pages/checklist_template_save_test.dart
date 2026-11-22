import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template_section.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_editable_item.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_template_draft.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_template_save.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

import '../../../../helpers/test_database.dart';

/// Counts the list writes a Save makes.
class _CountingRepository extends ChecklistTemplateRepository {
  int sectionWrites = 0;
  int itemWrites = 0;

  @override
  Future<void> saveSections(
    String templateId,
    List<ChecklistTemplateSection> sections,
  ) {
    sectionWrites++;
    return super.saveSections(templateId, sections);
  }

  @override
  Future<void> saveItems(String templateId, List<ChecklistTemplateItem> items) {
    itemWrites++;
    return super.saveItems(templateId, items);
  }
}

final _t = DateTime(2026, 11, 22);

EditableChecklistItem _item(String id, String title, {String? sectionId}) =>
    EditableChecklistItem(
      id: id,
      title: title,
      sectionId: sectionId,
      sortOrder: 0,
      createdAt: _t,
      updatedAt: _t,
    );

/// The form's state: its lists and the draft read from them.
class _Form {
  _Form({
    this.name = 'Packing',
    this.description = '',
    this.sections = const [],
    this.items = const [],
  });
  final String name;
  final String description;
  final List<EditableChecklistSection> sections;
  final List<EditableChecklistItem> items;

  ChecklistTemplateDraft get draft => checklistTemplateDraft(
    name: name,
    description: description,
    sections: sections,
    itemsInDisplayOrder: items,
  );
}

Future<void> _write(
  ChecklistTemplateRepository repository,
  _Form form, {
  String templateId = 'tpl-1',
  String? diverId = 'diver-1',
  _Form? start,
}) => writeChecklistTemplate(
  repository: repository,
  templateId: templateId,
  diverId: diverId,
  draft: form.draft,
  start: start?.draft,
  sections: form.sections,
  itemsInDisplayOrder: form.items,
);

/// A stored template 'tpl-1' with section s1 holding items a and b.
Future<_Form> _seedStored(ChecklistTemplateRepository repository) async {
  final form = _Form(
    description: 'Week trips',
    sections: const [EditableChecklistSection(id: 's1', title: 'Gear')],
    items: [
      _item('a', 'Fins', sectionId: 's1'),
      _item('b', 'Mask', sectionId: 's1'),
    ],
  );
  await _write(repository, form);
  return form;
}

void main() {
  late ChecklistTemplateRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'A', 1, 1)",
    );
    repository = ChecklistTemplateRepository();
  });
  tearDown(tearDownTestDatabase);

  test('a new template is written under the given id with its lists', () async {
    await _write(
      repository,
      _Form(
        sections: const [
          EditableChecklistSection(id: 's1', title: 'Gear'),
          EditableChecklistSection(id: 's2', title: 'Papers'),
        ],
        items: [
          _item('a', 'Fins', sectionId: 's1'),
          _item('b', 'Passport', sectionId: 's2'),
          _item('c', 'Snacks'),
        ],
      ),
    );

    final template = await repository.getTemplateById('tpl-1');
    expect(template?.name, 'Packing');
    expect(template?.diverId, 'diver-1');
    final sections = await repository.getSectionsForTemplate('tpl-1');
    expect([for (final s in sections) s.id], ['s1', 's2']);
    final items = await repository.getItemsForTemplate('tpl-1');
    expect(
      [for (final i in items) (i.id, i.sortOrder)],
      [('a', 0), ('b', 1), ('c', 2)],
    );
  });

  test('a new template with no diver writes nothing and throws', () async {
    await expectLater(
      _write(repository, _Form(), diverId: null),
      throwsStateError,
    );
    expect(await repository.getTemplateById('tpl-1'), isNull);
  });

  test('a rename writes the name and leaves the lists alone', () async {
    final start = await _seedStored(repository);
    // Synced meanwhile: a description the page never saw.
    final stored = await repository.getTemplateById('tpl-1');
    await repository.updateTemplate(stored!.copyWith(description: 'Synced'));

    final counting = _CountingRepository();
    await _write(
      counting,
      _Form(
        name: 'Liveaboard',
        description: start.description,
        sections: start.sections,
        items: start.items,
      ),
      start: start,
    );

    final saved = await repository.getTemplateById('tpl-1');
    expect(saved?.name, 'Liveaboard');
    expect(saved?.description, 'Synced');
    expect(counting.sectionWrites, 0);
    expect(counting.itemWrites, 0);
  });

  test(
    'an item left alone keeps a title changed in storage meanwhile',
    () async {
      final start = await _seedStored(repository);
      final storedItems = await repository.getItemsForTemplate('tpl-1');
      await repository.saveItems('tpl-1', [
        storedItems[0].copyWith(title: 'Long fins'),
        storedItems[1],
      ]);

      await _write(
        repository,
        _Form(
          description: start.description,
          sections: start.sections,
          items: [
            start.items[0],
            _item('b', 'Mask and snorkel', sectionId: 's1'),
          ],
        ),
        start: start,
      );

      final items = await repository.getItemsForTemplate('tpl-1');
      expect(
        [for (final i in items) i.title],
        ['Long fins', 'Mask and snorkel'],
      );
    },
  );

  test('an item added elsewhere meanwhile is kept', () async {
    final start = await _seedStored(repository);
    final storedItems = await repository.getItemsForTemplate('tpl-1');
    await repository.saveItems('tpl-1', [
      ...storedItems,
      ChecklistTemplateItem(
        id: 'synced',
        templateId: 'tpl-1',
        title: 'Torch',
        createdAt: _t,
        updatedAt: _t,
      ),
    ]);

    await _write(
      repository,
      _Form(
        description: start.description,
        sections: start.sections,
        items: [start.items[1], start.items[0]],
      ),
      start: start,
    );

    final items = await repository.getItemsForTemplate('tpl-1');
    expect([for (final i in items) i.id], ['b', 'a', 'synced']);
  });

  test('a section removed elsewhere leaves its items unsectioned', () async {
    final start = await _seedStored(repository);
    await repository.deleteSection('s1');

    await _write(
      repository,
      _Form(
        description: start.description,
        sections: start.sections,
        items: [
          _item('a', 'Fins and booties', sectionId: 's1'),
          start.items[1],
        ],
      ),
      start: start,
    );

    expect(await repository.getSectionsForTemplate('tpl-1'), isEmpty);
    final items = await repository.getItemsForTemplate('tpl-1');
    expect(
      [for (final i in items) (i.title, i.sectionId)],
      [('Fins and booties', null), ('Mask', null)],
    );
  });

  test(
    'a section renamed here and deleted elsewhere keeps its items',
    () async {
      final start = await _seedStored(repository);
      // Another device deleted the section: its items are left unsectioned.
      await repository.deleteSection('s1');
      final storedItems = await repository.getItemsForTemplate('tpl-1');
      await repository.saveItems('tpl-1', [
        for (final item in storedItems) item.copyWith(sectionId: null),
      ]);

      await _write(
        repository,
        _Form(
          description: start.description,
          sections: const [
            EditableChecklistSection(id: 's1', title: 'Dive gear'),
          ],
          items: start.items,
        ),
        start: start,
      );

      final sections = await repository.getSectionsForTemplate('tpl-1');
      expect(
        [for (final s in sections) (s.id, s.title)],
        [('s1', 'Dive gear')],
      );
      final items = await repository.getItemsForTemplate('tpl-1');
      expect(
        [for (final i in items) (i.id, i.sectionId)],
        [('a', 's1'), ('b', 's1')],
      );
    },
  );

  test(
    'a re-created section keeps what storage says of items left alone',
    () async {
      final start = await _seedStored(repository);
      // Another device: adds section s2, moves a into it, retitles b, then
      // deletes s1, which leaves b with no section.
      await repository.saveSections('tpl-1', [
        for (final s in await repository.getSectionsForTemplate('tpl-1')) s,
        ChecklistTemplateSection(
          id: 's2',
          templateId: 'tpl-1',
          title: 'Papers',
          createdAt: _t,
          updatedAt: _t,
        ),
      ]);
      final storedItems = await repository.getItemsForTemplate('tpl-1');
      await repository.saveItems('tpl-1', [
        storedItems[0].copyWith(sectionId: 's2'),
        storedItems[1].copyWith(title: 'Mask and snorkel', sectionId: null),
      ]);
      await repository.deleteSection('s1');

      await _write(
        repository,
        _Form(
          description: start.description,
          sections: const [
            EditableChecklistSection(id: 's1', title: 'Dive gear'),
          ],
          items: start.items,
        ),
        start: start,
      );

      final items = await repository.getItemsForTemplate('tpl-1');
      expect(
        [for (final i in items) (i.id, i.title, i.sectionId)],
        [('a', 'Fins', 's2'), ('b', 'Mask and snorkel', 's1')],
      );
    },
  );

  test('a template deleted meanwhile is refused', () async {
    final start = await _seedStored(repository);
    await repository.deleteTemplate('tpl-1');

    await expectLater(
      _write(
        repository,
        _Form(
          name: 'Renamed',
          description: start.description,
          sections: start.sections,
          items: start.items,
        ),
        start: start,
      ),
      throwsA(isA<RecordSittingRefusal>()),
    );
    expect(await repository.getTemplateById('tpl-1'), isNull);
    expect(await repository.getItemsForTemplate('tpl-1'), isEmpty);
  });
}
