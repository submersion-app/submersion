import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/services/trip_draft.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/select_items_menu.dart';
import '../../../../helpers/test_database.dart';

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

/// "New Trip from Selection" on the dive list opens the new-trip form with
/// a draft built from the checked dives (issue #3658).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO dive_sites (id, name, region, country, created_at, "
      "updated_at) VALUES ('s1', 'Cape Kri', 'Raja Ampat', 'Indonesia', 0, 0)",
    );
    for (final (id, day) in [('d1', 8), ('d2', 9), ('d3', 12)]) {
      await db.customStatement(
        'INSERT INTO dives (id, dive_date_time, site_id, created_at, '
        'updated_at) VALUES (?, ?, ?, 0, 0)',
        [id, DateTime.utc(2026, 3, day, 9).millisecondsSinceEpoch, 's1'],
      );
    }
  });
  tearDown(tearDownTestDatabase);

  testWidgets('the checked dives become the new trip draft', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final summaries = [
      for (final (id, day) in [('d1', 8), ('d2', 9), ('d3', 12)])
        DiveSummary.fromDive(
          Dive(id: id, dateTime: DateTime.utc(2026, 3, day, 9)),
        ),
    ];
    final base = await getBaseOverrides();
    TripDraft? opened;
    final router = GoRouter(
      initialLocation: '/dives',
      routes: [
        GoRoute(
          path: '/dives',
          builder: (_, _) =>
              const Scaffold(body: DiveListContent(showAppBar: false)),
        ),
        GoRoute(
          path: '/trips/new',
          builder: (_, state) {
            opened = state.extra as TripDraft?;
            return const Scaffold(body: Text('NEW TRIP'));
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
          paginatedDiveListProvider.overrideWith(
            (ref) => _MockPaginatedNotifier(summaries),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder tile(String id) =>
        find.byWidgetPredicate((w) => w is DiveListTile && w.diveId == id);
    await enterSelectionViaMenu(tester);
    await tester.tap(tile('d1'));
    await tester.pumpAndSettle();
    await tester.tap(tile('d2'));
    await tester.pumpAndSettle();

    final inline = find.byKey(const ValueKey('selection_action_new_trip'));
    if (inline.evaluate().isNotEmpty) {
      await tester.tap(inline);
    } else {
      await tester.tap(find.byKey(const ValueKey('selection_overflow')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Trip from Selection'));
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    expect(find.text('NEW TRIP'), findsOneWidget);
    expect(opened!.diveIds, unorderedEquals(['d1', 'd2']));
    expect(opened!.trip.location, 'Raja Ampat, Indonesia');
    expect(opened!.trip.startDate, DateTime(2026, 3, 8));
    expect(opened!.trip.endDate, DateTime(2026, 3, 9));
    expect(opened!.trip.name, 'Raja Ampat, Indonesia, Mar 2026');
  });
}
