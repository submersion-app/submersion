import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/profile_markers_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The external cursor ([DiveProfileChart.highlightedTimestamp]) must feed the
/// same readout the chart emits for a hover, so the fullscreen page's card
/// follows playback and minimap scrubbing (issue #2180). Before this, only
/// fl_chart's touchCallback ever emitted rows, leaving the card frozen on the
/// last hovered sample while the cursor line swept the dive.

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<DiveProfilePoint> _profile({int points = 10, double depthScale = 3.0}) =>
    List.generate(
      points,
      (i) => DiveProfilePoint(
        timestamp: i * 30,
        depth: (i < points / 2 ? i * depthScale : (points - i) * depthScale),
        temperature: 20,
      ),
    );

/// A profile whose first sample sits exactly one interval in, which is what
/// [shouldDrawSurfaceLeadIn] requires: the chart then draws a synthetic
/// surface vertex at t=0 ahead of it.
List<DiveProfilePoint> _leadInProfile() => List.generate(
  10,
  (i) => DiveProfilePoint(
    timestamp: (i + 1) * 10,
    depth: i * 2.0,
    temperature: 20,
  ),
);

/// One instance, reused across pumps. The chart treats a new list as a new
/// profile (identity, as the detail page and fullscreen page both rely on,
/// since they pass a cached provider value), so a harness that rebuilt this
/// per pump would look like a source switch on every frame.
final _standardProfile = _profile();

Widget _chart({
  required void Function(List<TooltipRow>? rows) onTooltipData,
  int? highlightedTimestamp,
  bool tooltipBelow = true,
  List<DiveProfilePoint>? profile,
  List<ProfileMarker>? markers,
}) {
  final points = profile ?? _standardProfile;
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: DiveProfileChart(
            profile: points,
            diveDurationSeconds: points.last.timestamp,
            tooltipPresentation: tooltipBelow
                ? TooltipPresentation.external
                : TooltipPresentation.inChart,
            onTooltipData: onTooltipData,
            highlightedTimestamp: highlightedTimestamp,
            markers: markers,
            showMaxDepthMarker: markers != null,
          ),
        ),
      ),
    ),
  );
}

/// The value of the row labelled [label], or null when no such row exists.
String? _rowValue(List<TooltipRow>? rows, String label) =>
    rows?.where((r) => r.label == label).map((r) => r.value).firstOrNull;

