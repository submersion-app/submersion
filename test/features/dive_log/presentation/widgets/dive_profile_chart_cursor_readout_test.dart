import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
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

List<DiveProfilePoint> _profile({int points = 10}) => List.generate(
  points,
  (i) => DiveProfilePoint(
    timestamp: i * 30,
    depth: i < points / 2 ? i * 3.0 : (points - i) * 3.0,
    temperature: 20,
  ),
);

Widget _chart({
  required void Function(List<TooltipRow>? rows) onTooltipData,
  int? highlightedTimestamp,
  bool tooltipBelow = true,
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: DiveProfileChart(
            profile: _profile(),
            diveDurationSeconds: 270,
            tooltipBelow: tooltipBelow,
            onTooltipData: onTooltipData,
            highlightedTimestamp: highlightedTimestamp,
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
}
