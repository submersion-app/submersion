import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_range_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/range_stats_panel.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final _profile = List.generate(
  61,
  (i) => DiveProfilePoint(
    timestamp: i * 10,
    depth: 10.0 + i % 5,
    temperature: 20.0 + i % 3,
  ),
);

Future<void> _pumpPanel(
  WidgetTester tester, {
  required double width,
  int? maxColumns,
}) async {
  tester.view.physicalSize = Size(width, 600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(rangeSelectionProvider('d1').notifier)
    ..initialize(600)
    ..enableRangeMode();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: maxColumns == null
              ? RangeStatsPanel(
                  diveId: 'd1',
                  profile: _profile,
                  units: const UnitFormatter(AppSettings()),
                  tanks: const [],
                )
              : RangeStatsPanel(
                  diveId: 'd1',
                  profile: _profile,
                  units: const UnitFormatter(AppSettings()),
                  tanks: const [],
                  maxColumns: maxColumns,
                ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Whether the fifth stat (Avg Depth) shares a row with the first (Elapsed).
bool _fifthStatOnFirstRow(WidgetTester tester) =>
    tester.getTopLeft(find.text('Avg Depth')).dy ==
    tester.getTopLeft(find.text('Elapsed')).dy;

void main() {
  testWidgets('keeps four columns by default, however wide it is', (
    tester,
  ) async {
    await _pumpPanel(tester, width: 1400);

    expect(_fifthStatOnFirstRow(tester), isFalse);
  });

  testWidgets('a higher maxColumns spreads the stats across a wide strip', (
    tester,
  ) async {
    await _pumpPanel(tester, width: 1400, maxColumns: 8);

    expect(_fifthStatOnFirstRow(tester), isTrue);
    // The eighth stat still fits the first row; the ninth wraps, because
    // the column count stops at maxColumns however wide the strip is.
    final firstRow = tester.getTopLeft(find.text('Elapsed')).dy;
    expect(tester.getTopLeft(find.text('Max Ascent')).dy, firstRow);
    expect(tester.getTopLeft(find.text('Min Temp')).dy, greaterThan(firstRow));
  });

  testWidgets('never drops below four columns on a narrow screen', (
    tester,
  ) async {
    // Too narrow for a fifth 120px stat. (Not phone-narrow: the test font
    // draws every glyph as a wide box and would overflow the header.)
    await _pumpPanel(tester, width: 500, maxColumns: 8);

    expect(_fifthStatOnFirstRow(tester), isFalse);
    expect(
      tester.getTopLeft(find.text('Max Depth')).dy,
      tester.getTopLeft(find.text('Elapsed')).dy,
    );
  });
}
