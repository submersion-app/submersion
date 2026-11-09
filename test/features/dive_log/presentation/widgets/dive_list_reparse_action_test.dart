import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_batch_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/select_items_menu.dart';
import '../../../../helpers/test_app.dart';

class _MockPaginatedNotifier
    extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _MockPaginatedNotifier(List<DiveSummary> dives)
    : super(
        AsyncValue.data(PaginatedDiveListState(dives: dives, hasMore: false)),
      );

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadNextPage() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Says no checked dive has raw data, so invoking the action ends in its
/// snackbar without a database.
class _NoRawDataBatch implements ReparseBatchService {
  final asked = <List<String>>[];

  @override
  Future<List<String>> withRawData(List<String> diveIds) async {
    asked.add(diveIds);
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Finder _tile(String id) =>
    find.byWidgetPredicate((w) => w is DiveListTile && w.diveId == id);

void main() {
  late _NoRawDataBatch batch;

  Future<void> pumpWithSelection(
    WidgetTester tester, {
    required bool canParse,
  }) async {
    batch = _NoRawDataBatch();
    final dt = DateTime(2026, 1, 1, 9);
    final summaries = [
      for (final id in ['d1', 'd2'])
        DiveSummary.fromDive(Dive(id: id, dateTime: dt, entryTime: dt)),
    ];
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...base,
          diveListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
          paginatedDiveListProvider.overrideWith(
            (ref) => _MockPaginatedNotifier(summaries),
          ),
          deviceCapabilitiesProvider.overrideWithValue(
            DeviceCapabilities.web.copyWith(diveComputerDownload: canParse),
          ),
          reparseBatchServiceProvider.overrideWithValue(batch),
        ],
        child: const DiveListContent(showAppBar: false),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    await enterSelectionViaMenu(tester);
    await tester.tap(_tile('d1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }

  testWidgets('the selection bar offers Re-parse and acts on the checked '
      'dives', (tester) async {
    await pumpWithSelection(tester, canParse: true);

    expect(find.text('Re-parse'), findsOneWidget);
    await tester.tap(find.text('Re-parse'));
    await tester.pumpAndSettle();

    expect(batch.asked, [
      ['d1'],
    ]);
    expect(
      find.text('None of the selected dives have stored raw data to re-parse.'),
      findsOneWidget,
    );
  });

  testWidgets('Re-parse is absent where the dive parser is unavailable', (
    tester,
  ) async {
    await pumpWithSelection(tester, canParse: false);

    expect(find.text('Re-parse'), findsNothing);
  });
}
