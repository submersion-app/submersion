import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart' as enums;
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_table_view.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

class _FixedTableConfigNotifier extends TableViewConfigNotifier {
  _FixedTableConfigNotifier(TableViewConfig config) {
    state = config;
  }
}

/// Sorting the dive table by a column whose values differ in kind (issue
/// #2444). Visibility extracts a measured distance for newer dives and the
/// legacy bucket label for pre-v144 ones; sorting by it threw
/// `String is not a subtype of num` inside the table's build, which a release
/// build draws as a grey box in place of the whole table. The sort is saved
/// per diver, so the table stayed grey on every visit.
void main() {
  // #1 measured 8 m, #2 bucket-only, #3 measured 3 m, #4 no visibility.
  final dives = [
    Dive(
      id: 'm8',
      diveNumber: 1,
      dateTime: DateTime(2024, 6, 1),
      visibilityMeters: 8.0,
    ),
    Dive(
      id: 'poor',
      diveNumber: 2,
      dateTime: DateTime(2024, 6, 2),
      visibility: enums.Visibility.poor,
    ),
    Dive(
      id: 'm3',
      diveNumber: 3,
      dateTime: DateTime(2024, 6, 3),
      visibilityMeters: 3.0,
    ),
    Dive(id: 'none', diveNumber: 4, dateTime: DateTime(2024, 6, 4)),
  ];

  Widget buildTable(TableViewConfig config) {
    return testApp(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        tableViewConfigProvider.overrideWith(
          (ref) => _FixedTableConfigNotifier(config),
        ),
      ],
      child: Column(
        children: [
          Expanded(
            child: DiveTableView(
              dives: dives,
              diveTypeLabelResolver: Dive.diveTypeDisplayName,
              onDiveTap: (_) {},
            ),
          ),
        ],
      ),
    );
  }

  TableViewConfig sortedBy(DiveField field, {required bool ascending}) {
    return TableViewConfig(
      columns: [
        TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
        TableColumnConfig(field: field),
      ],
      sortField: field,
      sortAscending: ascending,
    );
  }

  /// The dive numbers top to bottom, as the table lays the rows out.
  List<String> rowOrder(WidgetTester tester) {
    final rows = [
      for (final dive in dives)
        (
          label: '#${dive.diveNumber}',
          y: tester.getTopLeft(find.text('#${dive.diveNumber}')).dy,
        ),
    ]..sort((a, b) => a.y.compareTo(b.y));
    return rows.map((r) => r.label).toList();
  }

  testWidgets('sorting by Visibility with mixed values renders the rows, '
      'measured dives first in order, then bucket-only, empty last', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTable(sortedBy(DiveField.visibility, ascending: true)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // 3 m, 8 m, the Poor bucket, then the dive with no visibility.
    expect(rowOrder(tester), ['#3', '#1', '#2', '#4']);
  });

  testWidgets('descending Visibility reverses the groups but keeps empty '
      'last', (tester) async {
    await tester.pumpWidget(
      buildTable(sortedBy(DiveField.visibility, ascending: false)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The Poor bucket, 8 m, 3 m, then the dive with no visibility.
    expect(rowOrder(tester), ['#2', '#1', '#3', '#4']);
  });

  // A guard for every column, so a field that starts extracting mixed kinds
  // later cannot grey out the table again.
  for (final field in DiveField.values) {
    for (final ascending in [true, false]) {
      testWidgets('sorting by ${field.name} '
          '(${ascending ? 'asc' : 'desc'}) never throws', (tester) async {
        await tester.pumpWidget(
          buildTable(sortedBy(field, ascending: ascending)),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(DiveTableView), findsOneWidget);
      });
    }
  }
}
