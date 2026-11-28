import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The chart options' Right axis row (issue #5069): it shows what the axis
/// shows and brings the axis back after "None", which today needs a restart.

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<DiveProfilePoint> _profile({bool temperature = true}) => [
  for (var i = 0; i <= 40; i++)
    DiveProfilePoint(
      timestamp: i * 30,
      depth: i <= 20 ? i * 1.5 : (40 - i) * 1.5,
      temperature: temperature ? 24 - i * 0.1 : null,
      heartRate: 70 + i,
    ),
];

Future<void> _pump(WidgetTester tester, List<DiveProfilePoint> profile) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 1100,
            height: 500,
            child: DiveProfileChart(profile: profile),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ProfileLegend _legend(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(DiveProfileChart)),
).read(profileLegendProvider.notifier);

const _rowKey = ValueKey('chart-options-right-axis');

/// Opens chart options at the Display section and returns the Right axis
/// row's value text.
Future<String?> _openRow(WidgetTester tester) async {
  // A dive with nothing to toggle has no options button, so no row either.
  final options = find.byTooltip('More chart options');
  if (options.evaluate().isEmpty) return null;
  await tester.tap(options.first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Display'));
  await tester.pumpAndSettle();
  final row = find.byKey(_rowKey);
  if (row.evaluate().isEmpty) return null;
  final texts = tester
      .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
      .map((t) => t.data)
      .toList();
  return texts.last;
}

void main() {
  testWidgets('the row shows what the axis shows', (tester) async {
    await _pump(tester, _profile());
    // Temperature hidden: the axis moves to the heart-rate line.
    _legend(tester)
      ..toggleTemperature()
      ..toggleHeartRate();
    await tester.pumpAndSettle();

    expect(await _openRow(tester), 'Heart Rate');
  });

  testWidgets('the row reads None after None is chosen', (tester) async {
    await _pump(tester, _profile());
    _legend(tester).hideRightAxis();
    await tester.pumpAndSettle();

    expect(await _openRow(tester), 'None');
  });

  testWidgets('the row\'s menu checks None after None is chosen', (
    tester,
  ) async {
    await _pump(tester, _profile());
    _legend(tester).hideRightAxis();
    await tester.pumpAndSettle();
    await _openRow(tester);
    await tester.tap(find.byKey(_rowKey));
    await tester.pumpAndSettle();

    final noneItem = find.ancestor(
      of: find.text('None').last,
      matching: find.byType(PopupMenuItem<ProfileRightAxisMetric?>),
    );
    expect(
      find.descendant(of: noneItem, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
  });

  testWidgets('picking a metric from the row restores the axis', (
    tester,
  ) async {
    await _pump(tester, _profile());
    _legend(tester).hideRightAxis();
    await tester.pumpAndSettle();
    expect(find.textContaining('°C'), findsNothing);

    await _openRow(tester);
    await tester.tap(find.byKey(_rowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Temperature').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('°C'), findsWidgets);
    final row = find.byKey(_rowKey);
    expect(
      find.descendant(of: row, matching: find.text('Temperature')),
      findsOneWidget,
    );
  });

  testWidgets('the row reads None when only depth is drawn', (tester) async {
    await _pump(tester, _profile());
    _legend(tester).toggleTemperature();
    await tester.pumpAndSettle();

    expect(await _openRow(tester), 'None');
  });

  testWidgets('no row when the dive has no right-axis metric', (tester) async {
    await _pump(tester, [
      for (var i = 0; i <= 10; i++)
        DiveProfilePoint(timestamp: i * 60, depth: i <= 5 ? i * 3.0 : 30.0 - i),
    ]);

    expect(await _openRow(tester), isNull);
  });
}
