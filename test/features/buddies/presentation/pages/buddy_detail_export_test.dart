import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_detail_page.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Records which UDDF delivery the buddy export chose.
class _RecordingExportService implements ExportService {
  final calls = <String>[];
  List<DiveSite>? sites;

  @override
  Future<String> exportDivesToUddf(
    List<Dive> dives, {
    List<DiveSite>? sites,
    Map<String, Map<String, List<TankPressurePoint>>>? diveTankPressures,
  }) async {
    this.sites = sites;
    calls.add('share:uddf');
    return '/tmp/shared.uddf';
  }

  @override
  Future<String?> saveDivesToUddfFile(
    List<Dive> dives, {
    List<DiveSite>? sites,
    Map<String, Map<String, List<TankPressurePoint>>>? diveTankPressures,
  }) async {
    this.sites = sites;
    calls.add('save:uddf');
    return '/tmp/saved.uddf';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDiveRepository implements DiveRepository {
  _FakeDiveRepository(this.dives);
  final List<Dive> dives;

  @override
  Future<Dive?> getDiveById(String id) async =>
      dives.where((d) => d.id == id).firstOrNull;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final buddy = Buddy(
    id: 'buddy-1',
    name: 'Jane Doe',
    notes: '',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final dives = [
    Dive(
      id: 'dive-1',
      dateTime: DateTime(2026, 2, 2, 9),
      entryTime: DateTime(2026, 2, 2, 9),
      site: const DiveSite(id: 'site-1', name: 'Blue Hole'),
    ),
  ];

  late _RecordingExportService exportService;

  setUp(() => exportService = _RecordingExportService());

  /// Pumps the buddy page at phone width and opens the Share Dives flow.
  Future<void> pumpAndOpenShareDives(WidgetTester tester) async {
    // Phone-width so the page renders standalone rather than redirecting to
    // the master-detail layout.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 1200);
    addTearDown(tester.view.reset);

    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/buddies/buddy-1',
      routes: [
        GoRoute(
          path: '/buddies/:id',
          builder: (context, state) =>
              BuddyDetailPage(buddyId: state.pathParameters['id']!),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          buddyListViewModeProvider.overrideWith(
            (ref) => ListViewMode.detailed,
          ),
          buddyByIdProvider(buddy.id).overrideWith((ref) async => buddy),
          buddyStatsProvider(
            buddy.id,
          ).overrideWith((ref) async => const BuddyStats(totalDives: 1)),
          diveIdsForBuddyProvider(
            buddy.id,
          ).overrideWith((ref) async => ['dive-1']),
          divesForBuddyProvider(buddy.id).overrideWith((ref) async => dives),
          diveRepositoryProvider.overrideWithValue(_FakeDiveRepository(dives)),
          exportServiceProvider.overrideWithValue(exportService),
        ].cast(),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share Dives'));
    await tester.pumpAndSettle();
  }

  testWidgets('share dives offers a save destination and uses it', (
    tester,
  ) async {
    await pumpAndOpenShareDives(tester);

    await tester.tap(find.text('Save to File'));
    await tester.pumpAndSettle();

    expect(exportService.calls, ['save:uddf']);
    expect(exportService.sites?.map((s) => s.id), ['site-1']);
  });

  testWidgets('share dives can still share', (tester) async {
    await pumpAndOpenShareDives(tester);

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(exportService.calls, ['share:uddf']);
  });

  testWidgets('dismissing the destination sheet exports nothing', (
    tester,
  ) async {
    await pumpAndOpenShareDives(tester);

    // Tap the scrim above the sheet.
    await tester.tapAt(const Offset(300, 60));
    await tester.pumpAndSettle();

    expect(exportService.calls, isEmpty);
  });
}
