import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/presentation/pages/insights_profile_page.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockCurrentDiverIdNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _MockCurrentDiverIdNotifier() : super(null);

  @override
  Future<void> setCurrentDiver(String id) async => state = id;

  @override
  Future<void> clearCurrentDiver() async => state = null;
}

/// Issue #3807: while a first pass works through the library the card shows
/// what it knows so far instead of a bare spinner.
void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required DecoClassificationProgress? progress,
  }) async {
    final neverLoads = Completer<DecoObligationStats>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          decoObligationStatsProvider.overrideWith((ref) => neverLoads.future),
          decoClassificationProgressProvider.overrideWith((ref) => progress),
          ascentDescentRatesProvider.overrideWith(
            (ref) async => (avgAscent: null, avgDescent: null),
          ),
          timeAtDepthRangesProvider.overrideWith((ref) async => []),
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => _MockCurrentDiverIdNotifier(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InsightsProfilePage(embedded: true),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows the counts so far and how far the pass has got', (
    tester,
  ) async {
    await pumpPage(
      tester,
      progress: (
        stats: (decoCount: 3, noDecoCount: 9, unknownCount: 0),
        analyzed: 12,
        total: 40,
      ),
    );

    expect(find.text('Analyzing dives: 12 of 40'), findsOneWidget);
    expect(find.text('Deco Dives'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('25.0%'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is LinearProgressIndicator && w.value == 12 / 40,
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows progress alone while nothing is classified yet', (
    tester,
  ) async {
    await pumpPage(
      tester,
      progress: (
        stats: (decoCount: 0, noDecoCount: 0, unknownCount: 0),
        analyzed: 0,
        total: 40,
      ),
    );

    expect(find.text('Analyzing dives: 0 of 40'), findsOneWidget);
    expect(find.text('Deco Dives'), findsNothing);
  });

  testWidgets(
    'shows the dives left out of the rate as soon as they are known',
    (tester) async {
      await pumpPage(
        tester,
        progress: (
          stats: (decoCount: 0, noDecoCount: 0, unknownCount: 5),
          analyzed: 0,
          total: 40,
        ),
      );

      expect(find.textContaining('5 dives have no recorded'), findsOneWidget);
      expect(find.text('Analyzing dives: 0 of 40'), findsOneWidget);
    },
  );

  testWidgets('falls back to the spinner before the scan has finished', (
    tester,
  ) async {
    await pumpPage(tester, progress: null);

    expect(find.textContaining('Analyzing dives'), findsNothing);
    expect(find.text('Deco Dives'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });
}
