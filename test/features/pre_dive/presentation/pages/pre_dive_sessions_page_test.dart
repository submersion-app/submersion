import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/excel/pre_dive_excel_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_session_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/domain/services/checklist_session_engine.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_sessions_page.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';

import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Captures what the page handed the exporter, without writing any file.
class _RecordingExcelExporter extends PreDiveExcelExportService {
  List<PreDiveSession>? sharedSessions;
  List<PreDiveSession>? savedSessions;

  @override
  Future<String> exportToExcel({
    required List<PreDiveSession> sessions,
    required Map<String, List<PreDiveSessionItem>> itemsBySession,
    required DateFormatPreference dateFormat,
  }) async {
    sharedSessions = sessions;
    return '/tmp/checklists.xlsx';
  }

  @override
  Future<String?> saveToFile({
    required List<PreDiveSession> sessions,
    required Map<String, List<PreDiveSessionItem>> itemsBySession,
    required DateFormatPreference dateFormat,
  }) async {
    savedSessions = sessions;
    return '/tmp/checklists.xlsx';
  }
}

/// Serves the bulk item fetch without a database, and records which runs the
/// page asked for plus any dive-link writes it made.
class _StubSessionRepository implements PreDiveSessionRepository {
  /// Current dive link per session, seeded from the same fixtures the page
  /// renders. The real query reads stored state, so a fake built only from
  /// this test's own writes would answer differently for a run that arrived
  /// already linked.
  final Map<String, String?> _diveIdBySession;

  _StubSessionRepository({List<PreDiveSession> seed = const []})
    : _diveIdBySession = {
        for (final session in seed) session.id: session.diveId,
      };

  List<String>? requestedIds;

  /// Every link write in order. A null diveId is an unlink.
  final List<({String sessionId, String? diveId})> linkWrites = [];

  @override
  Future<Map<String, List<PreDiveSessionItem>>> getItemsForSessions(
    List<String> sessionIds,
  ) async {
    requestedIds = sessionIds;
    return {for (final id in sessionIds) id: const []};
  }

  /// No writes reach this fake from outside the test, so the tick the link
  /// providers subscribe to never has anything to report.
  @override
  Stream<void> watchSessionsChanges() => const Stream.empty();

  /// Current links only, matching the real query. Folding [linkWrites]
  /// instead would keep reporting a dive as taken after it was unlinked.
  @override
  Future<Set<String>> getLinkedDiveIds() async => {
    for (final diveId in _diveIdBySession.values) ?diveId,
  };

  @override
  Future<void> linkToDive(String sessionId, String diveId) async {
    linkWrites.add((sessionId: sessionId, diveId: diveId));
    _diveIdBySession[sessionId] = diveId;
  }

