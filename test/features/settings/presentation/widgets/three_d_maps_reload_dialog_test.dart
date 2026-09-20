import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_reset_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/three_d_maps_reload_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  testWidgets(
    'shows the estimate, duration and Wi-Fi hint, then confirms on tap',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await getBaseOverrides(),
            mapReloadEstimateProvider.overrideWith(
              (ref) async => const MapReloadEstimate(
                siteCount: 3,
                averageBytesPerSite: 1024 * 1024,
              ),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showMapReloadConfirmDialog(context),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Reload map data for every dive site?'), findsOneWidget);
      expect(find.text('3 dive sites will be reloaded.'), findsOneWidget);
      expect(find.textContaining('Estimated download'), findsOneWidget);
      expect(find.text('This can take several minutes.'), findsOneWidget);
      expect(
        find.text(
          'A lot of data will be downloaded — a fast Wi-Fi connection '
          'is recommended.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Reload'));
      await tester.pumpAndSettle();

      expect(find.text('Reload map data for every dive site?'), findsNothing);
    },
  );

  testWidgets('returns false when the diver cancels', (tester) async {
    bool? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          mapReloadEstimateProvider.overrideWith(
            (ref) async => const MapReloadEstimate(siteCount: 1),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showMapReloadConfirmDialog(context);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets(
    'shows a spinner while the estimate is loading and nothing when it '
    'fails to load',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await getBaseOverrides(),
            mapReloadEstimateProvider.overrideWith((ref) async {
              throw Exception('boom');
            }),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showMapReloadConfirmDialog(context),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('will be reloaded'), findsNothing);
    },
  );

  testWidgets('omits the estimated size when there is nothing to average', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          mapReloadEstimateProvider.overrideWith(
            (ref) async => const MapReloadEstimate(siteCount: 2),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showMapReloadConfirmDialog(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('2 dive sites will be reloaded.'), findsOneWidget);
    expect(find.textContaining('Estimated download'), findsNothing);
  });
}
