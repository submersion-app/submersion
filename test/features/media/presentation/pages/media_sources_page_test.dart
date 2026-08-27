import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/features/media/data/services/local_files_diagnostics_service.dart';
import 'package:submersion/features/media/data/services/media_verification_sweep.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/pages/media_sources_page.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Diagnostics service stub used to drive the Local files card without
/// hitting the real DB / platform channel.
class _StubDiagnosticsService implements LocalFilesDiagnosticsService {
  _StubDiagnosticsService();

  @override
  Future<int> androidUriUsage() async => 0;

  @override
  Future<LocalFilesDiagnostics> diagnose() async =>
      const LocalFilesDiagnostics(total: 0, available: 0, unavailable: 0);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} should not be called');
}

/// Records the filter it was handed and returns a canned outcome, or throws.
class _StubSweep implements MediaVerificationSweep {
  _StubSweep(this.outcome, {this.error});

  final SweepOutcome outcome;
  final Object? error;
  final List<Set<MediaSourceType>?> asked = [];

  @override
  Future<SweepOutcome> run({
    Set<MediaSourceType>? sourceTypes,
    void Function(int done, int total)? onProgress,
  }) async {
    asked.add(sourceTypes);
    if (error != null) throw error!;
    return outcome;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} should not be called');
}

/// The page is a ListView, which builds only what is near the viewport. At
/// the default 800x600 test surface the lower cards (Lightroom, Network
/// sources) fall outside it and `find.text` reports zero matches, so these
/// tests need a surface tall enough to hold the whole page.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap() => const ProviderScope(
  child: MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaSourcesPage(),
  ),
);

Widget _wrapWith(List<Object> overrides) => ProviderScope(
  overrides: overrides.cast(),
  child: const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaSourcesPage(),
  ),
);

