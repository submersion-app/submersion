import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The advanced query's chips in the active-filter bar (#2365): one per
/// top-level AND child, printed in the diver's units, each removing exactly
/// its child.
class _MockPaginatedNotifier
    extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _MockPaginatedNotifier(List<DiveSummary> dives)
    : super(
        AsyncValue.data(PaginatedDiveListState(dives: dives, hasMore: false)),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<Widget> buildContent(
    DiveFilterState filter, {
    MockSettingsNotifier? settings,
  }) async {
    final summaries = [
      DiveSummary.fromDive(
        Dive(id: 'd1', dateTime: DateTime(2026, 3, 15), diveNumber: 1),
      ),
    ];
    final base = await getBaseOverrides(settingsNotifier: settings);

    return testApp(
      locale: const Locale('en'),
      overrides: [
        ...base,
        diveListViewModeProvider.overrideWith((ref) => ListViewMode.compact),
        diveFilterProvider.overrideWith((ref) => filter),
        paginatedDiveListProvider.overrideWith(
          (ref) => _MockPaginatedNotifier(summaries),
        ),
      ],
      child: const DiveListContent(showAppBar: false),
    );
  }

  final query = AndNode([
    ConditionNode(
      FieldPath(['depth']),
      QueryOp.gt,
      const NumberValue(30, null),
    ),
    ConditionNode(FieldPath(['weights']), QueryOp.isEmpty, null),
  ]);

  testWidgets('each top-level AND child renders its own chip', (tester) async {
    await tester.pumpWidget(await buildContent(DiveFilterState(query: query)));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Chip, 'depth > 30'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'weights:none'), findsOneWidget);
  });

  testWidgets('the chip prints in the current unit setting', (tester) async {
    // The seed stores 30 m; under feet the chip must read it in feet, so a
    // chip never claims a strictness the filter does not apply.
    await tester.pumpWidget(
      await buildContent(
        DiveFilterState(query: query),
        settings: MockSettingsNotifier(
          const AppSettings(depthUnit: DepthUnit.feet),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Chip, 'depth > 98.4252'), findsOneWidget);
  });

  testWidgets('deleting a chip removes only its child', (tester) async {
    await tester.pumpWidget(await buildContent(DiveFilterState(query: query)));
    await tester.pumpAndSettle();
    final chip = find.widgetWithText(Chip, 'depth > 30');
    await tester.tap(
      find.descendant(of: chip, matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();
    expect(chip, findsNothing);
    expect(find.widgetWithText(Chip, 'weights:none'), findsOneWidget);
  });
}
