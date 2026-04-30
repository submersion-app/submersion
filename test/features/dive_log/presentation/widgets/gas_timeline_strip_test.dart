import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/gas_usage_segments_service.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_timeline_strip.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

GasUsageSegment _seg({
  required int start,
  required int end,
  double o2 = 21,
  double he = 0,
  String? label,
}) {
  final mix = GasMix(o2: o2, he: he);
  return GasUsageSegment(
    startSeconds: start,
    endSeconds: end,
    gasMix: mix,
    label: label ?? mix.name,
  );
}

/// Wraps [GasTimelineStrip] in a fixed-width box with explicit zero padding
/// so tests aren't affected by [DiveProfileChart] axis-size calculations.
Widget _strip(
  List<GasUsageSegment> segments,
  int duration, {
  double width = 400,
  double? visibleMin,
  double? visibleMax,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: width,
        child: GasTimelineStrip(
          segments: segments,
          diveDurationSeconds: duration,
          leftPadding: 0,
          rightPadding: 0,
          visibleMinSeconds: visibleMin,
          visibleMaxSeconds: visibleMax,
        ),
      ),
    ),
  );
}

void main() {
  group('GasTimelineStrip guards', () {
    testWidgets('renders nothing when segments list is empty', (tester) async {
      await tester.pumpWidget(_strip([], 1800));
      expect(find.byType(GasTimelineStrip), findsOneWidget);
      // Guard returns SizedBox.shrink() — no Tooltip/segment blocks are built
      expect(
        find.descendant(
          of: find.byType(GasTimelineStrip),
          matching: find.byType(Tooltip),
        ),
        findsNothing,
      );
    });

    testWidgets('renders nothing when diveDurationSeconds is zero', (
      tester,
    ) async {
      await tester.pumpWidget(_strip([_seg(start: 0, end: 100)], 0));
      // Guard returns SizedBox.shrink() — no Tooltip/segment blocks are built
      expect(
        find.descendant(
          of: find.byType(GasTimelineStrip),
          matching: find.byType(Tooltip),
        ),
        findsNothing,
      );
    });
  });

  group('GasTimelineStrip rendering', () {
    testWidgets('renders a Tooltip for each segment', (tester) async {
      await tester.pumpWidget(
        _strip([
          _seg(start: 0, end: 1500, o2: 21, label: 'Air'),
          _seg(start: 1500, end: 3000, o2: 50, label: 'EAN50'),
        ], 3000),
      );
      expect(find.byType(Tooltip), findsNWidgets(2));
      expect(
        find.byWidgetPredicate((w) => w is Tooltip && w.message == 'Air'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is Tooltip && w.message == 'EAN50'),
        findsOneWidget,
      );
    });

    testWidgets('shows label text for a wide segment', (tester) async {
      // 400px wide, single segment covering full dive → block is 400px > 36px
      await tester.pumpWidget(
        _strip([_seg(start: 0, end: 3000, label: 'Air')], 3000),
      );
      expect(find.text('Air'), findsOneWidget);
    });

    testWidgets('hides label text for a narrow segment', (tester) async {
      // 10% of 400px = 40px — but with a very short segment it should be ≤ 36px
      // Use 8% → 32px wide block
      await tester.pumpWidget(
        _strip(
          [
            _seg(start: 0, end: 240, label: 'Air'),
            _seg(start: 240, end: 3000, label: 'EAN50'),
          ],
          3000,
          width: 400,
        ),
      );
      // 240/3000 * 400 = 32px — too narrow to show label
      expect(find.text('Air'), findsNothing);
      // EAN50 block is 2760/3000 * 400 = 368px — wide → label shown
      expect(find.text('EAN50'), findsOneWidget);
    });

    testWidgets('uses correct color for air segment', (tester) async {
      await tester.pumpWidget(
        _strip([_seg(start: 0, end: 3000, o2: 21)], 3000),
      );
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(Tooltip),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(container.color, GasColors.air);
    });

    testWidgets('uses correct color for nitrox segment', (tester) async {
      await tester.pumpWidget(
        _strip([_seg(start: 0, end: 3000, o2: 32)], 3000),
      );
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(Tooltip),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(container.color, GasColors.nitrox);
    });

    testWidgets('uses correct color for oxygen segment', (tester) async {
      await tester.pumpWidget(
        _strip([_seg(start: 0, end: 3000, o2: 100)], 3000),
      );
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(Tooltip),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(container.color, GasColors.oxygen);
    });
  });

  group('GasTimelineStrip zoom window', () {
    testWidgets('segment fully outside visible window produces no block', (
      tester,
    ) async {
      await tester.pumpWidget(
        _strip(
          [_seg(start: 0, end: 500, label: 'Air')],
          3000,
          visibleMin: 1000,
          visibleMax: 3000,
        ),
      );
      // Block width = 0, so no Container is rendered
      expect(find.text('Air'), findsNothing);
      expect(find.byType(Tooltip), findsNothing);
    });

    testWidgets('segment partially in window is clipped to visible range', (
      tester,
    ) async {
      // Segment covers 0-1500, window shows 750-3000 → visible half
      await tester.pumpWidget(
        _strip(
          [_seg(start: 0, end: 1500, label: 'Air')],
          3000,
          visibleMin: 750,
          visibleMax: 3000,
        ),
      );
      // The partial segment still renders (block width > 0)
      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets('segment fully inside window renders normally', (tester) async {
      await tester.pumpWidget(
        _strip(
          [_seg(start: 1000, end: 2000, label: 'EAN32')],
          3000,
          visibleMin: 500,
          visibleMax: 2500,
        ),
      );
      expect(find.byType(Tooltip), findsOneWidget);
    });
  });
}
