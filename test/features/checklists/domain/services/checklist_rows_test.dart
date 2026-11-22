import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template_section.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_section.dart';
import 'package:submersion/features/checklists/domain/services/checklist_rows.dart';

/// The rows a template adds to a checklist, worked out without the
/// database, so a trip's editing sitting adds what the repository would.
void main() {
  final at = DateTime(2026);
  var next = 0;
  String newId() => 'n${next++}';

  setUp(() => next = 0);

  ChecklistTemplateItem templateItem(
    String title, {
    String? sectionId,
    int? offset,
  }) => ChecklistTemplateItem(
    id: title,
    templateId: 'tp',
    title: title,
    sectionId: sectionId,
    dueOffsetDays: offset,
    createdAt: at,
    updatedAt: at,
  );

  final bookings = ChecklistTemplateSection(
    id: 'ts1',
    templateId: 'tp',
    title: ' Bookings ',
    createdAt: at,
    updatedAt: at,
  );

  test('nextSortOrder is one past the highest, not the count', () {
    expect(nextSortOrder(const []), 0);
    expect(nextSortOrder(const [0, 4]), 5);
  });

  test('template rows date items from the given start', () {
    final rows = checklistRowsFromTemplate(
      templateItems: [
        templateItem('Book flights', sectionId: 'ts1', offset: 60),
        templateItem('Pack'),
      ],
      templateSections: [bookings],
      checklistId: 'c1',
      tripStart: DateTime(2030, 6, 1, 14),
      existingItems: const [],
      existingSections: const [],
      newId: newId,
      now: at,
    );

    expect(rows.added, 2);
    expect(rows.skipped, 0);
    expect(rows.sections.single.title, 'Bookings');
    final flights = rows.items.first;
    expect(flights.sectionId, rows.sections.single.id);
    expect(flights.dueDate, DateTime(2030, 4, 2));
    expect(rows.items.last.dueDate, isNull);
    expect([for (final i in rows.items) i.sortOrder], [0, 1]);
  });

  test('rows already on the checklist are skipped, and a matched section is '
      'reused case-insensitively', () {
    final section = TripChecklistSection(
      id: 's1',
      checklistId: 'c1',
      title: 'bookings',
      sortOrder: 3,
      createdAt: at,
      updatedAt: at,
    );
    final rows = checklistRowsFromTemplate(
      templateItems: [
        templateItem('Book flights', sectionId: 'ts1'),
        templateItem('Book hotel', sectionId: 'ts1'),
      ],
      templateSections: [bookings],
      checklistId: 'c1',
      tripStart: DateTime(2030, 6, 1),
      existingItems: [
        TripChecklistItem(
          id: 'i1',
          checklistId: 'c1',
          title: 'Book flights',
          sectionId: 's1',
          sortOrder: 7,
          createdAt: at,
          updatedAt: at,
        ),
      ],
      existingSections: [section],
      newId: newId,
      now: at,
    );

    expect(rows.skipped, 1);
    expect(rows.sections, isEmpty);
    expect(rows.items.single.title, 'Book hotel');
    expect(rows.items.single.sectionId, 's1');
    expect(rows.items.single.sortOrder, 8);
  });

  test('reorderedSortOrders keeps the values held, or positions on a tie', () {
    expect(reorderedSortOrders([5, 0, 2]), [0, 2, 5]);
    expect(reorderedSortOrders([1, 1, 4]), [0, 1, 2]);
  });
}
