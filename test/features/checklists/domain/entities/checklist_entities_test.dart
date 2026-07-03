import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';

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
      ).copyWith(category: 'Gear', notes: 'annual');
      expect(it.category, 'Gear');
      final cleared = it.copyWith(dueDate: null, category: null);
      expect(cleared.dueDate, isNull);
      expect(cleared.category, isNull);
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
        category: 'Bookings',
        notes: 'window seat',
        dueOffsetDays: 60,
        sortOrder: 2,
        createdAt: created,
        updatedAt: created,
      );
      expect(base(), equals(base()));
      expect(base(), isNot(equals(base().copyWith(title: 'Book hotel'))));
      expect(base(), isNot(equals(base().copyWith(category: null))));
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
}
