import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/display_zoom.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/pop_out/presentation/pop_out_app.dart';
import 'package:submersion/features/pop_out/presentation/providers/pop_out_client.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/fake_pop_out_windows.dart';
import 'pop_out_client_test.dart' show FakeWindowControl, launchOn;

class _FakeSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // The app's builder sets Intl.defaultLocale, a process global (#2500).
  late String? previousLocale;
  setUp(() => previousLocale = Intl.defaultLocale);
  tearDown(() => Intl.defaultLocale = previousLocale);

  // A pop-out on a second monitor must look like the main window (#5078):
  // its theme, language and display zoom, as the main window last sent them.
  testWidgets("the pop-out takes the main window's theme, language and zoom", (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      currentDiverIdKey: 'diver-1',
      SettingsKeys.displayZoom: 1.25,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(
            (ref) => _FakeSettingsNotifier(
              const AppSettings(themeMode: ThemeMode.dark, locale: 'de'),
            ),
          ),
          popOutLaunchProvider.overrideWithValue(launchOn(null)),
          popOutChannelProvider.overrideWithValue(FakePopOutChannel()),
          popOutWindowControlProvider.overrideWithValue(FakeWindowControl()),
          currentDiverIdProvider.overrideWith(
            (ref) => CurrentDiverIdNotifier.readOnly(
              ref.watch(sharedPreferencesProvider),
              ref.watch(diverRepositoryProvider),
            ),
          ),
        ],
        child: const PopOutApp(),
      ),
    );
    await tester.pumpAndSettle();

    final placeholder = find.text('Wähle einen Tauchgang im Hauptfenster');
    expect(placeholder, findsOneWidget);
    expect(Theme.of(tester.element(placeholder)).brightness, Brightness.dark);
    expect(
      tester.widget<DisplayZoomScope>(find.byType(DisplayZoomScope)).zoom,
      1.25,
    );
  });

  testWidgets('a window that could not reach the logbook says so', (
    tester,
  ) async {
    // It has no settings to take a language from, so it follows the
    // system's: pinned here so the English text is what shows.
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const PopOutConnectFailedApp());
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This window could not reach the logbook. Close it and try again.',
      ),
      findsOneWidget,
    );
  });
}
