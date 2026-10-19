import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
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
  }) async {
    final container = colorContainer(
      FakeColorRepository(),
      diverAuto: diverAuto,
      settings: settings,
    );
    addTearDown(container.dispose);
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
