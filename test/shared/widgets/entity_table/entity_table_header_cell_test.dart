import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_header_cell.dart';

import '../../../helpers/test_app.dart';

// ---------------------------------------------------------------------------
// Minimal EntityField implementation for testing
// ---------------------------------------------------------------------------

class _TestField implements EntityField {
  static const sortableField = _TestField._(
    name: 'sortableField',
    displayName: 'Sortable Field',
    shortLabel: 'Sort',
    sortable: true,
  );
  static const nonSortableField = _TestField._(
    name: 'nonSortableField',
    displayName: 'Non-Sortable Field',
    shortLabel: 'NoSort',
    sortable: false,
  );

  @override
  final String name;
  @override
  final String displayName;
  @override
  final String shortLabel;
  @override
  final bool sortable;

  const _TestField._({
    required this.name,
    required this.displayName,
    required this.shortLabel,
    required this.sortable,
  });

  @override
  IconData? get icon => null;
  @override
  double get defaultWidth => 120;
  @override
  double get minWidth => 60;
  @override
  String get categoryName => 'test';
  @override
  bool get isRightAligned => false;

  @override
  bool operator ==(Object other) => other is _TestField && other.name == name;
  @override
  int get hashCode => name.hashCode;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildHeaderCell({
  _TestField field = _TestField.sortableField,
  double width = 120,
  bool isSorted = false,
  bool sortAscending = true,
  VoidCallback? onTap,
  ValueChanged<double>? onResize,
  bool showResizeHandle = true,
}) {
  return testApp(
    child: Row(
      children: [
        EntityTableHeaderCell(
          field: field,
          width: width,
          isSorted: isSorted,
          sortAscending: sortAscending,
          onTap: onTap,
          onResize: onResize,
          showResizeHandle: showResizeHandle,
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EntityTableHeaderCell', () {
    testWidgets('renders shortLabel text', (tester) async {
      await tester.pumpWidget(_buildHeaderCell());
      await tester.pumpAndSettle();

      expect(find.text('Sort'), findsOneWidget);
    });

    testWidgets(
      'shows ascending sort indicator when field is sorted ascending',
      (tester) async {
        await tester.pumpWidget(
          _buildHeaderCell(isSorted: true, sortAscending: true),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
        expect(find.byIcon(Icons.arrow_downward), findsNothing);
      },
    );

    testWidgets(
      'shows descending sort indicator when field is sorted descending',
      (tester) async {
        await tester.pumpWidget(
          _buildHeaderCell(isSorted: true, sortAscending: false),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
        expect(find.byIcon(Icons.arrow_upward), findsNothing);
      },
    );

    testWidgets('no sort indicator when field does not match sort', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHeaderCell(isSorted: false));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });

    testWidgets('tapping calls onTap callback for sortable field', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(_buildHeaderCell(onTap: () => tapped = true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sort'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('drag handle for column resizing triggers onResize', (
      tester,
    ) async {
      double? resizedWidth;

      await tester.pumpWidget(
        _buildHeaderCell(width: 120, onResize: (w) => resizedWidth = w),
      );
      await tester.pumpAndSettle();

      // The resize handle is a MouseRegion with resizeColumn cursor placed at
      // the right edge of the cell. Find it by cursor type.
      final resizeHandleFinder = find.byWidgetPredicate(
        (widget) =>
            widget is MouseRegion &&
            widget.cursor == SystemMouseCursors.resizeColumn,
      );
      expect(resizeHandleFinder, findsOneWidget);

      // Perform a horizontal drag on the resize handle
      await tester.drag(resizeHandleFinder, const Offset(20, 0));
      await tester.pumpAndSettle();

      // onResize should have been called with a value close to 120 + 20 = 140
      expect(resizedWidth, isNotNull);
    });

    testWidgets('non-sortable fields do not fire onTap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _buildHeaderCell(
          field: _TestField.nonSortableField,
          onTap: () => tapped = true,
        ),
      );
      await tester.pumpAndSettle();

      // The InkWell should have onTap == null for non-sortable fields
      await tester.tap(find.text('NoSort'));
      await tester.pumpAndSettle();

      expect(tapped, isFalse);
    });

    testWidgets('non-sortable field renders shortLabel correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHeaderCell(field: _TestField.nonSortableField),
      );
      await tester.pumpAndSettle();

      expect(find.text('NoSort'), findsOneWidget);
    });
  });
}
