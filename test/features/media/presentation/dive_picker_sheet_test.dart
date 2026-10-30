import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_search.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_picker_row.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/dive_picker_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

typedef _Request = ({
  String? diverId,
  String query,
  DiveSummaryCursor? cursor,
  int limit,
});

/// A logbook the sheet can only reach a page at a time: it has no
/// `getAllDives`, so a sheet that reads the whole logbook fails here.
class _FakeDiveRepo implements DiveRepository {
  _FakeDiveRepo([List<DivePickerRow>? rows]) : rows = [...(rows ?? _twoDives)];

  final List<DivePickerRow> rows;
  final requests = <_Request>[];

  /// Answers for the searches named here wait for their completer.
  final held = <String, Completer<void>>{};

  /// Consulted before each request, so a test can fail a chosen one.
  bool Function(_Request request) failWhen = (_) => false;

  @override
  Future<List<DivePickerRow>> getDivePickerRows({
    String? diverId,
    String query = '',
    DiveSummaryCursor? cursor,
    int limit = kDivePickerPageSize,
  }) async {
    final request = (
      diverId: diverId,
      query: query,
      cursor: cursor,
      limit: limit,
    );
    requests.add(request);
    await held[query]?.future;
    if (failWhen(request)) throw StateError('read failed');
    final matching = rows.where(
      (r) => (r.name ?? '').toLowerCase().contains(query.toLowerCase()),
    );
    final after = cursor == null
        ? matching
        : matching.skipWhile((r) => r.id != cursor.id).skip(1);
    return after.take(limit).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DivePickerRow _row(String id, {int? number, String? name, String? site}) =>
    DivePickerRow(
      id: id,
      diveNumber: number,
      name: name,
      siteName: site,
      dateTime: DateTime.utc(2026, 6, 12),
      sortTimestamp: DateTime.utc(2026, 6, 12).millisecondsSinceEpoch,
    );

final _twoDives = [
  _row('dive-2', number: 2, name: 'Night dive'),
  _row('dive-1', number: 1),
];

List<DivePickerRow> _logbook(int count) => [
  for (var i = count; i > 0; i--) _row('dive-$i', number: i, name: 'Dive $i'),
];

class _FixedDiverIdNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _FixedDiverIdNotifier() : super('d1');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget host({
    required Future<void> Function(BuildContext) onPressed,
    _FakeDiveRepo? repo,
    String Function()? validatedDiver,
  }) {
    return ProviderScope(
      overrides: [
        diveRepositoryProvider.overrideWithValue(repo ?? _FakeDiveRepo()),
        // The raw id names diver d1; the validated one (what every scoped
        // read uses) has fallen back to the default diver.
        currentDiverIdProvider.overrideWith((ref) => _FixedDiverIdNotifier()),
        validatedCurrentDiverIdProvider.overrideWith(
          (ref) async => validatedDiver?.call() ?? 'default',
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => onPressed(context),
              child: const Text('OPEN'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester, _FakeDiveRepo repo) async {
    await tester.pumpWidget(
      host(onPressed: (context) => showDivePickerSheet(context), repo: repo),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(kDiveSearchDebounce);
    await tester.pumpAndSettle();
  }

  Future<void> scrollToEnd(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, -6000));
    await tester.pumpAndSettle();
  }

  testWidgets('lists the validated diver\'s dives', (tester) async {
    // The raw id can name a deleted diver. The picker must list the dives
    // of the diver every other scoped read uses, or a check-in saved under
    // that diver could never pick one of them.
    final repo = _FakeDiveRepo();
    await open(tester, repo);
    expect(repo.requests.map((r) => r.diverId), ['default']);
  });

  testWidgets('reopening after a diver switch lists the new diver', (
    tester,
  ) async {
    var diver = 'first';
    final repo = _FakeDiveRepo();
    await tester.pumpWidget(
      host(
        onPressed: (context) => showDivePickerSheet(context),
        repo: repo,
        validatedDiver: () => diver,
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(400, 20)); // barrier dismiss
    await tester.pumpAndSettle();

    diver = 'second';
    ProviderScope.containerOf(
      tester.element(find.text('OPEN')),
    ).invalidate(validatedCurrentDiverIdProvider);
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(repo.requests.map((r) => r.diverId), ['first', 'second']);
  });

  testWidgets('lists dives, filters by search, returns the tapped dive id', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      host(
        onPressed: (context) async {
          picked = await showDivePickerSheet(context);
        },
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.textContaining('#1'), findsOneWidget);
    expect(find.textContaining('#2'), findsOneWidget);

    await search(tester, 'night');
    expect(find.textContaining('#1'), findsNothing);
    expect(find.textContaining('#2'), findsOneWidget);

    await tester.tap(find.textContaining('#2'));
    await tester.pumpAndSettle();
    expect(picked, 'dive-2');
  });

  testWidgets('shows the site for a dive with no name', (tester) async {
    await open(
      tester,
      _FakeDiveRepo([_row('d', number: 7, site: 'Blue Hole')]),
    );
    expect(find.text('#7 Blue Hole'), findsOneWidget);
  });

  testWidgets('dismissing resolves null', (tester) async {
    String? picked = 'sentinel';
    await tester.pumpWidget(
      host(
        onPressed: (context) async {
          picked = await showDivePickerSheet(context);
        },
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(400, 20)); // barrier dismiss
    await tester.pumpAndSettle();
    expect(picked, isNull);
  });

  group('paging', () {
    testWidgets('opening reads a single page however long the logbook is', (
      tester,
    ) async {
      final repo = _FakeDiveRepo(_logbook(500));
      await open(tester, repo);

      expect(repo.requests, hasLength(1));
      expect(repo.requests.single.limit, kDivePickerPageSize);
      expect(repo.requests.single.cursor, isNull);
    });

    testWidgets('scrolling near the end loads the next page after the last', (
      tester,
    ) async {
      final repo = _FakeDiveRepo(_logbook(120));
      await open(tester, repo);

      await scrollToEnd(tester);

      expect(repo.requests[1].cursor, repo.rows[49].cursor);
      expect(repo.requests[1].diverId, 'default');
    });

    testWidgets('an old dive can be reached by scrolling back to it', (
      tester,
    ) async {
      final repo = _FakeDiveRepo(_logbook(120));
      await open(tester, repo);

      for (var i = 0; i < 6; i++) {
        await scrollToEnd(tester);
      }

      expect(find.text('#1 Dive 1'), findsOneWidget);
    });

    testWidgets('a last page shorter than a full one ends the list', (
      tester,
    ) async {
      final repo = _FakeDiveRepo(_logbook(60));
      await open(tester, repo);

      await scrollToEnd(tester);
      await scrollToEnd(tester);
      await scrollToEnd(tester);

      expect(repo.requests, hasLength(2));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a search pages with its own term', (tester) async {
      final repo = _FakeDiveRepo(_logbook(120));
      await open(tester, repo);

      await search(tester, 'dive');
      await scrollToEnd(tester);

      expect(repo.requests.last.query, 'dive');
      expect(repo.requests.last.cursor, isNotNull);
    });
  });

  group('search', () {
    testWidgets('a burst of typing runs one search, for the final text', (
      tester,
    ) async {
      final repo = _FakeDiveRepo();
      await open(tester, repo);

      await tester.enterText(find.byType(TextField), 'n');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'ni');
      await tester.pump(const Duration(milliseconds: 100));
      await search(tester, 'nig');

      expect(repo.requests.map((r) => r.query), ['', 'nig']);
    });

    testWidgets('a space added to the term runs no new search', (tester) async {
      final repo = _FakeDiveRepo();
      await open(tester, repo);

      await search(tester, 'night');
      await search(tester, 'night ');

      expect(repo.requests.map((r) => r.query), ['', 'night']);
    });

    testWidgets('the rows stay until the search answers', (tester) async {
      final repo = _FakeDiveRepo();
      final answer = Completer<void>();
      repo.held['night'] = answer;
      await open(tester, repo);

      await tester.enterText(find.byType(TextField), 'night');
      await tester.pump(kDiveSearchDebounce);
      await tester.pump();

      expect(find.textContaining('#1'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      answer.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('#1'), findsNothing);
    });

    testWidgets('an older search answering late changes nothing', (
      tester,
    ) async {
      final repo = _FakeDiveRepo();
      final slow = Completer<void>();
      repo.held['dive'] = slow;
      await open(tester, repo);

      await tester.enterText(find.byType(TextField), 'dive');
      await tester.pump(kDiveSearchDebounce);
      await search(tester, 'night');
      expect(find.textContaining('#2'), findsOneWidget);

      // Clearing the logbook makes the stale answer empty, so taking it
      // would drop the row the newer search found.
      repo.rows.clear();
      slow.complete();
      await tester.pumpAndSettle();

      expect(find.textContaining('#2'), findsOneWidget);
    });

    testWidgets('a page still loading is dropped when the search changes', (
      tester,
    ) async {
      final repo = _FakeDiveRepo(_logbook(120));
      final slow = Completer<void>();
      await open(tester, repo);
      repo.held[''] = slow;

      await tester.drag(find.byType(ListView), const Offset(0, -6000));
      await tester.pump();
      await search(tester, 'Dive 120');
      expect(find.text('#120 Dive 120'), findsOneWidget);

      slow.complete();
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsOneWidget);
    });

    testWidgets('old rows keep their scroll position until the answer', (
      tester,
    ) async {
      final repo = _FakeDiveRepo(_logbook(120));
      final answer = Completer<void>();
      repo.held['Dive 1'] = answer;
      await open(tester, repo);
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Dive 1');
      await tester.pump(kDiveSearchDebounce);
      await tester.pump();

      expect(find.text('#120 Dive 120'), findsNothing);

      answer.complete();
      await tester.pumpAndSettle();
      expect(find.text('#120 Dive 120'), findsOneWidget);
    });

    testWidgets('a new search starts from the top of the list', (tester) async {
      final repo = _FakeDiveRepo(_logbook(120));
      await open(tester, repo);
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      await search(tester, 'dive');

      expect(find.text('#120 Dive 120'), findsOneWidget);
    });

    testWidgets('closing the sheet mid-debounce runs no search', (
      tester,
    ) async {
      final repo = _FakeDiveRepo();
      await open(tester, repo);

      await tester.enterText(find.byType(TextField), 'night');
      await tester.tapAt(const Offset(400, 20)); // barrier dismiss
      // Past the sheet's exit animation, and short of the debounce.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);

      await tester.pump(kDiveSearchDebounce);
      expect(repo.requests, hasLength(1));
    });
  });

  group('nothing to show', () {
    testWidgets('an empty logbook says so', (tester) async {
      await open(tester, _FakeDiveRepo(const []));
      expect(find.text('No dives to link to'), findsOneWidget);
    });

    testWidgets('clearing a search with no matches never claims no dives', (
      tester,
    ) async {
      final repo = _FakeDiveRepo();
      await open(tester, repo);
      await search(tester, 'zzz');

      final answer = Completer<void>();
      repo.held[''] = answer;
      await tester.enterText(find.byType(TextField), '');
      await tester.pump(kDiveSearchDebounce);
      await tester.pump();

      expect(find.text('No dives to link to'), findsNothing);

      answer.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('#2'), findsOneWidget);
    });

    testWidgets('a search with no matches names the term', (tester) async {
      await open(tester, _FakeDiveRepo());
      await search(tester, 'zzz');
      expect(find.text('No dives match "zzz"'), findsOneWidget);
    });
  });

  group('a failed read', () {
    const message = 'Something went wrong. Please try again.';

    testWidgets('on opening offers a retry that loads the list', (
      tester,
    ) async {
      final repo = _FakeDiveRepo();
      repo.failWhen = (_) => true;
      await open(tester, repo);

      expect(find.text(message), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      repo.failWhen = (_) => false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text(message), findsNothing);
      expect(find.textContaining('#2'), findsOneWidget);
    });

    testWidgets('on a later page keeps the rows and retries that page', (
      tester,
    ) async {
      final repo = _FakeDiveRepo(_logbook(120));
      repo.failWhen = (r) => r.cursor != null;
      await open(tester, repo);

      await scrollToEnd(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -6000));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(ListTile), findsWidgets);
      // Failing again on every scroll would hammer a broken read.
      final attempts = repo.requests.length;
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(repo.requests, hasLength(attempts));

      repo.failWhen = (_) => false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsNothing);
      expect(repo.requests.last.cursor, repo.rows[49].cursor);
    });

    testWidgets('on a search does not leave the old rows under the term', (
      tester,
    ) async {
      final repo = _FakeDiveRepo();
      await open(tester, repo);
      repo.failWhen = (r) => r.query == 'night';

      await search(tester, 'night');

      expect(find.text(message), findsOneWidget);
      expect(find.textContaining('#1'), findsNothing);

      repo.failWhen = (_) => false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.textContaining('#2'), findsOneWidget);
      expect(find.textContaining('#1'), findsNothing);
    });
  });
}
