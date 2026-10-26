import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// A fully loaded list that never changes, so nothing but the settings
/// themselves can make it rebuild.
class _StillPaginatedNotifier
    extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _StillPaginatedNotifier(List<DiveSummary> dives)
    : super(
        AsyncValue.data(PaginatedDiveListState(dives: dives, hasMore: false)),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('a new card gradient reaches the rows without waiting for the '
      'list to change (#3506)', (tester) async {
    final settings = MockSettingsNotifier();
    final base = await getBaseOverrides(settingsNotifier: settings);
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...base,
          diveListViewModeProvider.overrideWith((ref) => ListViewMode.compact),
          highlightedDiveIdProvider.overrideWith((ref) => null),
          paginatedDiveListProvider.overrideWith(
            (ref) => _StillPaginatedNotifier([
              for (var i = 5; i >= 1; i--)
                DiveSummary(
                  id: 'd$i',
                  diveNumber: i,
                  dateTime: DateTime(2024, 1, i),
                  maxDepth: 10.0 + i,
                  sortTimestamp: DateTime(2024, 1, i).millisecondsSinceEpoch,
                ),
            ]),
          ),
        ],
        child: const DiveListContent(showAppBar: true),
      ),
    );
    await tester.pumpAndSettle();

    // The list used to pick settings up only when some unrelated change
    // rebuilt it, and it no longer rebuilds while a page loads.
    await settings.setCardColorGradientCustom(0xFF112233, 0xFF445566);
    await tester.pumpAndSettle();

    final row = tester.widget<DiveListItem>(find.byType(DiveListItem).first);
    expect(row.gradientStartColor, const Color(0xFF112233));
    expect(row.gradientEndColor, const Color(0xFF445566));
  });
}
