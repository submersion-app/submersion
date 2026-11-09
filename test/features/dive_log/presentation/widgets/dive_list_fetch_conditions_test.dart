import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weather/data/services/bulk_conditions_service.dart';
import 'package:submersion/features/weather/data/services/weather_service.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
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

/// Records the dives each call is scoped to, and answers with [candidates]
/// without touching the database or the network.
class _RecordingService extends BulkConditionsService {
  _RecordingService({required this.candidates})
    : super(
        diveRepository: DiveRepository(),
        weatherService: WeatherService(
          client: MockClient((_) async => http.Response('{}', 500)),
        ),
      );

  final int candidates;
  final scopes = <Set<String>?>[];

  @override
  Future<int> countCandidates({String? diverId, Set<String>? diveIds}) async {
    scopes.add(diveIds);
    return candidates;
  }

  @override
  Future<int> countWithoutLocation({
    String? diverId,
    Set<String>? diveIds,
  }) async => 0;

  @override
  Future<int> countLogged(Set<String> diveIds) async => diveIds.length;

  @override
  Future<BulkConditionsResult> run({
    String? diverId,
    Set<String>? diveIds,
    void Function(BulkConditionsProgress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    scopes.add(diveIds);
    return BulkConditionsResult(
      filled: candidates,
      unavailable: 0,
      unchanged: 0,
      total: candidates,
      cancelled: false,
    );
  }
}

/// "Fetch Conditions" in the dive list's selection bar fetches weather for
/// the checked dives only (issue #4329).
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  Future<void> pumpList(
    WidgetTester tester,
    BulkConditionsService service,
  ) async {
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
    final router = GoRouter(
      initialLocation: '/dives',
      routes: [
        GoRoute(
          path: '/dives',
          builder: (_, _) =>
              const Scaffold(body: DiveListContent(showAppBar: false)),
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
          bulkConditionsServiceProvider.overrideWithValue(service),
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
    await tester.tap(tile('d3'));
    await tester.pumpAndSettle();
  }

  Future<void> invokeFetch(WidgetTester tester) async {
    final inline = find.byKey(
      const ValueKey('selection_action_fetch_conditions'),
    );
    if (inline.evaluate().isNotEmpty) {
      await tester.tap(inline);
    } else {
      await tester.tap(find.byKey(const ValueKey('selection_overflow')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fetch Conditions'));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('scopes the fetch to the checked dives and keeps the selection '
      'when there is nothing to do', (tester) async {
    final service = _RecordingService(candidates: 0);
    await pumpList(tester, service);

    await invokeFetch(tester);

    expect(service.scopes, [
      {'d1', 'd3'},
    ]);
    expect(
      find.text('None of the selected dives are missing conditions.'),
      findsOneWidget,
    );
    expect(find.text('2 selected'), findsOneWidget);
  });

  testWidgets('a completed fetch ends selection mode', (tester) async {
    final service = _RecordingService(candidates: 2);
    await pumpList(tester, service);

    await invokeFetch(tester);
    expect(find.text('Fetch conditions?'), findsOneWidget);
    await tester.tap(find.text('Fetch'));
    await tester.pumpAndSettle();
    expect(find.text('Conditions fetched'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(service.scopes, [
      {'d1', 'd3'},
      {'d1', 'd3'},
    ]);
    expect(find.text('2 selected'), findsNothing);
  });
}
