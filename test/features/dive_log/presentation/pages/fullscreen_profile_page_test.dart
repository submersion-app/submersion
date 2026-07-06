import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/pages/fullscreen_profile_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_playback_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_review_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/draggable_readout_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_instrument_bar.dart';
import 'package:submersion/features/dive_log/presentation/widgets/source_bar.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _FakeSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier([AppSettings? initial])
    : super(initial ?? const AppSettings());

  double? savedCardX;
  double? savedCardY;

  @override
  Future<void> setFullscreenReadoutCardPosition(double x, double y) async {
    savedCardX = x;
    savedCardY = y;
    state = state.copyWith(
      fullscreenReadoutCardX: x,
      fullscreenReadoutCardY: y,
    );
  }

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

  testWidgets('shows the readout card with the placeholder hint', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_defaultOverrides()));
    await tester.pumpAndSettle();

    expect(find.byType(DraggableReadoutCard), findsOneWidget);
    expect(find.text('Hover or scrub the profile'), findsOneWidget);
  });

  testWidgets('chart runs in external-tooltip mode (no painted bubble)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_defaultOverrides()));
    await tester.pumpAndSettle();

    final chart = tester.widget<DiveProfileChart>(
      find.byType(DiveProfileChart),
    );
    expect(chart.tooltipBelow, isTrue);
    expect(chart.onTooltipData, isNotNull);
  });

  testWidgets('long-press populates the card and values stick after release', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_defaultOverrides()));
    await tester.pumpAndSettle();

    final chartCenter = tester.getCenter(find.byType(LineChart).first);
    final gesture = await tester.startGesture(chartCenter);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(2, 0));
    await tester.pump();

    // Rows arrived: hint is gone from the card.
    expect(find.text('Hover or scrub the profile'), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();

    // Sticky: hover ended but the card keeps the last values.
    expect(find.text('Hover or scrub the profile'), findsNothing);
  });

  testWidgets('dragging the card persists a clamped fraction to settings', (
    tester,
  ) async {
    final fake = _FakeSettingsNotifier();
    final overrides = _defaultOverrides()
      ..removeAt(0)
      ..insert(0, settingsProvider.overrideWith((ref) => fake));
    await tester.pumpWidget(_wrap(overrides));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('readout-card')),
      const Offset(-3000, 3000),
    );
    await tester.pumpAndSettle();

    expect(fake.savedCardX, 0.0);
    expect(fake.savedCardY, 1.0);
  });

  testWidgets('saved position seeds the card at bottom-left', (tester) async {
    final overrides = _defaultOverrides()
      ..removeAt(0)
      ..insert(
        0,
        settingsProvider.overrideWith(
          (ref) => _FakeSettingsNotifier(
            const AppSettings(
              fullscreenReadoutCardX: 0,
              fullscreenReadoutCardY: 1,
            ),
          ),
        ),
      );
    await tester.pumpWidget(_wrap(overrides));
    await tester.pumpAndSettle();

    final chartRect = tester.getRect(find.byType(DiveProfileChart));
    final cardRect = tester.getRect(find.byKey(const ValueKey('readout-card')));
    expect(cardRect.left, lessThan(chartRect.center.dx));
    expect(cardRect.bottom, greaterThan(chartRect.center.dy));
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
  testWidgets(
    'multi-source dive shows the sources bar; tapping a chip switches the '
    'chart profile; no management menu in fullscreen',
    (tester) async {
      final now = DateTime(2026, 5, 7);
      DiveDataSource source(String id, String computerId, bool isPrimary) =>
          DiveDataSource(
            id: id,
            diveId: 'd1',
            computerId: computerId,
            isPrimary: isPrimary,
            computerName: isPrimary ? 'Black' : 'Bronze',
            importedAt: now,
            createdAt: now,
          );
      List<DiveProfilePoint> points(int count) => List.generate(
        count,
        (i) => DiveProfilePoint(timestamp: i * 10, depth: 10),
      );

      await tester.pumpWidget(
        _wrap([
          ..._defaultOverrides(),
          diveDataSourcesProvider('d1').overrideWith(
            (ref) async => [
              source('src-a', 'dc-a', true),
              source('src-b', 'dc-b', false),
            ],
          ),
          sourceProfilesProvider('d1').overrideWith(
            (ref) async => {
              'src-a': SourceProfile(
                sourceId: 'src-a',
                computerId: 'dc-a',
                isEdited: false,
                points: points(61),
              ),
              'src-b': SourceProfile(
                sourceId: 'src-b',
                computerId: 'dc-b',
                isEdited: false,
                points: points(40),
              ),
            },
          ),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SourceBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SourceBar),
          matching: find.text('Bronze'),
        ),
        findsOneWidget,
      );
      // Management stays on the detail page: no overflow menus here.
      expect(
        find.descendant(
          of: find.byType(SourceBar),
          matching: find.byIcon(Icons.more_vert),
        ),
        findsNothing,
      );

      expect(
        tester.widget<DiveProfileChart>(find.byType(DiveProfileChart)).profile,
        hasLength(61),
      );
      // The instrument bar must resolve tiles against the SAME profile the
      // chart renders and the analysis is computed from; indexing analysis
      // curves with dive.profile positions reads wrong/blank values once the
      // arrays differ (issue: gauges wrong/blank mid-dive on 2-source dives).
      expect(
        tester
            .widget<ProfileInstrumentBar>(find.byType(ProfileInstrumentBar))
            .profile,
        hasLength(61),
      );

      await tester.tap(
        find.descendant(
          of: find.byType(SourceBar),
          matching: find.text('Bronze'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        tester.widget<DiveProfileChart>(find.byType(DiveProfileChart)).profile,
        hasLength(40),
      );
      expect(
        tester
            .widget<ProfileInstrumentBar>(find.byType(ProfileInstrumentBar))
            .profile,
        hasLength(40),
      );
    },
  );
}
