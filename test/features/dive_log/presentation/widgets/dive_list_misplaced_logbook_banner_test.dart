import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/domain/misplaced_logbook.dart';
import 'package:submersion/features/divers/presentation/providers/misplaced_logbook_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The misplaced-logbook banner (#3549) belongs where the diver notices
/// their dives are missing: the Dives list, in both list and table modes.
class _EmptyPaginatedNotifier
    extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _EmptyPaginatedNotifier()
    : super(
        const AsyncValue.data(
          PaginatedDiveListState(dives: [], hasMore: false),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Diver _diver(String id, String name) => Diver(
  id: id,
  name: name,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  Future<Widget> buildContent(ListViewMode mode) async {
    final base = await getBaseOverrides();
    return testApp(
      locale: const Locale('en'),
      overrides: [
        ...base,
        diveListViewModeProvider.overrideWith((ref) => mode),
        paginatedDiveListProvider.overrideWith(
          (ref) => _EmptyPaginatedNotifier(),
        ),
        allDivesForTableProvider.overrideWithValue(
          const AsyncValue<List<Dive>>.data([]),
        ),
        misplacedLogbookProvider.overrideWith(
          (ref) async => MisplacedLogbook(
            active: _diver('empty', 'iPhone Diver'),
            target: _diver('main', 'Dave'),
            targetDiveCount: 212,
            canMerge: true,
          ),
        ),
      ],
      child: const DiveListContent(showAppBar: false),
    );
  }

  for (final mode in [ListViewMode.compact, ListViewMode.table]) {
    testWidgets('shows the banner above the dives in ${mode.name} mode', (
      tester,
    ) async {
      await tester.pumpWidget(await buildContent(mode));
      await tester.pumpAndSettle();

      expect(find.text('Your dives are in another diver profile'), findsOne);
    });
  }
}
