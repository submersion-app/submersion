import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The active-filter bar's no-buddy chip (#639). Rendering the chip is one
/// thing; its delete affordance is a separate closure that has to write
/// `clearNoBuddyOnly` back to the filter, or the diver is stuck with a filter
/// they cannot see a way out of.
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
  Future<Widget> buildContent(DiveFilterState filter) async {
    final summaries = [
      DiveSummary.fromDive(
        Dive(id: 'd1', dateTime: DateTime(2026, 3, 15), diveNumber: 1),
      ),
    ];
    final base = await getBaseOverrides();

    return testApp(
      // Pinned: this suite finds the chip by its English label.
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

  testWidgets('an active no-buddy filter renders its chip', (tester) async {
    await tester.pumpWidget(
      await buildContent(const DiveFilterState(noBuddyOnly: true)),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Chip, 'No Buddy'), findsOneWidget);
  });

  testWidgets('no chip is shown when the filter is not set', (tester) async {
    await tester.pumpWidget(await buildContent(const DiveFilterState()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Chip, 'No Buddy'), findsNothing);
  });

  testWidgets('deleting the chip clears the filter', (tester) async {
    await tester.pumpWidget(
      await buildContent(const DiveFilterState(noBuddyOnly: true)),
    );
    await tester.pumpAndSettle();

    final chip = find.widgetWithText(Chip, 'No Buddy');
    await tester.tap(
      find.descendant(of: chip, matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();

    // The bar rebuilds off diveFilterProvider, so the chip going away is the
    // observable proof that clearNoBuddyOnly reached the filter state.
    expect(chip, findsNothing);
  });
}
