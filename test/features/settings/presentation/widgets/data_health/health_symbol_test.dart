import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_symbol.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    HealthLevel level,
    Brightness brightness,
  ) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Center(child: HealthSymbol(level: level)),
    ),
  );

  Color fill(WidgetTester tester) {
    final box = tester.widget<Container>(
      find.descendant(
        of: find.byType(HealthSymbol),
        matching: find.byType(Container),
      ),
    );
    return (box.decoration! as BoxDecoration).color ?? Colors.transparent;
  }

  IconData glyph(WidgetTester tester) =>
      tester.widget<Icon>(find.byType(Icon)).icon!;

  for (final brightness in Brightness.values) {
    final colors = brightness == Brightness.dark
        ? StatusColors.dark
        : StatusColors.light;

    testWidgets('health symbol uses status colours and the right glyph per '
        'level ($brightness)', (tester) async {
      await pump(tester, HealthLevel.healthy, brightness);
      expect((fill(tester), glyph(tester)), (colors.ok.accent, Icons.check));

      await pump(tester, HealthLevel.attention, brightness);
      expect(
        (fill(tester), glyph(tester)),
        (colors.warn.accent, Icons.priority_high),
      );

      await pump(tester, HealthLevel.failing, brightness);
      expect((fill(tester), glyph(tester)), (colors.alert.accent, Icons.close));

      await pump(tester, HealthLevel.notSetUp, brightness);
      expect((fill(tester), glyph(tester)), (Colors.transparent, Icons.remove));
    });
  }

  testWidgets('size sets the symbol diameter', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: HealthSymbol(level: HealthLevel.healthy, size: 16)),
      ),
    );
    expect(tester.getSize(find.byType(HealthSymbol)), const Size(16, 16));
  });
}
