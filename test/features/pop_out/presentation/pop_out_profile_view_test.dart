import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/fullscreen_profile_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_transport_bar.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/pop_out/domain/pop_out_messages.dart';
import 'package:submersion/features/pop_out/presentation/pop_out_profile_view.dart';
import 'package:submersion/features/pop_out/presentation/providers/pop_out_client.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/fake_pop_out_windows.dart';
import 'pop_out_client_test.dart' show FakeWindowControl, launchOn;

class _FakeSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Dive _dive(String id, {int number = 142, String? diverId}) => Dive(
  id: id,
  diverId: diverId,
  dateTime: DateTime(2026, 1, 1, 10),
  diveNumber: number,
  site: const DiveSite(id: 's', name: 'Salt Pier'),
  profile: List.generate(
    61,
    (i) => DiveProfilePoint(timestamp: i * 10, depth: 10, temperature: 20),
  ),
);

void main() {
  late FakePopOutChannel channel;
  late FakeWindowControl control;

  Future<void> pump(
    WidgetTester tester,
    PopOutLaunch launch, {
    Map<String, Dive?> dives = const {},
  }) async {
    SharedPreferences.setMockInitialValues({currentDiverIdKey: 'diver-1'});
    final prefs = await SharedPreferences.getInstance();
    channel = FakePopOutChannel();
    control = FakeWindowControl();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => _FakeSettingsNotifier()),
          popOutLaunchProvider.overrideWithValue(launch),
          popOutChannelProvider.overrideWithValue(channel),
          popOutWindowControlProvider.overrideWithValue(control),
          currentDiverIdProvider.overrideWith(
            (ref) => CurrentDiverIdNotifier.readOnly(
              ref.watch(sharedPreferencesProvider),
              ref.watch(diverRepositoryProvider),
            ),
          ),
          for (final entry in dives.entries) ...[
            diveProvider(entry.key).overrideWith((ref) async => entry.value),
            profileAnalysisProvider(
              entry.key,
            ).overrideWith((ref) async => null),
            gasSwitchesProvider(entry.key).overrideWith((ref) async => []),
            tankPressuresProvider(entry.key).overrideWith((ref) async => {}),
          ],
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(size: const Size(1200, 900)),
            child: child!,
          ),
          home: const PopOutProfileView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no dive shows the select placeholder', (tester) async {
    await pump(tester, launchOn(null));
    expect(find.text('Select a dive in the main window'), findsOneWidget);
    expect(find.byType(FullscreenProfilePage), findsNothing);
  });

  testWidgets('lock shows the locked placeholder and hides the chart', (
    tester,
  ) async {
    await pump(tester, launchOn('a'), dives: {'a': _dive('a')});
    expect(find.byType(FullscreenProfilePage), findsOneWidget);

    channel.deliver(const LockMessage(true));
    await tester.pumpAndSettle();
    expect(find.text('Unlock Submersion in the main window'), findsOneWidget);
    expect(find.byType(FullscreenProfilePage), findsNothing);
    // Nor in the window's title, which the Dock and taskbar show.
    expect(control.calls.last, 'title:Submersion');
  });

  testWidgets('shows the dive with a pin and names the window after it', (
    tester,
  ) async {
    await pump(tester, launchOn('a'), dives: {'a': _dive('a')});
    expect(find.byType(FullscreenProfilePage), findsOneWidget);
    expect(find.byTooltip('Pin to this dive'), findsOneWidget);
    expect(control.calls, contains('title:Profile: #142 Salt Pier'));
    // A chart to look at beside the main window: no playback bar.
    expect(find.byType(ProfileTransportBar), findsNothing);

    await tester.tap(find.byTooltip('Pin to this dive'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Follow the main window'), findsOneWidget);
  });

  testWidgets('follows the main window to another dive', (tester) async {
    await pump(
      tester,
      launchOn('a'),
      dives: {'a': _dive('a'), 'b': _dive('b', number: 143)},
    );
    channel.deliver(const ShowDiveMessage('b'));
    await tester.pumpAndSettle();
    expect(control.calls, contains('title:Profile: #143 Salt Pier'));
  });

  testWidgets('deleted pinned dive unpins and shows the placeholder', (
    tester,
  ) async {
    await pump(tester, launchOn('gone'), dives: {'gone': null});
    expect(find.text('Select a dive in the main window'), findsOneWidget);
  });

  testWidgets('a deleted dive takes its name off the window', (tester) async {
    await pump(tester, launchOn('a'), dives: {'a': _dive('a'), 'gone': null});
    expect(control.calls, contains('title:Profile: #142 Salt Pier'));

    channel.deliver(const ShowDiveMessage('gone'));
    await tester.pumpAndSettle();

    expect(find.text('Select a dive in the main window'), findsOneWidget);
    expect(control.calls.last, 'title:Submersion');
  });

  testWidgets("another diver's dive is not shown", (tester) async {
    // The main window switched diver; the pop-out still followed a dive of
    // the previous one, which would be drawn in the new diver's settings.
    await pump(
      tester,
      launchOn('a'),
      dives: {'a': _dive('a', diverId: 'diver-0')},
    );
    expect(find.byType(FullscreenProfilePage), findsNothing);
    expect(find.text('Select a dive in the main window'), findsOneWidget);
  });

  testWidgets("the active diver's dive is shown", (tester) async {
    await pump(
      tester,
      launchOn('a'),
      dives: {'a': _dive('a', diverId: 'diver-1')},
    );
    expect(find.byType(FullscreenProfilePage), findsOneWidget);
  });
}
