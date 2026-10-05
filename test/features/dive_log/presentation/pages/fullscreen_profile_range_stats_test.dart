import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/fullscreen_profile_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_range_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_transport_bar.dart';
import 'package:submersion/features/dive_log/presentation/widgets/range_selection_overlay.dart';
import 'package:submersion/features/dive_log/presentation/widgets/range_stats_panel.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Range statistics in the fullscreen profile (issue #1577): the same
/// selection the detail page uses, with the stats strip below the chart.

class _FakeSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 61 samples, 10 s apart: the drawn series ends at 600 s.
Dive _dive() => Dive(
  id: 'd1',
  dateTime: DateTime(2026, 1, 1, 10),
  profile: List.generate(
    61,
    (i) => DiveProfilePoint(timestamp: i * 10, depth: 10.0 + i % 5),
  ),
);

ProviderContainer _container() {
  final dive = _dive();
  final container = ProviderContainer(
    overrides: [
      settingsProvider.overrideWith((ref) => _FakeSettingsNotifier()),
      diveProvider(dive.id).overrideWith((ref) async => dive),
      profileAnalysisProvider(dive.id).overrideWith((ref) async => null),
      gasSwitchesProvider(dive.id).overrideWith((ref) async => []),
      tankPressuresProvider(dive.id).overrideWith((ref) async => {}),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pumpPage(
  WidgetTester tester,
  ProviderContainer container, {
  Size size = const Size(1200, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FullscreenProfilePage(diveId: 'd1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

DiveProfileChart _chart(WidgetTester tester) =>
    tester.widget<DiveProfileChart>(find.byType(DiveProfileChart));

final _rangeToggle = find.byTooltip('Range Stats');

void main() {
  testWidgets('keeps the range extent on the drawn series by itself', (
    tester,
  ) async {
    // Nothing else is mounted here to set the extent: the page must not
    // depend on the screen that opened it having done so.
    final container = _container();
    await _pumpPage(tester, container);

    expect(container.read(rangeSelectionProvider('d1')).maxTimestamp, 600);
  });

  testWidgets('the header still fits a 320pt phone with the toggle in it', (
    tester,
  ) async {
    // The toggle widens the fixed-width group ahead of the legend; on the
    // narrowest phones the title gives way instead of the zoom controls
    // overflowing.
    final container = _container();
    await _pumpPage(tester, container, size: const Size(320, 640));

    expect(tester.takeException(), isNull);
    expect(_rangeToggle, findsOneWidget);
  });

  testWidgets('range mode starts off: no handles and no stats strip', (
    tester,
  ) async {
    final container = _container();
    await _pumpPage(tester, container);

    expect(_rangeToggle, findsOneWidget);
    expect(_chart(tester).rangeSelection, isNull);
    expect(find.byType(RangeStatsPanel), findsNothing);
  });

  testWidgets('the toggle shows the handles and the stats strip', (
    tester,
  ) async {
    final container = _container();
    await _pumpPage(tester, container);

    await tester.tap(_rangeToggle);
    await tester.pumpAndSettle();

    final state = container.read(rangeSelectionProvider('d1'));
    expect(state.isEnabled, isTrue);
    // The default selection is the middle half of the drawn series.
    expect(_chart(tester).rangeSelection, (
      startSeconds: 150,
      endSeconds: 450,
      maxSeconds: 600,
    ));
    expect(find.byKey(RangeSelectionOverlay.startHandleKey), findsOneWidget);
    expect(find.byKey(RangeSelectionOverlay.endHandleKey), findsOneWidget);
    expect(find.byType(RangeStatsPanel), findsOneWidget);
    expect(find.text('02:30 - 07:30'), findsOneWidget);

    // Pressing it again turns range mode back off.
    await tester.tap(_rangeToggle);
    await tester.pumpAndSettle();
    expect(container.read(rangeSelectionProvider('d1')).isEnabled, isFalse);
    expect(_chart(tester).rangeSelection, isNull);
    expect(find.byType(RangeStatsPanel), findsNothing);
  });

  testWidgets('dragging a handle moves the shared selection', (tester) async {
    final container = _container();
    await _pumpPage(tester, container);
    await tester.tap(_rangeToggle);
    await tester.pumpAndSettle();

    _chart(tester).onRangeChanged!(120, 360);
    await tester.pumpAndSettle();

    final state = container.read(rangeSelectionProvider('d1'));
    expect((state.startTimestamp, state.endTimestamp), (120, 360));
    expect(find.text('02:00 - 06:00'), findsOneWidget);
  });

  testWidgets('the strip sits below the chart and above the transport bar', (
    tester,
  ) async {
    final container = _container();
    await _pumpPage(tester, container);
    await tester.tap(_rangeToggle);
    await tester.pumpAndSettle();

    final chart = tester.getRect(find.byType(DiveProfileChart));
    final strip = tester.getRect(find.byType(RangeStatsPanel));
    final transport = tester.getRect(find.byType(ProfileTransportBar));
    expect(strip.top, greaterThanOrEqualTo(chart.bottom));
    expect(transport.top, greaterThanOrEqualTo(strip.bottom));
  });

  testWidgets('the strip close button turns range mode off', (tester) async {
    final container = _container();
    await _pumpPage(tester, container);
    await tester.tap(_rangeToggle);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(RangeStatsPanel),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(rangeSelectionProvider('d1')).isEnabled, isFalse);
    expect(find.byType(RangeStatsPanel), findsNothing);
    expect(_chart(tester).rangeSelection, isNull);
  });

  testWidgets('a range picked on the detail page carries into fullscreen', (
    tester,
  ) async {
    final container = _container();
    container.read(rangeSelectionProvider('d1').notifier)
      ..initialize(600)
      ..enableRangeMode()
      ..setRange(100, 300);

    await _pumpPage(tester, container);

    expect(_chart(tester).rangeSelection, (
      startSeconds: 100,
      endSeconds: 300,
      maxSeconds: 600,
    ));
    expect(find.text('01:40 - 05:00'), findsOneWidget);
  });

  testWidgets('closing fullscreen leaves the range as the diver set it', (
    tester,
  ) async {
    final container = _container();
    await _pumpPage(tester, container);
    await tester.tap(_rangeToggle);
    await tester.pumpAndSettle();
    _chart(tester).onRangeChanged!(120, 360);
    await tester.pumpAndSettle();

    // The page's own close button, not the strip's.
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(find.byType(FullscreenProfilePage), findsNothing);

    final state = container.read(rangeSelectionProvider('d1'));
    expect(state.isEnabled, isTrue);
    expect((state.startTimestamp, state.endTimestamp), (120, 360));
  });
}
