import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/utils/service_severity_colors.dart';

void main() {
  group('serviceSeveritySwatch', () {
    test('overdue is the alert swatch', () {
      expect(
        serviceSeveritySwatch(StatusColors.light, ServiceClockSeverity.overdue),
        StatusColors.light.alert,
      );
    });

    test('due soon is the warn swatch', () {
      expect(
        serviceSeveritySwatch(StatusColors.dark, ServiceClockSeverity.dueSoon),
        StatusColors.dark.warn,
      );
    });

    test('an OK or absent clock has no status swatch', () {
      expect(
        serviceSeveritySwatch(StatusColors.light, ServiceClockSeverity.ok),
        isNull,
      );
      expect(serviceSeveritySwatch(StatusColors.light, null), isNull);
    });
  });

  group('serviceSeverityDotColor', () {
    Future<BuildContext> contextFor(
      WidgetTester tester,
      ThemeData theme,
    ) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return captured;
    }

    testWidgets('due and overdue dots use the status accents', (tester) async {
      final context = await contextFor(tester, ThemeData());
      expect(
        serviceSeverityDotColor(context, ServiceClockSeverity.overdue),
        StatusColors.light.alert.accent,
      );
      expect(
        serviceSeverityDotColor(context, ServiceClockSeverity.dueSoon),
        StatusColors.light.warn.accent,
      );
    });

    testWidgets('an OK dot stays the quiet surface color', (tester) async {
      final theme = ThemeData();
      final context = await contextFor(tester, theme);
      expect(
        serviceSeverityDotColor(context, ServiceClockSeverity.ok),
        theme.colorScheme.surfaceContainerHighest,
      );
      expect(
        serviceSeverityDotColor(context, null),
        theme.colorScheme.surfaceContainerHighest,
      );
    });
  });
}
