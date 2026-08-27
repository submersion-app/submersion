import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/chart_touch_recognizer.dart';

/// Harness mirroring the real chart stacking: a bottom layer owning plain
/// pan/tap recognizers (stand-ins for fl_chart's internal recognizers, which
/// normally win arena ties because they are hit-tested first) and a
/// translucent overlay above it hosting [ChartTouchClaimRecognizer]. The
/// overlay is hit first, so the claim recognizer joins each pointer's arena
/// before the stand-ins - exactly the production arrangement.
class _Harness extends StatelessWidget {
  const _Harness({
    required this.isZoomed,
    required this.onClaimed,
    required this.onReleased,
    required this.onStandInPanStart,
    required this.onStandInTap,
  });

  final ValueGetter<bool> isZoomed;
  final VoidCallback onClaimed;
  final VoidCallback onReleased;
  final VoidCallback onStandInPanStart;
  final VoidCallback onStandInTap;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          Positioned.fill(
            child: RawGestureDetector(
              gestures: {
                PanGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
                      () => PanGestureRecognizer(),
                      (r) => r.onStart = (_) => onStandInPanStart(),
                    ),
                TapGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                      () => TapGestureRecognizer(),
                      (r) => r.onTap = onStandInTap,
                    ),
              },
              child: Container(color: const Color(0xFF000000)),
            ),
          ),
          Positioned.fill(
            child: RawGestureDetector(
              behavior: HitTestBehavior.translucent,
              gestures: {
                ChartTouchClaimRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      ChartTouchClaimRecognizer
                    >(
                      () => ChartTouchClaimRecognizer(isZoomed: isZoomed),
                      (r) => r
                        ..onClaimed = onClaimed
                        ..onReleased = onReleased,
                    ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  late int claims;
  late int releases;
  late int standInPans;
  late int standInTaps;
  var zoomed = false;

  Widget harness() => _Harness(
    isZoomed: () => zoomed,
    onClaimed: () => claims++,
    onReleased: () => releases++,
    onStandInPanStart: () => standInPans++,
    onStandInTap: () => standInTaps++,
  );

  setUp(() {
    claims = 0;
    releases = 0;
    standInPans = 0;
    standInTaps = 0;
    zoomed = false;
  });

  testWidgets('zoomed one-finger drag past slop is claimed; the stand-in '
      'pan never starts', (tester) async {
    zoomed = true;
    await tester.pumpWidget(harness());

    final gesture = await tester.startGesture(const Offset(200, 200));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(claims, 1);
    expect(standInPans, 0);

    await gesture.up();
    await tester.pump();
    expect(releases, 1);
  });

  testWidgets('unzoomed one-finger drag is not claimed; the stand-in pan '
      'wins (scrub path preserved)', (tester) async {
    await tester.pumpWidget(harness());

    final gesture = await tester.startGesture(const Offset(200, 200));
    // Past kPanSlop (36), the threshold a competing PanGestureRecognizer
    // needs before it accepts.
    await gesture.moveBy(const Offset(50, 0));
    await tester.pump();
    expect(claims, 0);
    expect(standInPans, 1);

    await gesture.up();
    await tester.pump();
    expect(releases, 0);
  });

  testWidgets('second finger landing after the first already moved is still '
      'claimed (the async-finger pinch case)', (tester) async {
    await tester.pumpWidget(harness());

    final first = await tester.startGesture(const Offset(150, 200));
    await first.moveBy(const Offset(50, 0)); // stand-in pan wins pointer 1
    await tester.pump();
    expect(standInPans, 1);

    final second = await tester.startGesture(const Offset(250, 200));
    await tester.pump();
    expect(claims, 1, reason: 'pointer 2 must be claimed immediately');

    await first.up();
    await second.up();
    await tester.pump();
    expect(releases, 1);
  });

  testWidgets('a second finger joining an already-claimed drag is resolved '
      'too; the stand-in pan never engages', (tester) async {
    zoomed = true;
    await tester.pumpWidget(harness());

    // One-finger drag past slop: claimed (pan-while-zoomed).
    final first = await tester.startGesture(const Offset(150, 200));
    await first.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(claims, 1);

    // Second finger lands into the claimed gesture and moves: its own arena
    // must be resolved for us, so the stand-in pan can never win it.
    final second = await tester.startGesture(const Offset(250, 200));
    await second.moveBy(const Offset(50, 0));
    await tester.pump();
    expect(standInPans, 0);

    await first.up();
    await second.up();
    await tester.pump();
    expect(releases, 1);
  });

  testWidgets('a tap is never claimed, even while zoomed; the stand-in tap '
      'fires', (tester) async {
    zoomed = true;
    await tester.pumpWidget(harness());

    await tester.tapAt(const Offset(200, 200));
    await tester.pump();
    expect(claims, 0);
    expect(standInTaps, 1);
  });

  testWidgets('mouse drags are ignored entirely (desktop pan path is the '
      'passive listener, not this recognizer)', (tester) async {
    zoomed = true;
    await tester.pumpWidget(harness());

    final gesture = await tester.startGesture(
      const Offset(200, 200),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(50, 0));
    await tester.pump();
    expect(claims, 0);
    expect(standInPans, 1);

    await gesture.up();
    await tester.pump();
  });
}
