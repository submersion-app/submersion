import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_session_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Issue #1066: PR #913 removed the dive-detail pre-dive card, and with it the
/// only way to attach a checklist run completed the night before to the dive
/// it was run for. The overflow menu carries that affordance now, in both the
/// full-page and embedded (master-detail) app bars.
class _StubSessionRepository implements PreDiveSessionRepository {
  /// Every link write in order. A null diveId is an unlink.
  final List<({String sessionId, String? diveId})> linkWrites = [];

  @override
  Future<void> linkToDive(String sessionId, String diveId) async =>
      linkWrites.add((sessionId: sessionId, diveId: diveId));

  @override
  Future<void> unlinkFromDive(String sessionId) async =>
      linkWrites.add((sessionId: sessionId, diveId: null));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final startedAt = DateTime(2026, 3, 27, 19, 40);

  PreDiveSession session(String id, {String name = 'CCR Build Check'}) =>
      PreDiveSession(
        id: id,
        templateName: name,
        status: PreDiveSessionStatus.completed,
        startedAt: startedAt,
        createdAt: startedAt,
        updatedAt: startedAt,
      );

  Future<_StubSessionRepository> pumpDetail(
    WidgetTester tester, {
    required bool embedded,
    PreDiveSession? linked,
    List<PreDiveSession> unlinked = const [],
  }) async {
    final dive = createTestDiveWithBottomTime();
    final overrides = await getBaseOverrides(linkedPreDiveSession: linked);
    final repo = _StubSessionRepository();

    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/detail',
          builder: (context, state) {
            final page = DiveDetailPage(diveId: dive.id, embedded: embedded);
            // Embedded mode renders no Scaffold of its own; in production it
            // always sits inside MasterDetailScaffold's, which is what the
            // confirmation snackbar presents to.
            return embedded ? Scaffold(body: page) : page;
          },
        ),
      ],
    );

    // The detail page intentionally overflows its fixed test viewport; that is
    // not what this test asserts, so swallow only overflow errors.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveProvider(dive.id).overrideWith((ref) async => dive),
          diveDataSourcesProvider(
            dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
          preDiveSessionRepositoryProvider.overrideWithValue(repo),
          preDiveUnlinkedSessionsProvider.overrideWith(
            (ref, diverId) async => unlinked,
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    return repo;
  }

  Future<void> openMenu(WidgetTester tester) async {
    // The header overflow menu is the last more_vert on the page (a source bar,
    // when present, renders earlier).
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
  }

  for (final embedded in [false, true]) {
    final label = embedded ? 'embedded app bar' : 'full-page app bar';

    testWidgets('$label: offers Link pre-dive checklist when none is linked', (
      tester,
    ) async {
      await pumpDetail(tester, embedded: embedded);
      await openMenu(tester);

      expect(find.text('Link pre-dive checklist'), findsOneWidget);
      expect(find.text('Unlink pre-dive checklist'), findsNothing);
    });

    testWidgets('$label: choosing a run links it to this dive', (tester) async {
      final repo = await pumpDetail(
        tester,
        embedded: embedded,
        unlinked: [session('s1')],
      );

      await openMenu(tester);
      await tester.tap(find.text('Link pre-dive checklist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CCR Build Check'));
      await tester.pumpAndSettle();

      expect(repo.linkWrites, [(sessionId: 's1', diveId: 'test-dive-1')]);
    });

    testWidgets('$label: offers Unlink once a run is attached', (tester) async {
      final repo = await pumpDetail(
        tester,
        embedded: embedded,
        linked: session('s1'),
      );

      await openMenu(tester);
      expect(find.text('Link pre-dive checklist'), findsNothing);

      await tester.tap(find.text('Unlink pre-dive checklist'));
      await tester.pumpAndSettle();

      expect(repo.linkWrites, [(sessionId: 's1', diveId: null)]);
    });
  }
}
