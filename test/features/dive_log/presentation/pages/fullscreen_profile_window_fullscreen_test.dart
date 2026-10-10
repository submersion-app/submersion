import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/window_fullscreen.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/fullscreen_profile_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/viewer_fullscreen_mode_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_window_fullscreen_platform.dart';
import '../../../../helpers/mock_providers.dart';

Dive _dive() => Dive(
  id: 'd1',
  dateTime: DateTime(2026, 1, 1, 10),
  profile: List.generate(
    61,
    (i) => DiveProfilePoint(timestamp: i * 10, depth: 10, temperature: 20),
  ),
);

/// The fullscreen dive profile against the OS window (#3178): the page is
/// fullscreen for its whole life, so with the Fullscreen setting the desktop
/// window goes fullscreen when it opens and comes back when it closes.
void main() {
  late FakeWindowFullscreenPlatform platform;

  setUp(() => platform = FakeWindowFullscreenPlatform());

  Future<void> pumpHost(
    WidgetTester tester, {
    required ViewerFullscreenMode mode,
  }) async {
    final dive = _dive();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          diveProvider(dive.id).overrideWith((ref) async => dive),
          profileAnalysisProvider(dive.id).overrideWith((ref) async => null),
          gasSwitchesProvider(dive.id).overrideWith((ref) async => []),
          tankPressuresProvider(dive.id).overrideWith((ref) async => {}),
          windowFullscreenPlatformProvider.overrideWithValue(platform),
          viewerFullscreenModeProvider.overrideWith(
            (ref) => ViewerFullscreenModeNotifier.unstored(mode),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FullscreenProfilePage(diveId: 'd1'),
                ),
              ),
              child: const Text('Open profile'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Fullscreen setting: opening and closing drive the window', (
    tester,
  ) async {
    await pumpHost(tester, mode: ViewerFullscreenMode.fullscreen);
    await tester.tap(find.text('Open profile'));
    await tester.pumpAndSettle();
    expect(platform.fullScreen, isTrue);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(FullscreenProfilePage), findsNothing);
    expect(platform.setCalls, [true, false]);
  });

  testWidgets('Full window setting: the OS window is never touched', (
    tester,
  ) async {
    await pumpHost(tester, mode: ViewerFullscreenMode.fullWindow);
    await tester.tap(find.text('Open profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(platform.setCalls, isEmpty);
  });
}
