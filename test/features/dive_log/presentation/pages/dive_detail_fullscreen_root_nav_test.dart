import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/pages/fullscreen_profile_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The app hosts every tab inside a single `ShellRoute` whose Navigator lives
/// below `MainScaffold`'s bottom navigation bar. A plain
/// `Navigator.of(context).push` from the detail page therefore lands on that
/// shell Navigator and renders "fullscreen" underneath the app's own chrome
/// (#811). This stands in a nested Navigator for the shell so the push target
/// is observable.
void main() {
  late Dive dive;

  setUp(() {
    final dt = DateTime(2026, 3, 4, 10);
    dive = Dive(
      id: 'dive-1',
      dateTime: dt,
      entryTime: dt,
      diveNumber: 7,
      site: const DiveSite(id: 'site-1', name: 'Blue Hole'),
      profile: List.generate(
        61,
        (i) => DiveProfilePoint(timestamp: i * 10, depth: 10, temperature: 20),
      ),
    );
  });

  testWidgets('fullscreen profile is pushed above the shell navigator', (
    tester,
  ) async {
    final base = await getBaseOverrides();
    final shellNavigatorKey = GlobalKey<NavigatorState>();

    // Tall surface so the profile card's action row is on screen without
    // scrolling, and wide enough to stay on the desktop side of the
    // fullscreen page's own phone gate.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The detail page overflows this viewport; those layout warnings are
    // noise for this test.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.toString().contains('overflowed')) return;
      originalOnError?.call(d);
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveProvider(dive.id).overrideWith((ref) async => dive),
          diveDataSourcesProvider(
            dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Navigator(
              key: shellNavigatorKey,
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => DiveDetailPage(diveId: dive.id, embedded: true),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    FlutterError.onError = originalOnError;

    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(FullscreenProfilePage), findsOneWidget);
    // The decisive assertion: the shell Navigator's stack must not have
    // grown. Drop `rootNavigator: true` and this flips to true, which is
    // exactly the state in which the bottom navigation bar stays painted.
    expect(
      shellNavigatorKey.currentState!.canPop(),
      isFalse,
      reason: 'fullscreen must not be pushed onto the shell navigator',
    );
  });
}
