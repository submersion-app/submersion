import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_template_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_editable_item.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_template_draft.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_template_save.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

import '../../../../helpers/test_database.dart';

final _t = DateTime(2026, 11, 22);

EditablePreDiveItem _item(
  String id,
  String title, {
  String? sectionId,
  double? valueMin,
}) => EditablePreDiveItem(
  id: id,
  title: title,
  sectionId: sectionId,
  itemType: valueMin == null ? PreDiveItemType.check : PreDiveItemType.value,
  valueMin: valueMin,
  createdAt: _t,
  updatedAt: _t,
);

/// The form's state: its fields, its lists and the draft read from them.
class _Form {
  _Form({
    this.name = 'Twinset',
    this.category = '',
    this.strictOrder = false,
    this.sections = const [],
    this.items = const [],
  });
  final String name;
  final String category;
  final bool strictOrder;
  final List<EditablePreDiveSection> sections;
  final List<EditablePreDiveItem> items;

  _Form copyWith({
    String? name,
    bool? strictOrder,
    List<EditablePreDiveItem>? items,
  }) => _Form(
    name: name ?? this.name,
    category: category,
    strictOrder: strictOrder ?? this.strictOrder,
    sections: sections,
    items: items ?? this.items,
  );

  PreDiveTemplateDraft get draft => preDiveTemplateDraft(
    name: name,
    description: '',
    category: category,
    strictOrder: strictOrder,
    sections: sections,
    itemsInDisplayOrder: items,
  );
}

Future<void> _write(
  PreDiveTemplateRepository repository,
  _Form form, {
  String? diverId = 'diver-1',
  _Form? start,
}) => writePreDiveTemplate(
  repository: repository,
  templateId: 'tpl-1',
  diverId: diverId,
  draft: form.draft,
  start: start?.draft,
  sections: form.sections,
  itemsInDisplayOrder: form.items,
);

/// A stored template 'tpl-1': section s1 holding a value item with a
/// threshold carrying floating-point noise, and an unsectioned check.
Future<_Form> _seedStored(PreDiveTemplateRepository repository) async {
  final form = _Form(
    sections: const [EditablePreDiveSection(id: 's1', title: 'Gas')],
    items: [
      _item('a', 'Pressure', sectionId: 's1', valueMin: 0.1 + 0.2),
      _item('b', 'Buddy check'),
    ],
  );
  await _write(repository, form);
  return form;
}