void main() {
  testWidgets('moving the external cursor emits rows for that sample', (
    tester,
  ) async {
    List<TooltipRow>? rows;
    await tester.pumpWidget(_chart(onTooltipData: (r) => rows = r));
    await tester.pumpAndSettle();

    expect(rows, isNull, reason: 'no cursor yet, so nothing to report');

    // 150s is sample index 5 of the 30s-spaced profile.
    await tester.pumpWidget(
      _chart(onTooltipData: (r) => rows = r, highlightedTimestamp: 150),
    );
    await tester.pumpAndSettle();

    expect(rows, isNotNull);
    expect(_rowValue(rows, 'Time'), '2:30');
    expect(_rowValue(rows, 'Depth'), isNotNull);
  });

  testWidgets('each cursor move re-emits for the new sample', (tester) async {
    List<TooltipRow>? rows;
    await tester.pumpWidget(_chart(onTooltipData: (r) => rows = r));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _chart(onTooltipData: (r) => rows = r, highlightedTimestamp: 60),
    );
    await tester.pumpAndSettle();
    expect(_rowValue(rows, 'Time'), '1:00');

    await tester.pumpWidget(
      _chart(onTooltipData: (r) => rows = r, highlightedTimestamp: 240),
    );
    await tester.pumpAndSettle();
    expect(_rowValue(rows, 'Time'), '4:00');
  });

  testWidgets('a cursor already set on the first build is not reported', (
    tester,
  ) async {
    // Only a cursor MOVE reports. The dive-detail panel feeds its own shared
    // tracking index back in as the cursor, and that index outlives the page,
    // so reporting on first build would pop its hover tooltip open on a dive
    // the user has merely scrubbed before. Playback and the minimap both
    // start from no cursor, so neither depends on this.
    List<TooltipRow>? rows;
    await tester.pumpWidget(
      _chart(onTooltipData: (r) => rows = r, highlightedTimestamp: 150),
    );
    await tester.pumpAndSettle();

    expect(rows, isNull);
  });

  testWidgets('a cursor between samples reports the sample at or before it', (
    tester,
  ) async {
    List<TooltipRow>? rows;
    await tester.pumpWidget(_chart(onTooltipData: (r) => rows = r));
    await tester.pumpAndSettle();

    // 155s falls between index 5 (150s) and index 6 (180s).
    await tester.pumpWidget(
      _chart(onTooltipData: (r) => rows = r, highlightedTimestamp: 155),
    );
    await tester.pumpAndSettle();

    expect(_rowValue(rows, 'Time'), '2:30');
  });

  testWidgets('clearing the cursor keeps the last values (no null emit)', (
    tester,
  ) async {
    List<TooltipRow>? rows;
    var emissions = 0;
    void capture(List<TooltipRow>? r) {
      emissions++;
      rows = r;
    }

    await tester.pumpWidget(_chart(onTooltipData: capture));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _chart(onTooltipData: capture, highlightedTimestamp: 150),
    );
    await tester.pumpAndSettle();
    final afterCursor = emissions;
    expect(rows, isNotNull);

    await tester.pumpWidget(_chart(onTooltipData: capture));
    await tester.pumpAndSettle();

    expect(
      emissions,
      afterCursor,
      reason: 'clearing the cursor must not clear the card',
    );
    expect(_rowValue(rows, 'Time'), '2:30');
  });

  testWidgets('a settled cursor emits once, however often the chart rebuilds', (
    tester,
  ) async {
    // The consumer rebuilds on these rows, and that rebuild reaches the chart
    // again: emitting on anything but a changed cursor would loop.
    var emissions = 0;
    await tester.pumpWidget(_chart(onTooltipData: (_) => emissions++));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tester.pumpWidget(
        _chart(onTooltipData: (_) => emissions++, highlightedTimestamp: 150),
      );
      await tester.pumpAndSettle();
    }

    expect(emissions, 1);
  });

  testWidgets('crossing off the surface lead-in re-emits at the same index', (
    tester,
  ) async {
    // The synthetic surface vertex and the first real sample are both index 0
    // on a lead-in profile, so a dedupe keyed on the index alone would strand
    // the card at 0:00 until the second sample.
    List<TooltipRow>? rows;
    final profile = _leadInProfile();
    await tester.pumpWidget(
      _chart(onTooltipData: (r) => rows = r, profile: profile),
    );
    await tester.pumpAndSettle();

    // Before the first sample: the readout describes the surface at t=0.
    await tester.pumpWidget(
      _chart(
        onTooltipData: (r) => rows = r,
        profile: profile,
        highlightedTimestamp: 5,
      ),
    );
    await tester.pumpAndSettle();
    expect(_rowValue(rows, 'Time'), '0:00');

    // On the first sample: same index, different reading.
    await tester.pumpWidget(
      _chart(
        onTooltipData: (r) => rows = r,
        profile: profile,
        highlightedTimestamp: 10,
      ),
    );
    await tester.pumpAndSettle();
    expect(_rowValue(rows, 'Time'), '0:10');
  });

  testWidgets('replacing the profile under a still cursor re-reports it', (
    tester,
  ) async {
    // Switching source in fullscreen keeps the review timestamp but changes
    // which reading it names; the card must not keep describing the old one.
    List<TooltipRow>? rows;
    await tester.pumpWidget(_chart(onTooltipData: (r) => rows = r));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _chart(onTooltipData: (r) => rows = r, highlightedTimestamp: 150),
    );
    await tester.pumpAndSettle();
    final firstDepth = _rowValue(rows, 'Depth');
    expect(firstDepth, isNotNull);

    // Same cursor, deeper profile: the depth at 150s must be restated.
    await tester.pumpWidget(
      _chart(
        onTooltipData: (r) => rows = r,
        highlightedTimestamp: 150,
        profile: _profile(depthScale: 6.0),
      ),
    );
    await tester.pumpAndSettle();

    expect(_rowValue(rows, 'Time'), '2:30');
    expect(_rowValue(rows, 'Depth'), isNot(firstDepth));
  });

  testWidgets('a profile swap with nothing reported yet stays silent', (
    tester,
  ) async {
    // The detail panel carries a shared tracking index across pages; a source
    // switch there must not open a tooltip the user never asked for.
    var emissions = 0;
    await tester.pumpWidget(
      _chart(onTooltipData: (_) => emissions++, highlightedTimestamp: 150),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _chart(
        onTooltipData: (_) => emissions++,
        highlightedTimestamp: 150,
        profile: _profile(depthScale: 6.0),
      ),
    );
    await tester.pumpAndSettle();

    expect(emissions, 0);
  });

  testWidgets('a panel-style echo does not overwrite a surface-hover readout', (
    tester,
  ) async {
    // The detail panel feeds onPointSelected back in as highlightedTimestamp,
    // and an index can only echo as a sample's timestamp. For the synthetic
    // surface vertex that is the FIRST SAMPLE's timestamp, so resolving the
    // echo would turn a surface hover into a sample hover.
    final profile = _leadInProfile();
    List<TooltipRow>? rows;
    int? trackedIndex;

    Widget build() => ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: DiveProfileChart(
              profile: profile,
              diveDurationSeconds: profile.last.timestamp,
              tooltipPresentation: TooltipPresentation.external,
              onTooltipData: (r) {
                if (r != null && r.isNotEmpty) rows = r;
              },
              onPointSelected: (i) => trackedIndex = i,
              highlightedTimestamp:
                  trackedIndex != null && trackedIndex! < profile.length
                  ? profile[trackedIndex!].timestamp
                  : null,
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    // The lead-in vertex is at t=0 and depth 0: the top-left of the plot, not
    // its centre, since this profile descends left to right.
    final plot = tester.getRect(find.byType(LineChart).first);
    final gesture = await tester.startGesture(
      Offset(plot.left + 50, plot.top + 15),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(1, 0));
    await tester.pump();

    // Rebuild with the echoed cursor, exactly as the panel would.
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    expect(trackedIndex, 0, reason: 'the lead-in vertex selects index 0');
    expect(
      _rowValue(rows, 'Time'),
      '0:00',
      reason: 'the echo must not restate the surface hover as sample 1',
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('no external emission when the chart paints its own tooltip', (
    tester,
  ) async {
    List<TooltipRow>? rows;
    await tester.pumpWidget(
      _chart(onTooltipData: (r) => rows = r, tooltipBelow: false),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _chart(
        onTooltipData: (r) => rows = r,
        tooltipBelow: false,
        highlightedTimestamp: 150,
      ),
    );
    await tester.pumpAndSettle();

    expect(rows, isNull);
  });

  // The depth line is tagged ChartOnlyMetric.depth, and a tooltip row renders
  // bold when its metric equals the hovered line's tag. A Depth row without
  // that metric could never match, so hovering the depth line left its row
  // plain while every other metric's row lit up.
  testWidgets('the Depth row carries the depth line\'s hover identity', (
    tester,
  ) async {
    List<TooltipRow>? rows;
    await tester.pumpWidget(_chart(onTooltipData: (r) => rows = r));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _chart(onTooltipData: (r) => rows = r, highlightedTimestamp: 150),
    );
    await tester.pumpAndSettle();

    final depthRow = rows?.where((r) => r.label == 'Depth').firstOrNull;
    expect(depthRow, isNotNull);
    expect(depthRow!.metric, ChartOnlyMetric.depth);
  });

  testWidgets('the Depth row keeps its hover identity on the surface lead-in', (
    tester,
  ) async {
    List<TooltipRow>? rows;
    final profile = _leadInProfile();
    await tester.pumpWidget(
      _chart(onTooltipData: (r) => rows = r, profile: profile),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _chart(
        onTooltipData: (r) => rows = r,
        profile: profile,
        highlightedTimestamp: 5,
      ),
    );
    await tester.pumpAndSettle();

    expect(_rowValue(rows, 'Time'), '0:00');
    final depthRow = rows?.where((r) => r.label == 'Depth').firstOrNull;
    expect(depthRow?.metric, ChartOnlyMetric.depth);
  });

  // On the lead-in, rows whose value is only carried over from the first
  // sample are rebuilt with an "interpolated" value. The rebuilt row must
  // keep its metric, or hovering that line at t=0 would leave its row plain.
  testWidgets('an interpolated lead-in row keeps its hover identity', (
    tester,
  ) async {
    List<TooltipRow>? rows;
    final profile = _leadInProfile();
    await tester.pumpWidget(
      _chart(onTooltipData: (r) => rows = r, profile: profile),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _chart(
        onTooltipData: (r) => rows = r,
        profile: profile,
        highlightedTimestamp: 5,
      ),
    );
    await tester.pumpAndSettle();

    expect(_rowValue(rows, 'Time'), '0:00');
    final tempRow = rows?.where((r) => r.label == 'Temp').firstOrNull;
    expect(tempRow, isNotNull);
    expect(
      tempRow!.value,
      endsWith('(interpolated)'),
      reason: 'the row must actually have been rebuilt as interpolated',
    );
    expect(tempRow.metric, ProfileRightAxisMetric.temperature);
  });

  // A marker row is drawn with a diamond bullet; rebuilding it as
  // interpolated on the lead-in must not turn it back into a plain circle.
  testWidgets('an interpolated lead-in marker row keeps its diamond bullet', (
    tester,
  ) async {
    List<TooltipRow>? rows;
    final profile = _leadInProfile();
    const markers = [
      ProfileMarker(timestamp: 0, depth: 0, type: ProfileMarkerType.maxDepth),
    ];
    await tester.pumpWidget(
      _chart(
        onTooltipData: (r) => rows = r,
        profile: profile,
        markers: markers,
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _chart(
        onTooltipData: (r) => rows = r,
        profile: profile,
        markers: markers,
        highlightedTimestamp: 5,
      ),
    );
    await tester.pumpAndSettle();

    expect(_rowValue(rows, 'Time'), '0:00');
    final markerRow = rows?.where((r) => r.label == 'Marker').firstOrNull;
    expect(markerRow, isNotNull);
    expect(markerRow!.value, endsWith('(interpolated)'));
    expect(markerRow.diamondBullet, isTrue);
  });
}
