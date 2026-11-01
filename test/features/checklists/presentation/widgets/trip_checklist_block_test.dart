import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist.dart'
    as domain;
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_section.dart'
    as section_domain;
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/checklists/presentation/widgets/trip_checklist_block.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_app.dart';

/// Split from trip_checklist_block_real_db_test.dart (which covers the same
/// widget against a real database) to keep both files under the project's
/// 800-line cap; this file covers rendering against stubbed providers.

Trip _trip({required bool upcoming}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = upcoming
      ? today.add(const Duration(days: 10))
      : today.subtract(const Duration(days: 20));
  return Trip(
    id: 't1',
    name: 'Test',
    startDate: start,
    endDate: start.add(const Duration(days: 7)),
    createdAt: today,
    updatedAt: today,
  );
}

domain.TripChecklist _checklist() => domain.TripChecklist(
  id: 'c1',
  tripId: 't1',
  name: 'Checklist',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

TripChecklistItem _item({
  String id = 'i1',
  String title = 'Service regulator',
  String? sectionId,
  bool isDone = false,
  DateTime? dueDate,
}) => TripChecklistItem(
  id: id,
  checklistId: 'c1',
  title: title,
  sectionId: sectionId,
  isDone: isDone,
  dueDate: dueDate,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

section_domain.TripChecklistSection _section({
  required String id,
  required String title,
  int sortOrder = 0,
}) => section_domain.TripChecklistSection(
  id: id,
  checklistId: 'c1',
  title: title,
  sortOrder: sortOrder,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// Every checklist starts collapsed (issue #3356); tapping its title
/// expands it, the same gesture `ExpansionTile` exposes natively.
Future<void> _expand(WidgetTester tester, {String title = 'Checklist'}) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  Widget pumpBlock({
    required bool upcoming,
    List<dynamic> overrides = const [],
  }) {
    return testApp(
      overrides: overrides,
      child: SingleChildScrollView(
        child: TripChecklistBlock(
          trip: _trip(upcoming: upcoming),
          checklist: _checklist(),
        ),
      ),
    );
  }

  testWidgets('starts collapsed: items are not shown until expanded', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpBlock(
        upcoming: true,
        overrides: [
          tripChecklistProvider('c1').overrideWith(
            (ref) async => [_item(id: 'i1', title: 'Service regulator')],
          ),
          tripChecklistSectionsProvider('c1').overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Service regulator'), findsNothing);
    await _expand(tester);
    expect(find.text('Service regulator'), findsOneWidget);
  });

  testWidgets('shows progress in the header whether expanded or not', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpBlock(
        upcoming: true,
        overrides: [
          tripChecklistProvider('c1').overrideWith(
            (ref) async => [_item(id: 'i1', isDone: true), _item(id: 'i2')],
          ),
          tripChecklistSectionsProvider('c1').overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 of 2 to-dos done'), findsOneWidget);
    await _expand(tester);
    expect(find.text('1 of 2 to-dos done'), findsOneWidget);
  });

  testWidgets('groups items by section and shows checkboxes', (tester) async {
    await tester.pumpWidget(
      pumpBlock(
        upcoming: true,
        overrides: [
          tripChecklistProvider('c1').overrideWith(
            (ref) async => [
              _item(id: 'i1', title: 'Service regulator', sectionId: 'gear'),
              _item(id: 'i2', title: 'Book flights', sectionId: 'bookings'),
              _item(id: 'i3', title: 'Passport check'),
            ],
          ),
          tripChecklistSectionsProvider('c1').overrideWith(
            (ref) async => [
              _section(id: 'gear', title: 'Gear'),
              _section(id: 'bookings', title: 'Bookings', sortOrder: 1),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await _expand(tester);

    expect(find.text('Gear'), findsOneWidget);
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('Service regulator'), findsOneWidget);
    expect(find.text('Passport check'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(3));
  });

  testWidgets(
    'an item whose sectionId is not in the loaded sections renders without '
    'throwing (#3360)',
    (tester) async {
      // Reachable under sync: a section's delete can apply before this
      // item's own sectionId update does, since the two sync as
      // independent HLC records with no guaranteed arrival order.
      await tester.pumpWidget(
        pumpBlock(
          upcoming: true,
          overrides: [
            tripChecklistProvider('c1').overrideWith(
              (ref) async => [
                _item(id: 'i1', title: 'Service regulator', sectionId: 'gone'),
              ],
            ),
            tripChecklistSectionsProvider('c1').overrideWith(
              (ref) async => [_section(id: 'gear', title: 'Gear')],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _expand(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Service regulator'), findsOneWidget);
    },
  );

  testWidgets('shows overdue chip only for upcoming trips', (tester) async {
    final overdue = _item(
      dueDate: DateTime.now().subtract(const Duration(days: 3)),
    );
    await tester.pumpWidget(
      pumpBlock(
        upcoming: true,
        overrides: [
          tripChecklistProvider('c1').overrideWith((ref) async => [overdue]),
          tripChecklistSectionsProvider('c1').overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await _expand(tester);
    expect(find.text('Overdue'), findsOneWidget);

    await tester.pumpWidget(
      pumpBlock(
        upcoming: false,
        overrides: [
          tripChecklistProvider('c1').overrideWith((ref) async => [overdue]),
          tripChecklistSectionsProvider('c1').overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await _expand(tester);
    expect(find.text('Overdue'), findsNothing);
  });

  testWidgets('empty upcoming trip shows planning invitation', (tester) async {
    await tester.pumpWidget(
      pumpBlock(
        upcoming: true,
        overrides: [
          tripChecklistProvider('c1').overrideWith((ref) async => []),
          tripChecklistSectionsProvider('c1').overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await _expand(tester);
    expect(
      find.text('Plan your trip - add to-dos or apply a template'),
      findsOneWidget,
    );
  });

  testWidgets('a brand new checklist still offers "+ Add section" alongside '
      'the planning invitation', (tester) async {
    await tester.pumpWidget(
      pumpBlock(
        upcoming: true,
        overrides: [
          tripChecklistProvider('c1').overrideWith((ref) async => []),
          tripChecklistSectionsProvider('c1').overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await _expand(tester);

    expect(
      find.text('Plan your trip - add to-dos or apply a template'),
      findsOneWidget,
    );
    // The only way to create the feature's "empty section laid out in
    // advance" case is this button; a checklist with no items and no
    // sections yet must not hide it behind the empty-state message (issue
    // #3360).
    expect(find.text('Add section'), findsOneWidget);
  });

  testWidgets('a sections-provider failure shows the error, not a spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpBlock(
        upcoming: true,
        overrides: [
          tripChecklistProvider('c1').overrideWith((ref) async => []),
          tripChecklistSectionsProvider(
            'c1',
          ).overrideWith((ref) => Future.error('section load boom')),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await _expand(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('section load boom'), findsOneWidget);
  });

  testWidgets('sections render in their own sort order, not item order', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpBlock(
        upcoming: true,
        overrides: [
          tripChecklistProvider('c1').overrideWith(
            (ref) async => [
              // The first item in the list belongs to the section sorted
              // second, so a correct render still shows Bookings first.
              _item(id: 'i1', title: 'Pack fins', sectionId: 'diving'),
              _item(id: 'i2', title: 'Book flights', sectionId: 'bookings'),
            ],
          ),
          tripChecklistSectionsProvider('c1').overrideWith(
            (ref) async => [
              _section(id: 'bookings', title: 'Bookings'),
              _section(id: 'diving', title: 'Diving', sortOrder: 1),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await _expand(tester);

    final bookingsHeader = tester.getTopLeft(find.text('Bookings'));
    final divingHeader = tester.getTopLeft(find.text('Diving'));
    expect(bookingsHeader.dy, lessThan(divingHeader.dy));
  });
}