void main() {
  late PreDiveTemplateRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'A', 1, 1)",
    );
    repository = PreDiveTemplateRepository();
  });
  tearDown(tearDownTestDatabase);

  test('a new template is written under the given id with its lists', () async {
    await _seedStored(repository);

    final template = await repository.getTemplateById('tpl-1');
    expect(template?.name, 'Twinset');
    expect(template?.diverId, 'diver-1');
    expect(template?.category, isNull);
    final sections = await repository.getSectionsForTemplate('tpl-1');
    expect([for (final s in sections) s.id], ['s1']);
    final items = await repository.getItemsForTemplate('tpl-1');
    expect([for (final i in items) (i.id, i.sortOrder)], [('a', 0), ('b', 1)]);
  });

  test('a new template with no diver writes nothing and throws', () async {
    await expectLater(
      _write(repository, _Form(), diverId: null),
      throwsStateError,
    );
    expect(await repository.getTemplateById('tpl-1'), isNull);
  });

  test('an untouched threshold keeps its stored value', () async {
    final start = await _seedStored(repository);

    // The item dialog, confirmed unchanged, reads the shown "0.3" back.
    await _write(
      repository,
      start.copyWith(
        items: [
          _item('a', 'Pressure', sectionId: 's1', valueMin: 0.3),
          _item('b', 'Buddy check done'),
        ],
      ),
      start: start,
    );

    final items = await repository.getItemsForTemplate('tpl-1');
    expect(items.first.valueMin, 0.1 + 0.2);
    expect(items.last.title, 'Buddy check done');
  });

  test('turning strict order on keeps a name synced meanwhile', () async {
    final start = await _seedStored(repository);
    final stored = await repository.getTemplateById('tpl-1');
    await repository.updateTemplate(stored!.copyWith(name: 'Synced'));

    await _write(repository, start.copyWith(strictOrder: true), start: start);

    final saved = await repository.getTemplateById('tpl-1');
    expect(saved?.name, 'Synced');
    expect(saved?.strictOrder, isTrue);
  });

  test('an item left alone keeps a change made in storage meanwhile', () async {
    final start = await _seedStored(repository);
    final storedItems = await repository.getItemsForTemplate('tpl-1');
    await repository.saveItems('tpl-1', [
      storedItems[0].copyWith(title: 'Back gas pressure'),
      storedItems[1],
    ]);

    await _write(
      repository,
      start.copyWith(items: [start.items[0], _item('b', 'Buddy check done')]),
      start: start,
    );

    final items = await repository.getItemsForTemplate('tpl-1');
    expect(
      [for (final i in items) i.title],
      ['Back gas pressure', 'Buddy check done'],
    );
  });

  test('a section removed elsewhere leaves its items unsectioned', () async {
    final start = await _seedStored(repository);
    await repository.deleteSection('s1');

    await _write(
      repository,
      start.copyWith(
        items: [
          _item('a', 'Pressure', sectionId: 's1', valueMin: 200),
          start.items[1],
        ],
      ),
      start: start,
    );

    final items = await repository.getItemsForTemplate('tpl-1');
    expect(
      [for (final i in items) (i.valueMin, i.sectionId)],
      [(200.0, null), (null, null)],
    );
  });

  test(
    'a section renamed here and deleted elsewhere keeps its items',
    () async {
      final start = await _seedStored(repository);
      // Another device deleted the section: its item is left unsectioned.
      await repository.deleteSection('s1');
      final storedItems = await repository.getItemsForTemplate('tpl-1');
      await repository.saveItems('tpl-1', [
        for (final item in storedItems) item.copyWith(sectionId: null),
      ]);

      await _write(
        repository,
        _Form(
          sections: const [EditablePreDiveSection(id: 's1', title: 'Back gas')],
          items: start.items,
        ),
        start: start,
      );

      final sections = await repository.getSectionsForTemplate('tpl-1');
      expect([for (final s in sections) (s.id, s.title)], [('s1', 'Back gas')]);
      final items = await repository.getItemsForTemplate('tpl-1');
      expect(
        [for (final i in items) (i.id, i.sectionId)],
        [('a', 's1'), ('b', null)],
      );
    },
  );

  test(
    'a re-created section keeps what storage says of items left alone',
    () async {
      final start = await _seedStored(repository);
      // Another device retitles a, then deletes s1, leaving a unsectioned.
      final storedItems = await repository.getItemsForTemplate('tpl-1');
      await repository.saveItems('tpl-1', [
        storedItems[0].copyWith(title: 'Back gas pressure', sectionId: null),
        storedItems[1],
      ]);
      await repository.deleteSection('s1');

      await _write(
        repository,
        _Form(
          sections: const [EditablePreDiveSection(id: 's1', title: 'Back gas')],
          items: start.items,
        ),
        start: start,
      );

      final items = await repository.getItemsForTemplate('tpl-1');
      expect(
        [for (final i in items) (i.id, i.title, i.sectionId)],
        [('a', 'Back gas pressure', 's1'), ('b', 'Buddy check', null)],
      );
    },
  );

  test('a template deleted meanwhile is refused', () async {
    final start = await _seedStored(repository);
    await repository.deleteTemplate('tpl-1');

    await expectLater(
      _write(repository, start.copyWith(name: 'Renamed'), start: start),
      throwsA(isA<RecordSittingRefusal>()),
    );
    expect(await repository.getTemplateById('tpl-1'), isNull);
  });
}
