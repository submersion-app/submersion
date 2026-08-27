import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Minimal export service for the navigator tests: every delivery succeeds.
class _StubExportService implements ExportService {
  final calls = <String>[];

  @override
  Future<String> exportDivesToCsv(List<Dive> dives) async {
    calls.add('share:csv');
    return '/tmp/shared_csv';
  }

  @override
  Future<String?> saveDivesCsvToFile(List<Dive> dives) async {
    calls.add('save:csv');
    return '/tmp/saved_csv';
  }

  @override
  Future<String> exportDivesToUddf(
    List<Dive> dives, {
    List<DiveSite>? sites,
    Map<String, Map<String, List<TankPressurePoint>>>? diveTankPressures,
  }) async {
    calls.add('share:uddf');
    return '/tmp/shared_uddf';
  }

  @override
  Future<String?> saveDivesToUddfFile(
    List<Dive> dives, {
    List<DiveSite>? sites,
    Map<String, Map<String, List<TankPressurePoint>>>? diveTankPressures,
  }) async {
    calls.add('save:uddf');
    return '/tmp/saved_uddf';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fails the export so the catch branch is exercised too.
class _ThrowingExportService extends _StubExportService {
  @override
  Future<String> exportDivesToUddf(
    List<Dive> dives, {
    List<DiveSite>? sites,
    Map<String, Map<String, List<TankPressurePoint>>>? diveTankPressures,
  }) async {
    calls.add('share:uddf');
    throw StateError('disk full');
  }
}

void main() {
  late _StubExportService exportService;
  late Dive dive;

  setUp(() {
    exportService = _StubExportService();
    final dt = DateTime(2026, 3, 4, 10);
    dive = Dive(
      id: 'dive-1',
      dateTime: dt,
      entryTime: dt,
      diveNumber: 7,
      site: const DiveSite(id: 'site-1', name: 'Blue Hole'),
    );
  });

  /// Hosts the detail page inside a *nested* navigator holding a single route.
  ///
  /// This is the master-detail (tablet) shape the app really uses: the
  /// `ShellRoute` in `app_router.dart` declares no `navigatorKey`, so GoRouter
  /// builds its own navigator for the shell, and on a >=1100pt viewport
  /// `DiveDetailPage(embedded: true)` renders inside the shell's single
  /// `/dives` route rather than on a pushed route of its own.
  ///
  /// The distinction matters because `showDialog` defaults to
  /// `useRootNavigator: true`. Popping the progress dialog with a bare
  /// `Navigator.of(context)` therefore targets the *shell* navigator, not the
  /// one holding the dialog, and removes the shell's only route. The sibling
  /// harness in `dive_detail_export_test.dart` puts the page directly under
  /// `MaterialApp.home`, where the local and root navigators are the same
  /// object, so it cannot observe this.
  Future<GlobalKey<NavigatorState>> pumpEmbeddedInShell(
    WidgetTester tester,
  ) async {
    final base = await getBaseOverrides();
    final shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      testAppInShell(
        navigatorKey: shellKey,
        // Pinned so the English menu and dialog labels this test taps do not
        // depend on the host machine's locale, which flutter_test forwards.
        locale: const Locale('en'),
        overrides: [
          ...base,
          diveProvider(dive.id).overrideWith((ref) async => dive),
          diveDataSourcesProvider(
            dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
          exportServiceProvider.overrideWithValue(exportService),
        ],
        child: DiveDetailPage(diveId: dive.id, embedded: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    return shellKey;
  }

  Future<void> exportAs(
    WidgetTester tester,
    String format,
    String destination,
  ) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(format));
    await tester.pumpAndSettle();
    await tester.tap(find.text(destination));
    // Deliberately not pumpAndSettle: when the bug is present the progress
    // dialog is never dismissed and its spinner animates forever, so settling
    // would time out instead of reporting the assertion that actually matters.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('sharing UDDF leaves the master-detail pane on screen', (
    tester,
  ) async {
    await pumpEmbeddedInShell(tester);

    await exportAs(tester, 'UDDF', 'Share');

    expect(exportService.calls, ['share:uddf']);
    expect(find.text('Exporting...'), findsNothing);
    // The regression: the progress dialog was popped off the shell navigator
    // instead of the root one, tearing the detail pane out of the tree and
    // leaving a black screen.
    expect(find.byType(DiveDetailPage), findsOneWidget);
  });

  testWidgets('sharing CSV leaves the master-detail pane on screen', (
    tester,
  ) async {
    await pumpEmbeddedInShell(tester);

    await exportAs(tester, 'CSV', 'Share');

    expect(exportService.calls, ['share:csv']);
    expect(find.byType(DiveDetailPage), findsOneWidget);
  });

  testWidgets('a failed share leaves the master-detail pane on screen', (
    tester,
  ) async {
    exportService = _ThrowingExportService();
    await pumpEmbeddedInShell(tester);

    await exportAs(tester, 'UDDF', 'Share');

    expect(find.text('Exporting...'), findsNothing);
    expect(find.byType(DiveDetailPage), findsOneWidget);
  });

  testWidgets('the shell navigator keeps its only route after an export', (
    tester,
  ) async {
    final shellKey = await pumpEmbeddedInShell(tester);

    await exportAs(tester, 'UDDF', 'Share');

    // canPop() is false either way; what matters is that a route is still
    // mounted. An emptied navigator renders nothing at all.
    expect(shellKey.currentState!.mounted, isTrue);
    expect(find.byType(DiveDetailPage), findsOneWidget);
  });
}
