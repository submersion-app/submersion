import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/fullscreen_profile_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_playback_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Dive _dive() => Dive(
  id: 'd1',
  dateTime: DateTime(2026, 1, 1, 10),
  profile: List.generate(
    61,
    (i) => DiveProfilePoint(timestamp: i * 10, depth: 10, temperature: 20),
  ),
);

List<dynamic> _overrides() {
  final dive = _dive();
  return [
    settingsProvider.overrideWith((ref) => _FakeSettingsNotifier()),
    diveProvider(dive.id).overrideWith((ref) async => dive),
    profileAnalysisProvider(dive.id).overrideWith((ref) async => null),
    gasSwitchesProvider(dive.id).overrideWith((ref) async => []),
    tankPressuresProvider(dive.id).overrideWith((ref) async => {}),
  ];
}

/// In a desktop pop-out window (#5078) the page is the whole window: the pin
/// takes the close button's place, and Escape does not pop it.
void main() {
  testWidgets('leading replaces the close button and Escape does nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides().cast(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Text('under'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(size: const Size(1200, 900)),
            child: child!,
          ),
        ),
      ),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const FullscreenProfilePage(
          diveId: 'd1',
          leading: Icon(Icons.push_pin_outlined),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(FullscreenProfilePage), findsOneWidget);
  });

  testWidgets('without leading the close button stays', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides().cast(),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(size: Size(1200, 900)),
            child: FullscreenProfilePage(diveId: 'd1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('playback can keep going when the window loses focus', (
    tester,
  ) async {
    // A pop-out playing on the second monitor while the diver works in the
    // main window (#5078).
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides().cast(),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(size: Size(1200, 900)),
            child: FullscreenProfilePage(
              diveId: 'd1',
              pauseWhenInactive: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FullscreenProfilePage)),
    );
    final playback = container.read(playbackProvider('d1').notifier);
    if (!container.read(playbackProvider('d1')).isActive) {
      playback.togglePlaybackMode();
    }
    playback.play();
    expect(container.read(playbackProvider('d1')).isPlaying, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(container.read(playbackProvider('d1')).isPlaying, isTrue);
    playback.pause();
  });
}
