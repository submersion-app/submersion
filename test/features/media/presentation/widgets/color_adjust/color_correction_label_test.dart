import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/data/services/color_analysis_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/color_correction_label.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import 'color_adjust_test_support.dart';

/// Issue #3520: the small label saying what is applied.
void main() {
  Future<void> pump(
    WidgetTester tester,
    MediaItem item, {
    bool diverAuto = true,
    AppSettings settings = const AppSettings(),
    List<int> pixel = const [20, 100, 160],
  }) async {
    // The photo as analysed: blue water unless [pixel] says otherwise.
    final service = ColorAnalysisService(
      decodeRgba: (_) async => Uint8List.fromList([
        for (var i = 0; i < 16; i++) ...[...pixel, 255],
      ]),
    );
    final container = colorContainer(
      FakeColorRepository(),
      diverAuto: diverAuto,
      settings: settings,
      analysis: service,
    );
    addTearDown(container.dispose);
    await tester.runAsync(
      () => service.statsFor(colorStatsKey(item), MemoryImage(Uint8List(0))),
    );
    await tester.pumpWidget(
      colorHost(container, ColorCorrectionLabel(item: item)),
    );
    await tester.pump();
  }

  testWidgets('automatic at a known depth, in the diver units', (tester) async {
    await pump(tester, colorItem());
    expect(find.text('18m · auto'), findsOneWidget);
  });

  testWidgets('imperial divers see feet', (tester) async {
    await pump(
      tester,
      colorItem(),
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    );
    expect(find.text('59ft · auto'), findsOneWidget);
  });

  testWidgets('automatic with no depth', (tester) async {
    await pump(tester, colorItem(depth: null));
    expect(find.text('Auto'), findsOneWidget);
  });

  testWidgets('a photo the fix leaves unchanged is not labelled', (
    tester,
  ) async {
    // Strobe-lit, its red intact: the automatic fix draws nothing.
    await pump(tester, colorItem(), pixel: const [150, 140, 120]);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('a hand adjustment says Adjusted', (tester) async {
    await pump(
      tester,
      colorItem(adjustment: const ColorAdjustment(warmth: 0.2)),
    );
    expect(find.text('Adjusted'), findsOneWidget);
  });

  testWidgets('nothing applied shows nothing', (tester) async {
    await pump(tester, colorItem(), diverAuto: false);
    expect(find.byType(Text), findsNothing);
  });
}
