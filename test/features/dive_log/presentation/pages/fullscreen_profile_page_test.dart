import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/pages/fullscreen_profile_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_playback_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_review_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/draggable_readout_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_transport_bar.dart';
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

  testWidgets('without a saved position the card defaults to the corner the '
      'profile occupies least', (tester) async {
    // Fast descent, long deep bottom, ascent tail rising into the top-right:
    // the old fixed top-right default sat exactly on that tail. For this
    // shape the emptiest corner window is the top-left - the fast descent
    // leaves it almost immediately, while the max-depth bottom line (which
    // normalizes to exactly y = 1.0) fills both bottom corner windows.
    final dive = Dive(
      id: 'd1',
      dateTime: DateTime(2026, 1, 1, 10),
      profile: List.generate(61, (i) {
        final t = i * 10;
        final double depth;
        if (t < 90) {
          depth = 30.0 * t / 90;
        } else if (t < 450) {
          depth = 30;
        } else {
          depth = 30.0 * (600 - t) / 150;
        }
        return DiveProfilePoint(timestamp: t, depth: depth, temperature: 20);
      }),
    );
    final overrides = _defaultOverrides()
      ..removeAt(1)
      ..insert(1, diveProvider(dive.id).overrideWith((ref) async => dive));
    await tester.pumpWidget(_wrap(overrides, size: _phoneSize));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<DraggableReadoutCard>(find.byType(DraggableReadoutCard))
          .initialFraction,
      const Offset(0, 0),
      reason: 'the card must seed at the least occupied corner',
    );
    final closeButton = find.widgetWithIcon(IconButton, Icons.close);
    final closeRect = tester.getRect(closeButton);
    final cardRect = tester.getRect(find.byKey(const ValueKey('readout-card')));
    expect(
      cardRect.top,
      greaterThanOrEqualTo(closeRect.bottom + 8),
      reason: 'the phone readout must clear the close/title row',
    );

    await tester.tap(closeButton);
    await tester.pumpAndSettle();
    expect(find.byType(FullscreenProfilePage), findsNothing);
  });

  testWidgets('phone saved upper-left position clears the close button', (
    tester,
  ) async {
    final overrides = _defaultOverrides()
      ..removeAt(0)
      ..insert(
        0,
        settingsProvider.overrideWith(
          (ref) => _FakeSettingsNotifier(
            const AppSettings(
              fullscreenReadoutCardX: 0,
              fullscreenReadoutCardY: 0,
            ),
          ),
        ),
      );
    await tester.pumpWidget(_wrap(overrides, size: _phoneSize));
    await tester.pumpAndSettle();

    final closeRect = tester.getRect(
      find.widgetWithIcon(IconButton, Icons.close),
    );
    final cardRect = tester.getRect(find.byKey(const ValueKey('readout-card')));
    expect(cardRect.top, greaterThanOrEqualTo(closeRect.bottom + 8));
    expect(
      tester
          .widget<DraggableReadoutCard>(find.byType(DraggableReadoutCard))
          .initialFraction,
      Offset.zero,
      reason: 'the saved fraction stays unchanged inside the safer arena',
    );
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
      chart.onPointSelected!(3);
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
  });
}
