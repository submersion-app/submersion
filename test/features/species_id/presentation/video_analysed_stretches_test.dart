import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/species_id/domain/entities/scanned_ranges.dart';
import 'package:submersion/features/species_id/presentation/providers/label_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/video_analysed_stretches.dart';

/// The stretches of a video already analysed, on its scrub bar (issue
/// #4825).
void main() {
  setUp(() {
    marineLifeIdEnabled = true;
    addTearDown(resetMarineLifeIdEnabled);
  });

  Future<void> pump(WidgetTester tester, ScanStretches? stretches) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoScanStretchesProvider(
            'v1',
          ).overrideWith((ref) async => stretches),
        ],
        child: const MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 250,
              height: 4,
              child: VideoAnalysedStretches(mediaId: 'v1', width: 250),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Rect stretch(WidgetTester tester, int startMs) =>
      tester.getRect(find.byKey(ValueKey('video_analysed_$startMs')));

  testWidgets('draws each analysed stretch along the bar', (tester) async {
    await pump(tester, (
      scanned: ScannedRanges.of([
        (startMs: 0, endMs: 10000),
        (startMs: 15000, endMs: 20000),
      ]),
      durationMs: 25000,
    ));
    expect(stretch(tester, 0).left, closeTo(0, 0.01));
    expect(stretch(tester, 0).right, closeTo(100, 0.01));
    expect(stretch(tester, 15000).left, closeTo(150, 0.01));
    expect(stretch(tester, 15000).right, closeTo(200, 0.01));
  });

  testWidgets('draws nothing once the scan is complete', (tester) async {
    await pump(tester, null);
    expect(find.byKey(const ValueKey('video_analysed_0')), findsNothing);
  });

  testWidgets('draws nothing with the feature off', (tester) async {
    marineLifeIdEnabled = false;
    await pump(tester, (
      scanned: ScannedRanges.of([(startMs: 0, endMs: 10000)]),
      durationMs: 25000,
    ));
    expect(find.byKey(const ValueKey('video_analysed_0')), findsNothing);
  });

  testWidgets('draws nothing on Linux, where video labels never show '
      '(issue #4876)', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await pump(tester, (
        scanned: ScannedRanges.of([(startMs: 0, endMs: 10000)]),
        durationMs: 25000,
      ));
      expect(find.byKey(const ValueKey('video_analysed_0')), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('takes no taps: the bar under it does', (tester) async {
    await pump(tester, (
      scanned: ScannedRanges.of([(startMs: 0, endMs: 10000)]),
      durationMs: 25000,
    ));
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('video_analysed_0')),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
  });
}
