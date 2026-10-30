import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template_section.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_section.dart';

void main() {
  final created = DateTime(2026, 1, 1);

  group('TripChecklistItem', () {
    TripChecklistItem item({DateTime? dueDate, bool isDone = false}) =>
        TripChecklistItem(
          id: 'i1',
          tripId: 't1',
          title: 'Service regulator',
          dueDate: dueDate,
          isDone: isDone,
          createdAt: created,
          updatedAt: created,
        );

    test('isOverdue when due date passed and not done', () {
      final it = item(dueDate: DateTime(2026, 6, 1));
      expect(it.isOverdue(DateTime(2026, 6, 2)), isTrue);
    });

    test('not overdue when done, when due today, or when dateless', () {
      expect(
        item(
          dueDate: DateTime(2026, 6, 1),
          isDone: true,
        ).isOverdue(DateTime(2026, 6, 2)),
        isFalse,
      );
      expect(
        item(dueDate: DateTime(2026, 6, 2)).isOverdue(DateTime(2026, 6, 2, 18)),
        isFalse,
        reason: 'due today is not overdue (date-only comparison)',
      );
      expect(item().isOverdue(DateTime(2026, 6, 2)), isFalse);
    });

    test('copyWith can clear nullable fields via sentinel', () {
      final it = item(
        dueDate: DateTime(2026, 6, 1),
      ).copyWith(sectionId: 'sec1', notes: 'annual');
      expect(it.sectionId, 'sec1');
      final cleared = it.copyWith(dueDate: null, sectionId: null);
      expect(cleared.dueDate, isNull);
      expect(cleared.sectionId, isNull);
      expect(cleared.title, 'Service regulator');
    });

    test('equatable includes isDone', () {
      expect(item(), isNot(equals(item(isDone: true))));
    });
  });

  group('ChecklistTemplateItem', () {
    test('copyWith clears dueOffsetDays via sentinel', () {
      final it = ChecklistTemplateItem(
        id: 'x1',
        templateId: 'tpl1',
        title: 'Book flights',
        dueOffsetDays: 60,
        createdAt: created,
        updatedAt: created,
      );
      expect(it.copyWith(dueOffsetDays: null).dueOffsetDays, isNull);
      expect(it.copyWith(title: 'Book hotel').dueOffsetDays, 60);
    });

    test('equatable compares every field', () {
      ChecklistTemplateItem base() => ChecklistTemplateItem(
        id: 'x1',
        templateId: 'tpl1',
        title: 'Book flights',
        sectionId: 'sec1',
        notes: 'window seat',
        dueOffsetDays: 60,
        sortOrder: 2,
        createdAt: created,
        updatedAt: created,
      );
      expect(base(), equals(base()));
      expect(base(), isNot(equals(base().copyWith(title: 'Book hotel'))));
      expect(base(), isNot(equals(base().copyWith(sectionId: null))));
      expect(base(), isNot(equals(base().copyWith(notes: 'aisle seat'))));
      expect(base(), isNot(equals(base().copyWith(sortOrder: 3))));
    });
  });

  group('ChecklistTemplate', () {
    test('equatable and copyWith', () {
      final a = ChecklistTemplate(
        id: 'tpl1',
        name: 'Liveaboard packing',
        createdAt: created,
        updatedAt: created,
      );
      expect(a.copyWith(name: 'Resort packing'), isNot(equals(a)));
      expect(a.copyWith(description: 'd').id, 'tpl1');
    });
  });

  group('ChecklistTemplateSection', () {
    ChecklistTemplateSection section({int sortOrder = 0}) =>
        ChecklistTemplateSection(
          id: 's1',
          templateId: 'tpl1',
          title: 'Cells',
          sortOrder: sortOrder,
          createdAt: created,
          updatedAt: created,
        );

    test('equatable compares every field', () {
      expect(section(), equals(section()));
      expect(section(), isNot(equals(section().copyWith(title: 'Gas'))));
      expect(section(), isNot(equals(section(sortOrder: 1))));
    });

    test('copyWith keeps unspecified fields', () {
      final renamed = section().copyWith(title: 'O2 Cells');
      expect(renamed.title, 'O2 Cells');
      expect(renamed.id, 's1');
      expect(renamed.sortOrder, 0);
    });
  });

  group('TripChecklistSection', () {
    TripChecklistSection section({int sortOrder = 0}) => TripChecklistSection(
      id: 's1',
      tripId: 't1',
      title: 'Cells',
      sortOrder: sortOrder,
      createdAt: created,
      updatedAt: created,
    );

    test('equatable compares every field', () {
      expect(section(), equals(section()));
      expect(section(), isNot(equals(section().copyWith(title: 'Gas'))));
      expect(section(), isNot(equals(section(sortOrder: 1))));
    });

    test('copyWith keeps unspecified fields', () {
      final renamed = section().copyWith(title: 'O2 Cells');
      expect(renamed.title, 'O2 Cells');
      expect(renamed.id, 's1');
      expect(renamed.sortOrder, 0);
    });
  });
}
