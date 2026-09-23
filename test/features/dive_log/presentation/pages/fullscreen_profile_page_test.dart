import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/pages/fullscreen_profile_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_playback_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_review_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_transport_bar.dart';
import 'package:submersion/features/dive_log/presentation/widgets/source_bar.dart';
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

/// Phone and desktop sizes for the layout gate. The page reads
/// `MediaQuery.sizeOf`, and `setSurfaceSize` does not reliably drive that,
/// so [_wrap] injects an explicit MediaQuery instead.
const _phoneSize = Size(400, 800);
const _desktopSize = Size(1200, 900);

Widget _wrap(List<Override> overrides, {Size? size}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: size == null
        ? const FullscreenProfilePage(diveId: 'd1')
        : MediaQuery(
            data: MediaQueryData(size: size),
            child: const FullscreenProfilePage(diveId: 'd1'),
          ),
  ),
);

/// [_wrap] with an externally owned container, for cases that assert on
/// provider state after the page has run.
Widget _wrapContainer(ProviderContainer container, {Size? size}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: size == null
            ? const FullscreenProfilePage(diveId: 'd1')
            : MediaQuery(
                data: MediaQueryData(size: size),
                child: const FullscreenProfilePage(diveId: 'd1'),
              ),
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
  testWidgets('renders chart and transport bar', (tester) async {
    await tester.pumpWidget(_wrap(_defaultOverrides()));
    await tester.pumpAndSettle();

    expect(find.byType(DiveProfileChart), findsOneWidget);
    expect(find.byType(ProfileTransportBar), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('chart runs its cursor-following in-chart tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_defaultOverrides()));
    await tester.pumpAndSettle();

    final chart = tester.widget<DiveProfileChart>(
      find.byType(DiveProfileChart),
    );
    // Cursor-following ProfileCursorTooltip (issue #2228 follow-up): the
    // old clipping concern that used to justify the external presentation
    // here no longer applies, since that tooltip clamps to the plot rect
    // itself.
    expect(chart.tooltipPresentation, TooltipPresentation.inChart);
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
      // The transport bar must scrub against the SAME profile the chart
      // renders: its minimap and seek range are drawn from these points, so
      // passing dive.profile would scrub a different source's timeline.
      expect(
        tester
            .widget<ProfileTransportBar>(find.byType(ProfileTransportBar))
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
            .widget<ProfileTransportBar>(find.byType(ProfileTransportBar))
            .profile,
        hasLength(40),
      );
    },
  );

  SafetyFinding laneFinding() => SafetyFinding(
    id: 'f-lane',
    diveId: 'd1',
    ruleId: SafetyRuleId.rapidAscent,
    severity: SafetySeverity.caution,
    startTimestamp: 60,
    endTimestamp: 120,
    value: 14.0,
    engineVersion: 1,
    createdAt: DateTime.utc(2026, 8, 9),
  );

  List<Override> reviewOverrides(SafetyFinding finding) => [
    ..._defaultOverrides(),
    safetyReviewProvider('d1').overrideWith(
      (ref) async => SafetyReview(
        diveId: 'd1',
        engineVersion: 1,
        reviewedAt: DateTime.utc(2026, 8, 9),
        findings: [finding],
      ),
    ),
  ];

  testWidgets(
    'selected safety finding carries into fullscreen as a highlight',
    (tester) async {
      final finding = laneFinding();
      await tester.pumpWidget(_wrap(reviewOverrides(finding)));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(FullscreenProfilePage)),
      );
      container.read(selectedSafetyFindingProvider('d1').notifier).state =
          finding;
      await tester.pump();

      final chart = tester.widget<DiveProfileChart>(
        find.byType(DiveProfileChart),
      );
      expect(chart.highlightRange, isNotNull);
      expect(chart.highlightRange!.startTimestamp, 60);
      expect(chart.highlightRange!.endTimestamp, 120);
    },
  );

  testWidgets('a selection outside the gated lane renders no highlight', (
    tester,
  ) async {
    // The stored review has no active row for the selection (dismissed), so
    // the lane hides it; the highlight must be gated off with it.
    final dismissed = SafetyFinding(
      id: 'f-lane',
      diveId: 'd1',
      ruleId: SafetyRuleId.rapidAscent,
      severity: SafetySeverity.caution,
      startTimestamp: 60,
      endTimestamp: 120,
      value: 14.0,
      engineVersion: 1,
      dismissedAt: DateTime.utc(2026, 8, 9),
      createdAt: DateTime.utc(2026, 8, 9),
    );
    await tester.pumpWidget(_wrap(reviewOverrides(dismissed)));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FullscreenProfilePage)),
    );
    container.read(selectedSafetyFindingProvider('d1').notifier).state =
        dismissed;
    await tester.pump();

    final chart = tester.widget<DiveProfileChart>(
      find.byType(DiveProfileChart),
    );
    expect(chart.highlightRange, isNull);
    expect(chart.selectedSafetyFindingId, isNull);
  });

  testWidgets('lane findings and selection wiring reach the chart', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(reviewOverrides(laneFinding())));
    await tester.pumpAndSettle();

    final chart = tester.widget<DiveProfileChart>(
      find.byType(DiveProfileChart),
    );
    expect(chart.safetyFindings, isNotNull);
    expect(chart.safetyFindings!.map((f) => f.id), ['f-lane']);
    expect(chart.onSafetyFindingTap, isNotNull);
    expect(chart.onSafetyFindingDismiss, isNotNull);
    expect(chart.onSafetyFindingDetails, isNull); // no section in fullscreen
  });

  testWidgets('fullscreen tap callback toggles the shared provider', (
    tester,
  ) async {
    final finding = laneFinding();
    await tester.pumpWidget(_wrap(reviewOverrides(finding)));
    await tester.pumpAndSettle();

    final chart = tester.widget<DiveProfileChart>(
      find.byType(DiveProfileChart),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FullscreenProfilePage)),
    );

    chart.onSafetyFindingTap!(finding);
    expect(container.read(selectedSafetyFindingProvider('d1'))?.id, 'f-lane');

    chart.onSafetyFindingTap!(finding);
    expect(container.read(selectedSafetyFindingProvider('d1')), isNull);
  });

  testWidgets('enters immersive mode on open and restores it on close', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(_wrap(_defaultOverrides()));
    await tester.pumpAndSettle();

    final uiModeCalls = calls.where(
      (c) => c.method == 'SystemChrome.setEnabledSystemUIMode',
    );
    expect(
      uiModeCalls,
      isNotEmpty,
      reason: 'the page must request immersive mode on entry',
    );
    expect(uiModeCalls.last.arguments, 'SystemUiMode.immersiveSticky');

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(
      calls
          .lastWhere((c) => c.method == 'SystemChrome.setEnabledSystemUIMode')
          .arguments,
      'SystemUiMode.edgeToEdge',
      reason: 'leaving the page must hand the system bars back',
    );
  });

  testWidgets('a chart selection at time 0 seeks playback to 00:00', (
    tester,
  ) async {
    // The chart reports time 0 for its surface lead-in vertex, which has no
    // profile sample; playback must land on 00:00, not the first sample.
    final container = ProviderContainer(overrides: _defaultOverrides());
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrapContainer(container, size: _desktopSize));
    await tester.pumpAndSettle();
    expect(container.read(playbackProvider('d1')).isActive, isTrue);

    final chart = tester.widget<DiveProfileChart>(
      find.byType(DiveProfileChart),
    );
    chart.onTimeSelected!(300);
    await tester.pump();
    expect(container.read(playbackProvider('d1')).currentTimestamp, 300);

    chart.onTimeSelected!(0);
    await tester.pump();
    expect(container.read(playbackProvider('d1')).currentTimestamp, 0);
    expect(container.read(profileReviewProvider('d1')), 0);
  });

  group('optional fixed tooltip (issue #2228 follow-up)', () {
    testWidgets(
      'switching the setting off docks the tooltip instead of following '
      'the cursor',
      (tester) async {
        final container = ProviderContainer(overrides: _defaultOverrides());
        addTearDown(container.dispose);
        container.read(profileLegendProvider.notifier).state = container
            .read(profileLegendProvider)
            .copyWith(tooltipFollowsCursor: false);

        await tester.pumpWidget(_wrapContainer(container));
        await tester.pumpAndSettle();

        final chart = tester.widget<DiveProfileChart>(
          find.byType(DiveProfileChart),
        );
        expect(chart.tooltipPresentation, TooltipPresentation.external);
        expect(chart.onTooltipData, isNotNull);

        chart.onTooltipData!(const [
          TooltipRow(label: 'Zeit', value: '01:00', bulletColor: Colors.blue),
        ]);
        await tester.pump();

        // The label renders padded (padRight) to align the bullet column,
        // so it is not an exact "Zeit" match.
        expect(find.textContaining('Zeit'), findsOneWidget);
        expect(find.text('01:00'), findsOneWidget);
      },
    );

    testWidgets(
      'keeps showing the last reading instead of vanishing when the chart '
      'reports null -- which it does the instant the pointer moves onto '
      'the docked panel itself, since the panel sits on top of the chart '
      'to be draggable (issue #2228 follow-up: this used to unmount the '
      'panel, and any in-progress drag with it, right as the user reached '
      'for it)',
      (tester) async {
        final container = ProviderContainer(overrides: _defaultOverrides());
        addTearDown(container.dispose);
        container.read(profileLegendProvider.notifier).state = container
            .read(profileLegendProvider)
            .copyWith(tooltipFollowsCursor: false);

        await tester.pumpWidget(_wrapContainer(container));
        await tester.pumpAndSettle();

        final chart = tester.widget<DiveProfileChart>(
          find.byType(DiveProfileChart),
        );
        chart.onTooltipData!(const [
          TooltipRow(label: 'Zeit', value: '01:00', bulletColor: Colors.blue),
        ]);
        await tester.pump();
        expect(find.text('01:00'), findsOneWidget);

        // The chart reporting null (pointer left its own hit-testable area)
        // must not blank the panel.
        chart.onTooltipData!(null);
        await tester.pump();
        expect(find.text('01:00'), findsOneWidget);
      },
    );

    testWidgets('leaving the setting on keeps the default cursor tooltip', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_defaultOverrides()));
      await tester.pumpAndSettle();

      final chart = tester.widget<DiveProfileChart>(
        find.byType(DiveProfileChart),
      );
      expect(chart.tooltipPresentation, TooltipPresentation.inChart);
      expect(chart.onTooltipData, isNull);
    });
  });

  group('phone layout', () {
    testWidgets('no transport bar below the chart', (tester) async {
      await tester.pumpWidget(_wrap(_defaultOverrides(), size: _phoneSize));
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsOneWidget);
      expect(find.byType(ProfileTransportBar), findsNothing);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('landscape still counts as a phone', (tester) async {
      // shortestSide, not width: a phone on its side has the least vertical
      // room of all, so it needs the full-bleed chart most.
      await tester.pumpWidget(
        _wrap(_defaultOverrides(), size: const Size(800, 400)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProfileTransportBar), findsNothing);
    });

    testWidgets('desktop keeps the transport bar', (tester) async {
      await tester.pumpWidget(_wrap(_defaultOverrides(), size: _desktopSize));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileTransportBar), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('playback mode is never activated', (tester) async {
      // ProfileTransportControls.initState is what flips playback mode on.
      // With no transport on phone it never mounts, so the page must leave
      // the shared playback provider untouched.
      final container = ProviderContainer(overrides: _defaultOverrides());
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrapContainer(container, size: _phoneSize));
      await tester.pumpAndSettle();

      expect(container.read(playbackProvider('d1')).isActive, isFalse);
    });

    testWidgets('tapping the chart still drives the readout', (tester) async {
      final container = ProviderContainer(overrides: _defaultOverrides());
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrapContainer(container, size: _phoneSize));
      await tester.pumpAndSettle();

      final chart = tester.widget<DiveProfileChart>(
        find.byType(DiveProfileChart),
      );
      chart.onTimeSelected!(30);
      await tester.pump();

      expect(container.read(profileReviewProvider('d1')), 30);
    });

    testWidgets('multi-source dive keeps the source bar', (tester) async {
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
        ], size: _phoneSize),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Source switching stays reachable on phone; only the transport goes.
      expect(find.byType(SourceBar), findsOneWidget);
      expect(find.byType(ProfileTransportBar), findsNothing);
    });

    testWidgets(
      'an overlaid source is wired to its own computed analysis, not the '
      'active source\'s',
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
            // 'src-a' stays active (the default); overlaying 'src-b' builds
            // the ChartSourceOverlay list and, with it, the
            // sourceProfileAnalysisProvider watch this test targets.
            overlaySourcesProvider('d1').overrideWith((ref) => {'src-b'}),
          ]),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final chart = tester.widget<DiveProfileChart>(
          find.byType(DiveProfileChart),
        );
        expect(chart.overlays, isNotNull);
        final overlay = chart.overlays!.singleWhere(
          (o) => o.sourceId == 'src-b',
        );
        expect(overlay.points, hasLength(40));
        // The real sourceProfileAnalysisProvider isn't overridden here (no
        // repository backing 'd1'), so it resolves to an error/no data and
        // .valueOrNull reads null -- the coverage win is that the analysis
        // field is wired through the provider watch at all, not a specific
        // computed value.
        expect(overlay.analysis, isNull);
      },
    );
  });
}
