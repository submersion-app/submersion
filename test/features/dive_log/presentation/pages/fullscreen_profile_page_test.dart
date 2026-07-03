import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/fullscreen_profile_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_playback_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_review_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_instrument_bar.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _FakeSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier([AppSettings? initial])
    : super(initial ?? const AppSettings());

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

Widget _wrap(List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: FullscreenProfilePage(diveId: 'd1'),
  ),
);

List<Override> _defaultOverrides() {
  final dive = _dive();
  return [
    settingsProvider.overrideWith((ref) => _FakeSettingsNotifier()),
    diveProvider(dive.id).overrideWith((ref) async => dive),
    profileAnalysisProvider(dive.id).overrideWith((ref) async => null),
    gasSwitchesProvider(dive.id).overrideWith((ref) async => []),
    tankPressuresProvider(dive.id).overrideWith((ref) async => {}),
  ];
}

List<Override> _erroringOverrides() {
  final dive = _dive();
  return [
    settingsProvider.overrideWith((ref) => _FakeSettingsNotifier()),
    diveProvider(dive.id).overrideWith((ref) async => throw Exception('boom')),
    profileAnalysisProvider(dive.id).overrideWith((ref) async => null),
    gasSwitchesProvider(dive.id).overrideWith((ref) async => []),
    tankPressuresProvider(dive.id).overrideWith((ref) async => {}),
  ];
}

void main() {
  testWidgets('renders chart and instrument bar', (tester) async {
    await tester.pumpWidget(_wrap(_defaultOverrides()));
    await tester.pumpAndSettle();

    expect(find.byType(DiveProfileChart), findsOneWidget);
    expect(find.byType(ProfileInstrumentBar), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('chart fills most of the screen height', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_defaultOverrides()));
    await tester.pumpAndSettle();

    final chartHeight = tester.getSize(find.byType(DiveProfileChart)).height;
    expect(chartHeight, greaterThan(500));
  });

  testWidgets('close button pops the page', (tester) async {
    await tester.pumpWidget(_wrap(_defaultOverrides()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(DiveProfileChart), findsNothing);
  });

  testWidgets('error state shows error icon and message with close button', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_erroringOverrides()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(FullscreenProfilePage), findsNothing);
  });

  testWidgets(
    'closing fullscreen mid-play resets playback and review position',
    (tester) async {
      final container = ProviderContainer(overrides: _defaultOverrides());
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FullscreenProfilePage(diveId: 'd1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The transport controls auto-activate playback mode on entry.
      expect(container.read(playbackProvider('d1')).isActive, isTrue);

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      expect(container.read(playbackProvider('d1')).isPlaying, isTrue);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      final playback = container.read(playbackProvider('d1'));
      expect(playback.isPlaying, isFalse);
      expect(playback.isActive, isFalse);
      expect(container.read(profileReviewProvider('d1')), isNull);
    },
  );
}
