import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/views/timeline_days.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_timeline_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/timeline_control.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

final DayRange _span = (
  start: DateTime(2019, 1, 1),
  end: DateTime(2024, 12, 31),
);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget child, {
  DayRange? span,
  bool noSpan = false,
  DateFormatPreference? dateFormat,
}) async {
  final overrides = await getBaseOverrides(
    settingsNotifier: dateFormat == null
        ? null
        : MockSettingsNotifier(
            AppSettings(
              dateFormat: dateFormat,
              hasAcceptedPlanningDisclaimer: true,
            ),
          ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        connectionsDateSpanProvider.overrideWith(
          (ref) async => noSpan ? null : (span ?? _span),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

RangeSlider _slider(WidgetTester tester) =>
    tester.widget<RangeSlider>(find.byKey(const ValueKey('timeline-slider')));

void main() {
  testWidgets('the label shows the range in the default date format', (
    tester,
  ) async {
    await _pump(tester, const TimelineControl());
    expect(find.text('Jan 1, 2019 to Dec 31, 2024'), findsOneWidget);
  });

  testWidgets('the label follows the diver date format setting', (
    tester,
  ) async {
    await _pump(
      tester,
      const TimelineControl(),
      dateFormat: DateFormatPreference.dMMMYYYY,
    );
    expect(find.text('1 Jan 2019 to 31 Dec 2024'), findsOneWidget);
  });

  testWidgets('dragging updates the label live and commits the release', (
    tester,
  ) async {
    final c = await _pump(tester, const TimelineControl());
    final slider = _slider(tester);
    expect(
      slider.values,
      RangeValues(0, dayIndex(_span.start, _span.end).toDouble()),
    );
    slider.onChangeStart!(slider.values);
    slider.onChanged!(const RangeValues(31, 59));
    await tester.pump();
    expect(find.text('Feb 1, 2019 to Mar 1, 2019'), findsOneWidget);
    expect(c.read(connectionsFilterProvider).endDate, DateTime(2019, 3, 1));

    _slider(tester).onChanged!(const RangeValues(31, 90));
    await tester.pump();
    expect(find.text('Feb 1, 2019 to Apr 1, 2019'), findsOneWidget);
    expect(
      c.read(connectionsFilterProvider).endDate,
      DateTime(2019, 3, 1),
      reason: 'the first range is still loading',
    );
    _slider(tester).onChangeEnd!(const RangeValues(31, 90));
    c.read(connectionsTimelineProvider.notifier)
      ..loadStarted()
      ..loadSettled(failed: false);
    await tester.pump();
    expect(c.read(connectionsFilterProvider).startDate, DateTime(2019, 2, 1));
    expect(c.read(connectionsFilterProvider).endDate, DateTime(2019, 4, 1));
  });

  testWidgets('screen readers hear each thumb as a date', (tester) async {
    await _pump(tester, const TimelineControl());
    expect(_slider(tester).semanticFormatterCallback!(31), 'Feb 1, 2019');
  });

  testWidgets('play and pause toggle, with the tooltip following', (
    tester,
  ) async {
    final c = await _pump(tester, const TimelineControl());
    expect(find.byTooltip('Play timeline'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('timeline-play-button')));
    await tester.pump();
    expect(c.read(connectionsTimelineProvider).playing, isTrue);
    expect(find.byTooltip('Pause'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('timeline-play-button')));
    await tester.pump();
    expect(c.read(connectionsTimelineProvider).playing, isFalse);
    expect(find.byTooltip('Play timeline'), findsOneWidget);
  });

  testWidgets('hidden on a single-day log or with no dives', (tester) async {
    final day = DateTime(2024, 5, 5);
    await _pump(
      tester,
      const ConnectionsTimelineBar(),
      span: (start: day, end: day),
    );
    expect(
      find.byKey(const ValueKey('connections-timeline-bar')),
      findsNothing,
    );
    expect(find.byType(RangeSlider), findsNothing);
    await _pump(tester, const ConnectionsTimelineBar(), noSpan: true);
    expect(
      find.byKey(const ValueKey('connections-timeline-bar')),
      findsNothing,
    );
  });

  for (final (width, expected) in [(390.0, 366.0), (1280.0, 560.0)]) {
    testWidgets('the bar is $expected wide on a $width-wide canvas', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(
        tester,
        const Stack(
          children: [
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: ConnectionsTimelineBar(),
            ),
          ],
        ),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('connections-timeline-bar')))
            .width,
        expected,
      );
    });
  }

  testWidgets('play is disabled with both thumbs on the last day', (
    tester,
  ) async {
    final c = await _pump(tester, const TimelineControl());
    c.read(connectionsFilterProvider.notifier).state = DiveFilterState(
      startDate: _span.end,
      endDate: _span.end,
    );
    await tester.pump();
    final button = tester.widget<IconButton>(
      find.byKey(const ValueKey('timeline-play-button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('the canvas keeps more room for the bar at larger text', (
    tester,
  ) async {
    late double normal;
    late double large;
    await tester.pumpWidget(
      Column(
        children: [
          Builder(
            builder: (context) {
              normal = ConnectionsTimelineBar.reserveOf(context);
              return const SizedBox();
            },
          ),
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Builder(
              builder: (context) {
                large = ConnectionsTimelineBar.reserveOf(context);
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
    expect(normal, 104);
    expect(large, greaterThan(normal + 15));
  });
}