void main() {
  // The Lightroom entry point is gated behind [lightroomUiEnabled], which
  // defaults to false while the integration is pending Adobe review. Enable it
  // for the surface tests that assert the Lightroom UI wires up correctly, and
  // reset after each test so the value does not leak.
  setUp(() => lightroomUiEnabled = true);
  tearDown(() => lightroomUiEnabled = false);

  testWidgets('renders Photo library and Adobe Lightroom, without the '
      'hidden-picker-tabs toggle', (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Media Sources'), findsOneWidget);
    expect(find.text('Photo library'), findsOneWidget);
    expect(find.text('Adobe Lightroom'), findsOneWidget);
    // The debug toggle is retired; the picker always shows all tabs.
    expect(find.text('Show hidden picker tabs'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('hides the Adobe Lightroom entry point when lightroomUiEnabled '
      'is false (pending Adobe review)', (tester) async {
    lightroomUiEnabled = false;
    _useTallSurface(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // Other sources remain; only the Lightroom card is gated out.
    expect(find.text('Photo library'), findsOneWidget);
    expect(find.text('Network sources'), findsOneWidget);
    expect(find.text('Adobe Lightroom'), findsNothing);
  });

  testWidgets(
    'renders Local files card with diagnostics counts and Re-verify tile',
    (tester) async {
      await tester.pumpWidget(
        _wrapWith([
          localFilesDiagnosticsProvider.overrideWith(
            (ref) async => const LocalFilesDiagnostics(
              total: 5,
              available: 4,
              unavailable: 1,
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Local files'), findsOneWidget);
      expect(find.text('4 available, 1 unavailable'), findsOneWidget);
      expect(find.text('Re-verify all local files'), findsOneWidget);
    },
  );

  testWidgets('shows Counting placeholder while diagnostics are loading', (
    tester,
  ) async {
    // Use a Completer instead of a Future.delayed timer so we don't leak a
    // pending timer when the test ends.
    final completer = Completer<LocalFilesDiagnostics>();
    addTearDown(() {
      if (!completer.isCompleted) {
        completer.complete(
          const LocalFilesDiagnostics(total: 0, available: 0, unavailable: 0),
        );
      }
    });
    await tester.pumpWidget(
      _wrapWith([
        localFilesDiagnosticsProvider.overrideWith(
          (ref) async => completer.future,
        ),
      ]),
    );
    await tester.pump(); // initial frame; provider stays loading
    expect(find.textContaining('Counting'), findsOneWidget);
  });

  // Note: AsyncError branch on the Local files subtitle (`Error: $e`) is
  // hard to drive deterministically under flutter_test because Riverpod's
  // FutureProvider.overrideWith requires a settled rejection that flutter's
  // fake-async timer pump doesn't deliver to a ListView sliver build pass
  // without runAsync, and runAsync conflicts with widget-tree settling.
  // Exercised by manual smoke tests on the macOS host.

  testWidgets('tapping Re-verify all triggers reverifyAll and shows snackbar', (
    tester,
  ) async {
    final sweep = _StubSweep(
      const SweepOutcome(processed: 10, flipped: 3, inconclusive: 0, failed: 0),
    );
    await tester.pumpWidget(
      _wrapWith([
        localFilesDiagnosticsServiceProvider.overrideWithValue(
          _StubDiagnosticsService(),
        ),
        mediaVerificationSweepProvider.overrideWithValue(sweep),
        localFilesDiagnosticsProvider.overrideWith(
          (ref) async => const LocalFilesDiagnostics(
            total: 0,
            available: 0,
            unavailable: 0,
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Re-verify all local files'));
    await tester.pump(); // start the future
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(); // run microtasks

    // Still filtered to local files. This tile is the Local files card's own
    // action; the unfiltered pass is the separate "Check all media" tile.
    expect(sweep.asked.single, {MediaSourceType.localFile});
    // Snackbar with the count.
    expect(find.text('3 items updated'), findsOneWidget);
  });

  testWidgets('reverifyAll error path shows Re-verify failed snackbar', (
    tester,
  ) async {
    final sweep = _StubSweep(
      const SweepOutcome(processed: 0, flipped: 0, inconclusive: 0, failed: 0),
      error: Exception('nope'),
    );
    await tester.pumpWidget(
      _wrapWith([
        localFilesDiagnosticsServiceProvider.overrideWithValue(
          _StubDiagnosticsService(),
        ),
        mediaVerificationSweepProvider.overrideWithValue(sweep),
        localFilesDiagnosticsProvider.overrideWith(
          (ref) async => const LocalFilesDiagnostics(
            total: 0,
            available: 0,
            unavailable: 0,
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Re-verify all local files'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    expect(sweep.asked, hasLength(1));
    expect(find.textContaining('Re-verify failed'), findsOneWidget);
  });

  testWidgets('renders Network sources entry that pushes to network-sources', (
    tester,
  ) async {
    _useTallSurface(tester);
    var pushed = false;
    final router = GoRouter(
      initialLocation: '/settings/media-sources',
      routes: [
        GoRoute(
          path: '/settings/media-sources',
          builder: (context, state) => const MediaSourcesPage(),
          routes: [
            GoRoute(
              path: 'network-sources',
              builder: (context, state) {
                pushed = true;
                return const Scaffold(body: Text('NETWORK_SOURCES_PAGE'));
              },
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Network sources'), findsOneWidget);
    expect(find.text('URLs and manifest feeds (advanced)'), findsOneWidget);

    await tester.tap(find.text('Network sources'));
    await tester.pumpAndSettle();

    expect(pushed, isTrue);
    expect(find.text('NETWORK_SOURCES_PAGE'), findsOneWidget);
  });

  group('Check all media', () {
    testWidgets('reports the number of rows whose state changed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWith([
          localFilesDiagnosticsServiceProvider.overrideWithValue(
            _StubDiagnosticsService(),
          ),
          mediaVerificationSweepProvider.overrideWithValue(
            _StubSweep(
              const SweepOutcome(
                processed: 453,
                flipped: 2,
                inconclusive: 0,
                failed: 0,
              ),
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Check all media'));
      await tester.pumpAndSettle();

      expect(find.text('2 items updated'), findsOneWidget);
    });

    // The failure this exists to prevent: a device with revoked photo
    // permission verifies nothing, and "0 items updated" would read as a
    // clean bill of health for a library nobody could look at.
    testWidgets('a blocked pass says so instead of reporting success', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWith([
          localFilesDiagnosticsServiceProvider.overrideWithValue(
            _StubDiagnosticsService(),
          ),
          mediaVerificationSweepProvider.overrideWithValue(
            _StubSweep(
              const SweepOutcome(
                processed: 453,
                flipped: 0,
                inconclusive: 453,
                failed: 0,
              ),
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Check all media'));
      await tester.pumpAndSettle();

      // Cause-neutral wording: inconclusive aggregates a missing photo
      // permission, an unmounted volume, a disconnected connector account and
      // rows from another machine, so the message must not name one of them.
      expect(find.textContaining('Could not check'), findsOneWidget);
      expect(find.textContaining('photo library'), findsNothing);
      expect(find.text('0 items updated'), findsNothing);
    });

    // inconclusive aggregates several causes (no photo permission, an
    // unmounted volume, a disconnected connector account, a row from another
    // machine), so one unreachable row must not replace the real result with
    // a message about any single one of them.
    testWidgets('a partly inconclusive pass still reports what changed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWith([
          localFilesDiagnosticsServiceProvider.overrideWithValue(
            _StubDiagnosticsService(),
          ),
          mediaVerificationSweepProvider.overrideWithValue(
            _StubSweep(
              const SweepOutcome(
                processed: 453,
                flipped: 2,
                inconclusive: 1,
                failed: 0,
              ),
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Check all media'));
      await tester.pumpAndSettle();

      expect(find.text('2 items updated'), findsOneWidget);
      expect(find.textContaining('Could not check'), findsNothing);
    });

    testWidgets('sweeps every source type, unfiltered', (tester) async {
      final sweep = _StubSweep(
        const SweepOutcome(
          processed: 1,
          flipped: 0,
          inconclusive: 0,
          failed: 0,
        ),
      );
      await tester.pumpWidget(
        _wrapWith([
          localFilesDiagnosticsServiceProvider.overrideWithValue(
            _StubDiagnosticsService(),
          ),
          mediaVerificationSweepProvider.overrideWithValue(sweep),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Check all media'));
      await tester.pumpAndSettle();

      // Null, not a filter. The whole point of this action is that it is not
      // restricted to local files the way the re-verify above it is.
      expect(sweep.asked.single, isNull);
    });
  });
}
