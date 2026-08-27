import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Renders a real [DiveDetailPage] inside a router so the previous/next
/// controls and arrow keys exercise the page's navigation helpers.
Future<List<String>> _pumpNav(
  WidgetTester tester, {
  required bool embedded,
  required Size size,
  String initialLocation = '/dives',
}) async {
  final dive = createTestDiveWithBottomTime(id: 'b');
  final overrides = await getBaseOverrides();
  final locations = <String>[];

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/dives',
        builder: (context, state) {
          locations.add(state.uri.toString());
          return DiveDetailPage(diveId: 'b', embedded: embedded);
        },
      ),
      GoRoute(
        path: '/dives/:id',
        builder: (context, state) {
          locations.add(state.uri.toString());
          // A detail path is always a standalone page, so pushing one from
          // the embedded pane exercises the master-detail redirect guard.
          return DiveDetailPage(
            diveId: state.pathParameters['id']!,
            embedded: false,
          );
        },
      ),
    ],
  );

  final originalOnError = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.toString().contains('overflowed')) return;
    originalOnError?.call(d);
  };

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        diveProvider(dive.id).overrideWith((ref) async => dive),
        diveDataSourcesProvider(
          dive.id,
        ).overrideWith((ref) async => <DiveDataSource>[]),
        orderedDiveIdsProvider.overrideWith((ref) async => ['a', 'b', 'c']),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  FlutterError.onError = originalOnError;
  return locations;
}

void main() {
  testWidgets('embedded: Next/Previous buttons swap the selected dive', (
    tester,
  ) async {
    final locations = await _pumpNav(
      tester,
      embedded: true,
      size: const Size(1200, 800),
    );

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(locations.last, '/dives?selected=c');

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    expect(locations.last, '/dives?selected=a');
  });

  // Arrow-key navigation (Left/Right) is wired in _wrapWithDiveShortcuts and
  // verified manually: the widget tester's focus handling is unreliable across
  // the route rebuild that each navigation triggers. The button tests above and
  // below cover the shared _navigateToDive helper the shortcuts delegate to.

  testWidgets('standalone: Next uses replace navigation', (tester) async {
    final locations = await _pumpNav(
      tester,
      embedded: false,
      // Narrow so the desktop master-detail redirect does not fire.
      size: const Size(500, 800),
    );

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(locations.last, '/dives/c');
  });

  testWidgets('standalone wide: a plain detail path redirects into the pane', (
    tester,
  ) async {
    // Baseline for the menu case below: at master-detail width a root-level
    // standalone /dives/:id bounces into /dives?selected=:id.
    final locations = await _pumpNav(
      tester,
      embedded: false,
      size: const Size(1200, 800),
      initialLocation: '/dives/b',
    );

    expect(locations.last, '/dives?selected=b');
  });

  testWidgets('embedded wide: Open Full Page pushes a standalone page', (
    tester,
  ) async {
    // "Open Full Page" must push (not go) so the pushed page can pop back
    // and skips the master-detail redirect instead of bouncing straight
    // back into the pane it was opened from (PR #802).
    final locations = await _pumpNav(
      tester,
      embedded: true,
      size: const Size(1200, 800),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Full Page'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The pane route below rebuilds when the menu closes, so assert on
    // membership rather than ordering.
    expect(locations, contains('/dives/b'));
    expect(
      locations.where((l) => l.contains('selected=')),
      isEmpty,
      reason: 'the full page must not redirect back into the pane',
    );
  });
}
