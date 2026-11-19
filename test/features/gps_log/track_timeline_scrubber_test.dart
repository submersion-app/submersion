import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_timeline_scrubber.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The scrubber reads the diver's 12h/24h preference, so it needs settings.
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(TimeFormat format)
    : super(AppSettings(timeFormat: format));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const int _startMs = 1700000000000;
const int _endMs = 1700003600000;

Future<void> _pump(
  WidgetTester tester, {
  required TrackScrubberMode mode,
  int startMs = _startMs,
  int endMs = _endMs,
  void Function(int, int)? onChanged,
  void Function(int, int)? onChangeEnd,
  int? initialStartMs,
  int? initialEndMs,
  TimeFormat timeFormat = TimeFormat.twentyFourHour,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _TestSettingsNotifier(timeFormat),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: TrackTimelineScrubber(
            startMs: startMs,
            endMs: endMs,
            mode: mode,
            onChanged: onChanged ?? (_, _) {},
            onChangeEnd: onChangeEnd,
            initialStartMs: initialStartMs,
            initialEndMs: initialEndMs,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders a range slider in trim mode', (tester) async {
    await _pump(tester, mode: TrackScrubberMode.range);
    expect(find.byType(RangeSlider), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('renders a single slider in split mode', (tester) async {
    await _pump(tester, mode: TrackScrubberMode.single);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byType(RangeSlider), findsNothing);
  });

  testWidgets('reports millisecond values, not slider fractions', (
    tester,
  ) async {
    int? reportedStart;
    await _pump(
      tester,
      mode: TrackScrubberMode.range,
      onChanged: (s, _) => reportedStart = s,
    );
    await tester.drag(find.byType(RangeSlider), const Offset(40, 0));
    await tester.pumpAndSettle();

    expect(reportedStart, isNotNull);
    expect(reportedStart, greaterThanOrEqualTo(_startMs));
    expect(reportedStart, lessThanOrEqualTo(_endMs));
  });

  testWidgets('labels the ends with wall-clock times, not device-local', (
    tester,
  ) async {
    // The times belong to the recording device's wall clock; formatting via
    // toLocal() would shift them for anyone reviewing from another zone.
    await _pump(
      tester,
      mode: TrackScrubberMode.range,
      startMs: DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch,
      endMs: DateTime.utc(2026, 5, 22, 12).millisecondsSinceEpoch,
    );
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
  });

  testWidgets('labels honour the 12-hour preference', (tester) async {
    // DateFormat.Hm() hardcoded a 24-hour clock, ignoring the setting.
    await _pump(
      tester,
      mode: TrackScrubberMode.range,
      startMs: DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch,
      endMs: DateTime.utc(2026, 5, 22, 13).millisecondsSinceEpoch,
      timeFormat: TimeFormat.twelveHour,
    );
    expect(find.text('08:00'), findsNothing);
    expect(find.textContaining('8:00'), findsOneWidget);
    expect(find.textContaining('1:00'), findsOneWidget);
  });

  testWidgets('handles a zero-length span without asserting', (tester) async {
    await _pump(
      tester,
      mode: TrackScrubberMode.range,
      startMs: _startMs,
      endMs: _startMs,
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(RangeSlider), findsNothing);
  });

  testWidgets('re-anchors the handles when the span narrows', (tester) async {
    // Applying a trim shrinks effectivePoints, so the panel rebuilds with a
    // narrower span while this State survives. The handles were seeded once,
    // so they stayed on the old span - and Slider asserts when its value
    // falls outside min..max, taking the page down rather than just looking
    // wrong.
    int? reportedStart;
    final wide = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch;
    final wideEnd = DateTime.utc(2026, 5, 22, 18).millisecondsSinceEpoch;
    final narrow = DateTime.utc(2026, 5, 22, 14).millisecondsSinceEpoch;

    Widget host(int startMs, int endMs) => ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _TestSettingsNotifier(TimeFormat.twentyFourHour),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: TrackTimelineScrubber(
            startMs: startMs,
            endMs: endMs,
            mode: TrackScrubberMode.range,
            onChanged: (s, _) => reportedStart = s,
          ),
        ),
      ),
    );

    await tester.pumpWidget(host(wide, wideEnd));
    await tester.pumpAndSettle();

    // The trim lands: same widget, narrower span.
    await tester.pumpWidget(host(narrow, wideEnd));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
    expect(slider.values.start, greaterThanOrEqualTo(narrow.toDouble()));
    expect(slider.values.end, lessThanOrEqualTo(wideEnd.toDouble()));

    await tester.drag(find.byType(RangeSlider), const Offset(20, 0));
    await tester.pumpAndSettle();
    expect(reportedStart, greaterThanOrEqualTo(narrow));
  });

  testWidgets('an unchanged span leaves a dragged handle alone', (
    tester,
  ) async {
    // Only a span change re-anchors; an ordinary parent rebuild must not
    // snap the handle the diver just moved back to the start.
    await _pump(tester, mode: TrackScrubberMode.range);
    // Grab the START thumb specifically: a drag from the widget centre is
    // equidistant and RangeSlider picks the end one.
    final box = tester.getRect(find.byType(RangeSlider));
    await tester.dragFrom(
      Offset(box.left + 24, box.center.dy),
      const Offset(40, 0),
    );
    await tester.pumpAndSettle();
    final moved = tester
        .widget<RangeSlider>(find.byType(RangeSlider))
        .values
        .start;
    expect(moved, greaterThan(_startMs.toDouble()));

    await tester.pump();
    expect(
      tester.widget<RangeSlider>(find.byType(RangeSlider)).values.start,
      moved,
    );
  });

  testWidgets('onChangeEnd fires once per drag, with the values it ended on', (
    tester,
  ) async {
    final changes = <(int, int)>[];
    final ends = <(int, int)>[];
    await _pump(
      tester,
      mode: TrackScrubberMode.range,
      onChanged: (s, e) => changes.add((s, e)),
      onChangeEnd: (s, e) => ends.add((s, e)),
    );

    final slider = tester.getRect(find.byType(RangeSlider));
    final gesture = await tester.startGesture(
      Offset(slider.left + 24, slider.center.dy),
    );
    for (var i = 1; i <= 5; i++) {
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(changes.length, greaterThan(1));
    expect(ends, hasLength(1));
    expect(ends.single, changes.last);
  });

  testWidgets('a range starts at the bounds it is given, inside the span', (
    tester,
  ) async {
    await _pump(
      tester,
      mode: TrackScrubberMode.range,
      initialStartMs: _startMs + 600000,
      initialEndMs: _endMs + 999999,
    );

    final values = tester.widget<RangeSlider>(find.byType(RangeSlider)).values;
    expect(values.start, (_startMs + 600000).toDouble());
    expect(values.end, _endMs.toDouble());
  });

  testWidgets('the handles follow new starting bounds over the same span', (
    tester,
  ) async {
    Widget host(int? start) => ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _TestSettingsNotifier(TimeFormat.twentyFourHour),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: TrackTimelineScrubber(
            startMs: _startMs,
            endMs: _endMs,
            initialStartMs: start,
            mode: TrackScrubberMode.range,
            onChanged: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(host(_startMs + 600000));
    await tester.pumpWidget(host(_startMs + 1200000));
    await tester.pumpAndSettle();

    final values = tester.widget<RangeSlider>(find.byType(RangeSlider)).values;
    expect(values.start, (_startMs + 1200000).toDouble());
  });
}
