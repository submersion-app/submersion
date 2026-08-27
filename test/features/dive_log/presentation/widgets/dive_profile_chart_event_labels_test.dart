import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Event-label placement on the rendered chart: labels are anchored below
/// the profile depth at the event time (not pinned to the plot top where the
/// end-of-dive tail lives), flipped inward at the right edge, staggered when
/// they would overlap, and pixel-deduped when events are seconds apart.

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 20-minute dive: descend, bottom time, ascend with a shallow tail at the
/// end (the classic shape whose tail the old top-pinned labels buried).
List<DiveProfilePoint> _makeProfile() {
  return List.generate(41, (i) {
    final t = i * 30; // 0..1200 s
    final double depth;
    if (t < 180) {
      depth = 30.0 * t / 180; // descent
    } else if (t < 900) {
      depth = 30; // bottom
    } else if (t < 1110) {
      depth = 30.0 * (1110 - t) / 210; // ascent
    } else {
      depth = 4; // shallow safety-stop tail
    }
    return DiveProfilePoint(timestamp: t, depth: depth);
  });
}

ProfileEvent _event(
  int timestamp,
  ProfileEventType type, {
  EventSeverity severity = EventSeverity.info,
}) => ProfileEvent(
  id: 'e$timestamp',
  diveId: 'd1',
  timestamp: timestamp,
  eventType: type,
  severity: severity,
  createdAt: DateTime(2026),
);

Widget _buildChart(List<ProfileEvent> events) {
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
          child: DiveProfileChart(profile: _makeProfile(), events: events),
        ),
      ),
    ),
  );
}

List<VerticalLine> _eventLines(WidgetTester tester) {
  final data = tester.widget<LineChart>(find.byType(LineChart).first).data;
  // Event lines are the dashed ones; cursor/highlight lines are not dashed.
  return data.extraLinesData.verticalLines
      .where((l) => l.dashArray != null)
      .toList();
}

void main() {
  testWidgets('labels anchor below the profile depth, never pinned to the '
      'surface line', (tester) async {
    await tester.pumpWidget(
      _buildChart([
        _event(300, ProfileEventType.maxDepth),
        _event(930, ProfileEventType.ascentStart),
      ]),
    );
    await tester.pumpAndSettle();

    final lines = _eventLines(tester);
    expect(lines, hasLength(2));
    for (final line in lines) {
      expect(line.label.show, isTrue);
      expect(
        line.label.padding.resolve(TextDirection.ltr).top,
        greaterThan(0),
        reason: 'labels must sit below the curve, not on the plot top edge',
      );
    }
  });

  testWidgets('tail-cluster labels near the dive end stay inside the plot '
      'and do not overlap each other', (tester) async {
    await tester.pumpWidget(
      _buildChart([
        _event(900, ProfileEventType.ascentStart),
        _event(
          1020,
          ProfileEventType.ascentRateWarning,
          severity: EventSeverity.warning,
        ),
        _event(1140, ProfileEventType.safetyStopStart),
      ]),
    );
    await tester.pumpAndSettle();

    final lines = _eventLines(tester);
    expect(lines, hasLength(3));

    // Reconstruct label rects the same way the chart maps placements.
    final rects = <Rect>[];
    final data = tester.widget<LineChart>(find.byType(LineChart).first).data;
    final chartSize = tester.getSize(find.byType(LineChart).first);
    for (final line in lines) {
      if (!line.label.show) continue;
      final text = line.label.labelResolver(line);
      final painter = TextPainter(
        text: TextSpan(text: text, style: const TextStyle(fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      final padding = line.label.padding.resolve(TextDirection.ltr);
      // Approximate x from the data-space fraction; exact plot insets are
      // irrelevant for an overlap check between labels. All labels use
      // Alignment.topLeft with the horizontal position encoded in
      // padding.right (drawn left edge = x - padding.right - textWidth).
      final xFrac = (line.x - data.minX) / (data.maxX - data.minX);
      final x = xFrac * chartSize.width;
      final left = x - padding.right - painter.width;
      rects.add(
        Rect.fromLTWH(left, padding.top, painter.width, painter.height),
      );
      painter.dispose();
    }
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(
          rects[i].overlaps(rects[j]),
          isFalse,
          reason: 'labels $i and $j must not overlap',
        );
      }
    }
  });

  testWidgets('an event at the very end flips its label left of the line '
      'instead of clipping at the right edge', (tester) async {
    await tester.pumpWidget(
      _buildChart([_event(1195, ProfileEventType.safetyStopEnd)]),
    );
    await tester.pumpAndSettle();

    final lines = _eventLines(tester);
    expect(lines, hasLength(1));
    // The drawn left edge is x - padding.right - textWidth; a label pushed
    // fully left of its line carries padding.right >= the flip gap, instead
    // of the centered layout's negative padding (-textWidth / 2).
    final padding = lines.first.label.padding.resolve(TextDirection.ltr);
    expect(
      padding.right,
      greaterThanOrEqualTo(4),
      reason: 'the label text must sit left of the line, not centered on it',
    );
  });

  testWidgets('events seconds apart collapse to the most severe one', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildChart([
        _event(1000, ProfileEventType.ascentStart),
        _event(
          1003,
          ProfileEventType.ascentRateWarning,
          severity: EventSeverity.warning,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    final lines = _eventLines(tester);
    expect(
      lines,
      hasLength(1),
      reason: '3 s apart is sub-pixel at phone widths; keep one line',
    );
    expect(lines.first.x, 1003.0, reason: 'the warning outranks the info');
  });
}
