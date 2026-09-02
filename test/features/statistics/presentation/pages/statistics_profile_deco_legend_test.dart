import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_profile_page.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Minimal mock SettingsNotifier using noSuchMethod to avoid re-implementing
/// the full interface. Matches the pattern used in the other statistics page
/// tests.
class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mock CurrentDiverIdNotifier that does not access the database.
class _MockCurrentDiverIdNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _MockCurrentDiverIdNotifier() : super(null);

  @override
  Future<void> setCurrentDiver(String id) async => state = id;

  @override
  Future<void> clearCurrentDiver() async => state = null;
}

void main() {
  group('Decompression Obligation legend', () {
    const decoCount = 29;
    const noDecoCount = 194;

    late SharedPreferences prefs;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Future<void> pumpPage(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            decoObligationStatsProvider.overrideWith(
              (ref) async => (
                decoCount: decoCount,
                noDecoCount: noDecoCount,
                unknownCount: 0,
              ),
            ),
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
            home: StatisticsProfilePage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// The legend labels are the only colored copies of these strings; the
    /// stat tiles above render the same words in onSurfaceVariant.
    Finder legendLabel(String text, Color color) => find.byWidgetPredicate(
      (widget) =>
          widget is Text && widget.data == text && widget.style?.color == color,
      description: '$text label styled $color',
    );

    testWidgets('bar fills with the deco share', (tester) async {
      await pumpPage(tester);

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );

      expect(bar.value, closeTo(decoCount / (decoCount + noDecoCount), 0.001));
      expect(bar.valueColor?.value, Colors.orange);
    });

    testWidgets('each label sits under the segment it names', (tester) async {
      await pumpPage(tester);

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      // The bar paints valueColor from the leading edge and leaves the
      // remainder in backgroundColor, so the label naming the filled share
      // has to be the leading one.
      final fillColor = bar.valueColor!.value!;

      final decoFinder = legendLabel('Deco', fillColor);
      final noDecoFinder = legendLabel('No Deco', Colors.green);
      expect(decoFinder, findsOneWidget);
      expect(noDecoFinder, findsOneWidget);

      expect(
        tester.getCenter(decoFinder).dx,
        lessThan(tester.getCenter(noDecoFinder).dx),
        reason:
            'the orange "Deco" label must sit under the orange leading fill, '
            'not opposite it',
      );
    });
  });
}
