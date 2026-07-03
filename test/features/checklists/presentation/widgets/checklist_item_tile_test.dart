import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/presentation/widgets/checklist_item_tile.dart';

import '../../../../helpers/test_app.dart';

TripChecklistItem _item({
  String title = 'Service regulator',
  bool isDone = false,
  String notes = '',
  DateTime? dueDate,
}) => TripChecklistItem(
  id: 'i1',
  tripId: 't1',
  title: title,
  isDone: isDone,
  notes: notes,
  dueDate: dueDate,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  testWidgets('tapping the checkbox invokes onToggle with the new value', (
    tester,
  ) async {
    bool? toggledTo;
    await tester.pumpWidget(
      testApp(
        child: ChecklistItemTile(
          item: _item(),
          showOverdue: true,
          onToggle: (value) => toggledTo = value,
        ),
      ),
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(toggledTo, isTrue);
  });

  testWidgets('a done item renders its title with strikethrough styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        child: ChecklistItemTile(
          item: _item(isDone: true),
          showOverdue: true,
          onToggle: (_) {},
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('Service regulator'));
    expect(text.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('shows notes as a subtitle when present', (tester) async {
    await tester.pumpWidget(
      testApp(
        child: ChecklistItemTile(
          item: _item(notes: 'bring backup mask'),
          showOverdue: true,
          onToggle: (_) {},
        ),
      ),
    );

    expect(find.text('bring backup mask'), findsOneWidget);
  });

  testWidgets('omits the subtitle when notes are empty', (tester) async {
    await tester.pumpWidget(
      testApp(
        child: ChecklistItemTile(
          item: _item(),
          showOverdue: true,
          onToggle: (_) {},
        ),
      ),
    );

    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.subtitle, isNull);
  });

  testWidgets('selecting edit from the overflow menu invokes onEdit', (
    tester,
  ) async {
    var edited = false;
    await tester.pumpWidget(
      testApp(
        child: ChecklistItemTile(
          item: _item(),
          showOverdue: true,
          onToggle: (_) {},
          onEdit: () => edited = true,
        ),
      ),
    );

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit item'));
    await tester.pumpAndSettle();

    expect(edited, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting delete from the overflow menu invokes onDelete', (
    tester,
  ) async {
    var deleted = false;
    await tester.pumpWidget(
      testApp(
        child: ChecklistItemTile(
          item: _item(),
          showOverdue: true,
          onToggle: (_) {},
          onDelete: () => deleted = true,
        ),
      ),
    );

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete item'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an overdue chip when the due date has passed', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        child: ChecklistItemTile(
          item: _item(
            dueDate: DateTime.now().subtract(const Duration(days: 3)),
          ),
          showOverdue: true,
          onToggle: (_) {},
        ),
      ),
    );

    expect(find.text('Overdue'), findsOneWidget);
  });

  testWidgets('shows the formatted due date chip when not overdue', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        child: ChecklistItemTile(
          item: _item(dueDate: DateTime(2026, 8, 1)),
          showOverdue: false,
          onToggle: (_) {},
        ),
      ),
    );

    expect(find.text('Overdue'), findsNothing);
    expect(find.textContaining('Aug 1'), findsOneWidget);
  });
}