  @override
  Future<void> unlinkFromDive(String sessionId) async {
    linkWrites.add((sessionId: sessionId, diveId: null));
    _diveIdBySession[sessionId] = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  PreDiveSession session(
    String id, {
    String name = 'CCR Build',
    PreDiveSessionStatus status = PreDiveSessionStatus.inProgress,
    String? diveId,
  }) => PreDiveSession(
    id: id,
    templateName: name,
    status: status,
    diveId: diveId,
    startedAt: now,
    createdAt: now,
    updatedAt: now,
  );

  PreDiveSessionItem item(
    String sessionId,
    int order,
    PreDiveItemState state,
  ) => PreDiveSessionItem(
    id: '$sessionId-i$order',
    sessionId: sessionId,
    title: 'Item $order',
    sortOrder: order,
    state: state,
    createdAt: now,
    updatedAt: now,
  );

  // Overrides the per-session items family for each id so the real
  // repository-backed provider never runs during a widget test.
  List<dynamic> itemOverridesFor(Map<String, List<PreDiveSessionItem>> byId) =>
      [
        for (final entry in byId.entries)
          preDiveSessionItemsProvider(
            entry.key,
          ).overrideWith((ref) async => entry.value),
      ];

  // The page reads tallies from the aggregate stats provider. Deriving them
  // from the same item fixtures (via the same engine the repository query
  // mirrors) keeps these tests asserting computed counts rather than numbers
  // typed into the override.
  dynamic statsOverrideFor(Map<String, List<PreDiveSessionItem>> byId) =>
      preDiveSessionStatsProvider.overrideWith(
        (ref) async => {
          for (final entry in byId.entries)
            entry.key: PreDiveSessionStats(
              total: entry.value.length,
              resolved: ChecklistSessionEngine.resolvedCount(entry.value),
              flagged: ChecklistSessionEngine.flaggedCount(entry.value),
            ),
        },
      );

  Future<void> pumpPage(
    WidgetTester tester, {
    PreDiveSession? active,
    required List<PreDiveSession> sessions,
    Map<String, List<PreDiveSessionItem>> items = const {},
    Locale locale = const Locale('en'),
    List<dynamic> extraOverrides = const [],
  }) async {
    await tester.pumpWidget(
      testApp(
        locale: locale,
        overrides: [
          preDiveActiveSessionProvider.overrideWith((ref) async => active),
          preDiveSessionsProvider.overrideWith((ref) async => sessions),
          statsOverrideFor(items),
          ...itemOverridesFor(items),
          ...extraOverrides,
        ],
        child: const PreDiveSessionsPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders title and start FAB', (tester) async {
    await pumpPage(tester, sessions: []);

    expect(find.text('Pre-Dive Checklists'), findsOneWidget);
    expect(find.text('Start checklist'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('empty state renders when no active and no history', (
    tester,
  ) async {
    await pumpPage(tester, sessions: []);

    expect(find.text('No checklist runs yet'), findsOneWidget);
  });

  testWidgets('active session card shows name, progress and Resume', (
    tester,
  ) async {
    final s = session('s1', name: 'Deep Air Check');
    await pumpPage(
      tester,
      active: s,
      sessions: [s],
      items: {
        's1': [
          item('s1', 0, PreDiveItemState.done),
          item('s1', 1, PreDiveItemState.pending),
          item('s1', 2, PreDiveItemState.pending),
        ],
      },
    );

    expect(find.text('Deep Air Check'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    // Empty state must not show when an active session is pinned.
    expect(find.text('No checklist runs yet'), findsNothing);
  });

  testWidgets('history tiles render for completed and aborted sessions', (
    tester,
  ) async {
    await pumpPage(
      tester,
      sessions: [
        session(
          'done1',
          name: 'Reef Dive',
          status: PreDiveSessionStatus.completed,
        ),
        session(
          'ab1',
          name: 'Wreck Dive',
          status: PreDiveSessionStatus.aborted,
        ),
      ],
      items: {
        'done1': [item('done1', 0, PreDiveItemState.done)],
        'ab1': [item('ab1', 0, PreDiveItemState.skipped)],
      },
    );

    expect(find.text('Reef Dive'), findsOneWidget);
    expect(find.text('Wreck Dive'), findsOneWidget);
    expect(find.textContaining('Completed'), findsOneWidget);
    expect(find.textContaining('Aborted'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2));
  });

  testWidgets('in-progress history tile shows pending icon and status', (
    tester,
  ) async {
    // A session that is in-progress but not the active one still renders in
    // history and exercises the inProgress branch of both switches.
    await pumpPage(
      tester,
      sessions: [
        session(
          'ip1',
          name: 'Solo Check',
          status: PreDiveSessionStatus.inProgress,
        ),
      ],
      items: {
        'ip1': [item('ip1', 0, PreDiveItemState.pending)],
      },
    );

    expect(find.text('Solo Check'), findsOneWidget);
    expect(find.textContaining('In progress'), findsOneWidget);
    expect(find.byIcon(Icons.pending_outlined), findsOneWidget);
  });

  testWidgets('flagged badge appears when items are flagged', (tester) async {
    await pumpPage(
      tester,
      sessions: [
        session(
          'f1',
          name: 'Cave Check',
          status: PreDiveSessionStatus.completed,
        ),
      ],
      items: {
        'f1': [
          item('f1', 0, PreDiveItemState.done),
          item('f1', 1, PreDiveItemState.flagged),
        ],
      },
    );

    expect(find.textContaining('1 flagged'), findsOneWidget);
  });

  testWidgets('linked dive chip renders when session has a diveId', (
    tester,
  ) async {
    await pumpPage(
      tester,
      sessions: [
        session(
          'l1',
          name: 'Boat Dive',
          status: PreDiveSessionStatus.completed,
          diveId: 'dive-42',
        ),
      ],
      items: {
        'l1': [item('l1', 0, PreDiveItemState.done)],
      },
    );

    expect(find.text('Linked dive'), findsOneWidget);
    expect(find.byType(ActionChip), findsOneWidget);
    expect(find.byIcon(Icons.scuba_diving), findsOneWidget);
  });

  testWidgets(
    'session title keeps its width on a narrow phone in German (#935)',
    (tester) async {
      // The German "Verknuepfter Tauchgang" chip is far wider than the English
      // "Linked dive". A ListTile measures its trailing widget against the full
      // tile width first, so anything wide there starves the title column and
      // the name degrades to one glyph per line.
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const longName = 'CCR rEvo - Modifiziert';
      await pumpPage(
        tester,
        locale: const Locale('de'),
        sessions: [
          session(
            'w1',
            name: longName,
            status: PreDiveSessionStatus.completed,
            diveId: 'dive-42',
          ),
        ],
        items: {
          'w1': [item('w1', 0, PreDiveItemState.done)],
        },
      );

      final titleSize = tester.getSize(find.text(longName));

      expect(
        titleSize.width,
        greaterThan(150),
        reason:
            'Title collapsed to ${titleSize.width}px wide on a 360px screen; '
            'the linked-dive chip is starving the ListTile text column.',
      );
    },
  );

  group('filtering', () {
    Future<void> pumpTwoChecklists(WidgetTester tester) => pumpPage(
      tester,
      sessions: [
        session('a', name: 'CCR Build', status: PreDiveSessionStatus.completed),
        session('b', name: 'BWRAF', status: PreDiveSessionStatus.aborted),
      ],
      items: {
        'a': [item('a', 0, PreDiveItemState.flagged)],
        'b': [item('b', 0, PreDiveItemState.done)],
      },
    );

    testWidgets('filter icon opens the filter sheet', (tester) async {
      await pumpTwoChecklists(tester);

      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();

      expect(find.text('Filter checklist runs'), findsOneWidget);
      // Checklist names are offered from the runs actually present.
      expect(find.widgetWithText(FilterChip, 'CCR Build'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'BWRAF'), findsOneWidget);
    });

    testWidgets('applying a checklist filter hides the other runs', (
      tester,
    ) async {
      await pumpTwoChecklists(tester);
      expect(find.text('BWRAF'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'CCR Build'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Scoped to the list rows: the active-filter bar also renders the
      // selected checklist name as a chip.
      expect(find.widgetWithText(ListTile, 'CCR Build'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'BWRAF'), findsNothing);
    });

    testWidgets('dismissing the active filter chip restores the full list', (
      tester,
    ) async {
      await pumpTwoChecklists(tester);
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'CCR Build'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'BWRAF'), findsNothing);

      // The bar chip carries the facet name and a close affordance.
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'BWRAF'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'CCR Build'), findsOneWidget);
    });

    testWidgets('filtered empty state appears when nothing matches', (
      tester,
    ) async {
      await pumpPage(
        tester,
        sessions: [
          session(
            'a',
            name: 'CCR Build',
            status: PreDiveSessionStatus.completed,
          ),
        ],
        items: {
          'a': [item('a', 0, PreDiveItemState.done)],
        },
      );

      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();
      // The switch sits below the sheet's initial fold.
      await tester.scrollUntilVisible(
        find.text('Flagged runs only'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      // No run has a flagged item, so this filter matches nothing.
      await tester.tap(find.text('Flagged runs only'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(
        find.text('No checklist runs match these filters'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.filter_list_off), findsOneWidget);
      // The unfiltered empty copy must not be shown: runs do exist.
      expect(find.text('No checklist runs yet'), findsNothing);
    });

    testWidgets('an in-progress run stays pinned while a filter is active', (
      tester,
    ) async {
      final active = session(
        'live',
        name: 'CCR Build',
        status: PreDiveSessionStatus.inProgress,
      );
      await pumpPage(
        tester,
        active: active,
        sessions: [
          active,
          session('old', name: 'BWRAF', status: PreDiveSessionStatus.completed),
        ],
        items: {
          'live': [item('live', 0, PreDiveItemState.pending)],
          'old': [item('old', 0, PreDiveItemState.done)],
        },
      );

      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'BWRAF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Filtering to a different checklist must not strand the running one.
      expect(find.text('Resume'), findsOneWidget);
    });
  });

  group('export', () {
    testWidgets('exports the filtered set, not the whole history', (
      tester,
    ) async {
      final exporter = _RecordingExcelExporter();
      final repo = _StubSessionRepository();

      await pumpPage(
        tester,
        sessions: [
          session(
            'a',
            name: 'CCR Build',
            status: PreDiveSessionStatus.completed,
          ),
          session('b', name: 'BWRAF', status: PreDiveSessionStatus.completed),
        ],
        items: {
          'a': [item('a', 0, PreDiveItemState.done)],
          'b': [item('b', 0, PreDiveItemState.done)],
        },
        extraOverrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          preDiveExcelExportServiceProvider.overrideWithValue(exporter),
          preDiveSessionRepositoryProvider.overrideWithValue(repo),
        ],
      );

      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'CCR Build'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.grid_on));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      // The filter doubles as the export selector.
      expect(exporter.sharedSessions?.map((s) => s.templateName).toList(), [
        'CCR Build',
      ]);
      // Item rows were fetched in one bulk call for exactly those runs.
      expect(repo.requestedIds, ['a']);
    });

    testWidgets('choosing Save routes to the save path, not share', (
      tester,
    ) async {
      final exporter = _RecordingExcelExporter();

      await pumpPage(
        tester,
        sessions: [
          session(
            'a',
            name: 'CCR Build',
            status: PreDiveSessionStatus.completed,
          ),
        ],
        items: {
          'a': [item('a', 0, PreDiveItemState.done)],
        },
        extraOverrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          preDiveExcelExportServiceProvider.overrideWithValue(exporter),
          preDiveSessionRepositoryProvider.overrideWithValue(
            _StubSessionRepository(),
          ),
        ],
      );

      await tester.tap(find.byIcon(Icons.grid_on));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save to File'));
      await tester.pumpAndSettle();

      expect(exporter.savedSessions, isNotNull);
      expect(exporter.sharedSessions, isNull);
    });

    testWidgets('export action is disabled while sessions are still loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            preDiveActiveSessionProvider.overrideWith((ref) async => null),
            // Never completes: holds the provider in its loading state.
            preDiveSessionsProvider.overrideWith(
              (ref) => Completer<List<PreDiveSession>>().future,
            ),
          ],
          child: const PreDiveSessionsPage(),
        ),
      );
      await tester.pump();

      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.grid_on),
          matching: find.byType(IconButton),
        ),
      );

      // A pending load must not be reported as "nothing to export".
      expect(button.onPressed, isNull);
    });

    testWidgets('exporting an empty list reports it instead of writing', (
      tester,
    ) async {
      final exporter = _RecordingExcelExporter();

      await pumpPage(
        tester,
        sessions: [],
        extraOverrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          preDiveExcelExportServiceProvider.overrideWithValue(exporter),
        ],
      );

      await tester.tap(find.byIcon(Icons.grid_on));
      await tester.pumpAndSettle();

      expect(find.text('No checklist runs to export'), findsOneWidget);
      expect(exporter.sharedSessions, isNull);
      expect(exporter.savedSessions, isNull);
    });
  });

  testWidgets('loading spinner shows while sessions are pending', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          preDiveActiveSessionProvider.overrideWith((ref) async => null),
          // Never completes: keeps the provider in a loading state.
          preDiveSessionsProvider.overrideWith(
            (ref) => Completer<List<PreDiveSession>>().future,
          ),
        ],
        child: const PreDiveSessionsPage(),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error text shows when sessions provider fails', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          preDiveActiveSessionProvider.overrideWith((ref) async => null),
          preDiveSessionsProvider.overrideWith(
            (ref) async => throw StateError('boom-loading'),
          ),
        ],
        child: const PreDiveSessionsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('boom-loading'), findsOneWidget);
  });

  testWidgets('delete menu opens confirm dialog and Cancel dismisses it', (
    tester,
  ) async {
    await pumpPage(
      tester,
      sessions: [
        session(
          'd1',
          name: 'Night Dive',
          status: PreDiveSessionStatus.completed,
        ),
      ],
      items: {
        'd1': [item('d1', 0, PreDiveItemState.done)],
      },
    );

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Confirmation dialog is shown with its body copy.
    expect(find.text('Delete this checklist record?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Dialog dismissed; no repository call made.
    expect(find.text('Delete this checklist record?'), findsNothing);
  });

  group('manual dive linking (#1066)', () {
    DiveSummary diveSummary(String id, {int? number, String? site}) {
      final at = DateTime(2026, 8, 14, 9, 30);
      return DiveSummary(
        id: id,
        diveNumber: number,
        dateTime: at,
        siteName: site,
        sortTimestamp: at.millisecondsSinceEpoch,
      );
    }

    /// Pumps one completed run and returns the repository stub so the test can
    /// assert on the link write the menu actually made.
    Future<_StubSessionRepository> pumpOneRun(
      WidgetTester tester, {
      String? diveId,
      List<DiveSummary> candidates = const [],
    }) async {
      final run = session(
        's1',
        name: 'CCR Build',
        status: PreDiveSessionStatus.completed,
        diveId: diveId,
      );
      final repo = _StubSessionRepository(seed: [run]);
      await pumpPage(
        tester,
        sessions: [run],
        items: {
          's1': [item('s1', 0, PreDiveItemState.done)],
        },
        extraOverrides: [
          preDiveSessionRepositoryProvider.overrideWithValue(repo),
          preDiveLinkCandidateDivesProvider.overrideWith(
            (ref) async => candidates,
          ),
        ],
      );
      return repo;
    }

    testWidgets('an unlinked run offers Link to dive', (tester) async {
      await pumpOneRun(tester);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Link to dive'), findsOneWidget);
      expect(find.text('Unlink dive'), findsNothing);
    });

    testWidgets('a run already linked offers Unlink dive instead', (
      tester,
    ) async {
      await pumpOneRun(tester, diveId: 'dive-42');

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Unlink dive'), findsOneWidget);
      expect(find.text('Link to dive'), findsNothing);
    });

    testWidgets('picking a dive writes the link', (tester) async {
      final repo = await pumpOneRun(
        tester,
        candidates: [diveSummary('dive-42', number: 42, site: 'Blue Hole')],
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Link to dive'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Blue Hole'));
      await tester.pumpAndSettle();

      expect(repo.linkWrites, [(sessionId: 's1', diveId: 'dive-42')]);
    });

    testWidgets('cancelling the picker writes nothing', (tester) async {
      final repo = await pumpOneRun(
        tester,
        candidates: [diveSummary('dive-42', number: 42, site: 'Blue Hole')],
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Link to dive'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.linkWrites, isEmpty);
    });

    testWidgets('Unlink dive clears the link', (tester) async {
      final repo = await pumpOneRun(tester, diveId: 'dive-42');

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unlink dive'));
      await tester.pumpAndSettle();

      expect(repo.linkWrites, [(sessionId: 's1', diveId: null)]);
    });

    testWidgets('the excluded set tracks current links, not link history', (
      tester,
    ) async {
      // A dive spoken for by another run must not be offered, and unlinking
      // that run must hand the dive back. Both directions matter: the picker
      // is the only thing standing between a hand-made link and the
      // one-run-per-dive rule ChecklistDiveLinker enforces.
      final taken = session(
        'taken',
        name: 'Reef Check',
        status: PreDiveSessionStatus.completed,
        diveId: 'dive-42',
      );
      final free = session(
        'free',
        name: 'CCR Build',
        status: PreDiveSessionStatus.completed,
      );
      final repo = _StubSessionRepository(seed: [taken, free]);

      await pumpPage(
        tester,
        sessions: [taken, free],
        items: {
          'taken': [item('taken', 0, PreDiveItemState.done)],
          'free': [item('free', 0, PreDiveItemState.done)],
        },
        extraOverrides: [
          preDiveSessionRepositoryProvider.overrideWithValue(repo),
          preDiveLinkCandidateDivesProvider.overrideWith(
            (ref) async => [
              diveSummary('dive-42', number: 42, site: 'Blue Hole'),
              diveSummary('dive-7', number: 7, site: 'Ginnie Springs'),
            ],
          ),
        ],
      );

      Future<void> openMenuFor(String name) async {
        await tester.tap(
          find.descendant(
            of: find.widgetWithText(ListTile, name),
            matching: find.byType(PopupMenuButton<String>),
          ),
        );
        await tester.pumpAndSettle();
      }

      // Blue Hole belongs to the Reef Check run, so it is not on offer.
      await openMenuFor('CCR Build');
      await tester.tap(find.text('Link to dive'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Blue Hole'), findsNothing);
      expect(find.textContaining('Ginnie Springs'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Release it.
      await openMenuFor('Reef Check');
      await tester.tap(find.text('Unlink dive'));
      await tester.pumpAndSettle();

      // Now it is claimable again.
      await openMenuFor('CCR Build');
      await tester.tap(find.text('Link to dive'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Blue Hole'), findsOneWidget);
    });
  });

  testWidgets('tapping Resume navigates to the session runner route', (
    tester,
  ) async {
    final s = session('r1', name: 'Resume Me');
    final router = GoRouter(
      initialLocation: '/pre-dive-sessions',
      routes: [
        GoRoute(
          path: '/pre-dive-sessions',
          builder: (context, state) => const PreDiveSessionsPage(),
        ),
        GoRoute(
          path: '/pre-dive-sessions/:id',
          builder: (context, state) =>
              Scaffold(body: Text('runner-${state.pathParameters['id']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      testAppRouter(
        router: router,
        overrides: [
          preDiveActiveSessionProvider.overrideWith((ref) async => s),
          preDiveSessionsProvider.overrideWith((ref) async => [s]),
          preDiveSessionItemsProvider('r1').overrideWith(
            (ref) async => [item('r1', 0, PreDiveItemState.pending)],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(find.text('runner-r1'), findsOneWidget);
  });
}
