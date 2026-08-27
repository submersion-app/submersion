import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/presentation/widgets/ocean_background.dart';

const _abyssTop = Color(0xFF0B2540);
const _lightTop = Color(0xFF00ACC1);

Future<void> _pumpBackground(
  WidgetTester tester, {
  Brightness? override,
  required Brightness themeBrightness,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: themeBrightness),
      home: OceanBackground(
        brightness: override,
        child: const SizedBox.expand(),
      ),
    ),
  );
  await tester.pump();
}

LinearGradient _gradientOf(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(OceanBackground),
          matching: find.byType(Container),
        )
        .first,
  );
  final decoration = container.decoration! as BoxDecoration;
  return decoration.gradient! as LinearGradient;
}

void main() {
  testWidgets('dark theme renders the Abyss Blue gradient', (tester) async {
    await _pumpBackground(tester, themeBrightness: Brightness.dark);
    final gradient = _gradientOf(tester);
    expect(gradient.colors, [
      _abyssTop,
      const Color(0xFF08243A).withValues(alpha: 0.9),
      const Color(0xFF041220).withValues(alpha: 0.85),
    ]);
  });

  testWidgets('light theme renders the existing teal gradient', (tester) async {
    await _pumpBackground(tester, themeBrightness: Brightness.light);
    final gradient = _gradientOf(tester);
    expect(gradient.colors, [
      _lightTop,
      const Color(0xFF00ACC1).withValues(alpha: 0.9),
      const Color(0xFF009688).withValues(alpha: 0.85),
    ]);
  });

  testWidgets('brightness override beats the ambient theme both ways', (
    tester,
  ) async {
    await _pumpBackground(
      tester,
      override: Brightness.light,
      themeBrightness: Brightness.dark,
    );
    expect(_gradientOf(tester).colors.first, _lightTop);

    await _pumpBackground(
      tester,
      override: Brightness.dark,
      themeBrightness: Brightness.light,
    );
    expect(_gradientOf(tester).colors.first, _abyssTop);
  });
}
