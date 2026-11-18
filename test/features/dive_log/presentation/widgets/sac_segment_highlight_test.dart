import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/core/theme/contrast_ratio.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_segment_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_segment_table.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_time_columns.dart';

import 'sac_segments_test_harness.dart';

/// The picked column and the rows it falls in, which must be plain to see
/// rather than a thin outline (issue #4697).
void main() {
  Color opaque(Color color) => color.withValues(alpha: 1);

  ColorScheme schemeOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(SacTimeColumns))).colorScheme;

  Color hue(WidgetTester tester, DivePhase phase) =>
      SacSegmentColors.forPhase(phase, schemeOf(tester).brightness);

  BoxDecoration columnDecoration(WidgetTester tester, int index) {
    final boxes = tester.widgetList<DecoratedBox>(
      find.descendant(
        of: find.byKey(SacTimeColumns.plotKey),
        matching: find.byType(DecoratedBox),
      ),
    );
    return boxes.elementAt(index).decoration as BoxDecoration;
  }

  /// The table's rows by their label, headings left out.
  Map<String, BoxDecoration?> rowDecorations(WidgetTester tester) {
    final table = tester.widget<SacSegmentTable>(find.byType(SacSegmentTable));
    final labels = [
      for (final section in table.sections) ...[
        null,
        ...section.rows.map((r) => r.label),
      ],
    ];
    final rows = tester
        .widget<Table>(
          find.descendant(
            of: find.byType(SacSegmentTable),
            matching: find.byType(Table),
          ),
        )
        .children;
    return {
      for (final (index, label) in labels.indexed)
        ?label: rows[index].decoration as BoxDecoration?,
    };
  }

  group('time chart', () {
    testWidgets('the other columns fade while one is picked', (tester) async {
      await pumpSacSegmentsView(tester, selectedTimestamp: 7 * 60);

      expect(columnDecoration(tester, 1).color, hue(tester, DivePhase.bottom));
      for (final index in [0, 2, 3]) {
        final color = columnDecoration(tester, index).color!;
        expect(color.a, SacTimeColumns.unpickedAlpha, reason: 'column $index');
      }
      expect(
        opaque(columnDecoration(tester, 3).color!),
        hue(tester, DivePhase.safetyStop),
      );
    });

    testWidgets('every column keeps its full color with nothing picked', (
      tester,
    ) async {
      await pumpSacSegmentsView(tester);

      for (final index in [0, 1, 2, 3]) {
        expect(columnDecoration(tester, index).color!.a, 1.0);
      }
    });

    testWidgets('a tapped column fades the others', (tester) async {
      await pumpSacSegmentsView(tester);

      await tester.tapAt(sacColumnCenter(tester, 2, 4));
      await tester.pump();

      expect(columnDecoration(tester, 2).color!.a, 1.0);
      expect(
        columnDecoration(tester, 0).color!.a,
        SacTimeColumns.unpickedAlpha,
      );
    });

    testWidgets('the picked column keeps a bold outline', (tester) async {
      await pumpSacSegmentsView(tester, selectedTimestamp: 7 * 60);

      final side = (columnDecoration(tester, 1).border! as Border).top;
      expect(side.color, schemeOf(tester).onSurface);
      expect(side.width, greaterThanOrEqualTo(2));
      // Half inside, so a short column keeps its color within it, and half
      // in the gap between columns, so no neighbour covers it.
      expect(side.strokeAlign, BorderSide.strokeAlignCenter);
    });
  });

  group('phase and gas rows', () {
    testWidgets('the picked row is tinted in its own color', (tester) async {
      await pumpSacSegmentsView(
        tester,
        gases: const [],
        selectedTimestamp: 420,
      );
      final bottom = hue(tester, DivePhase.bottom);

      final picked = rowDecorations(tester)['Bottom']!;
      expect(opaque(picked.color!), bottom);
      expect(picked.color!.a, SacSegmentTable.selectedTintAlpha);
      final stripe = (picked.border! as BorderDirectional).start;
      expect(stripe.color, bottom);
      expect(stripe.width, greaterThanOrEqualTo(3));
    });

    testWidgets('a picked row with no color of its own takes the primary', (
      tester,
    ) async {
      // The fixture's cylinders name no mix, so they have no color.
      await pumpSacSegmentsView(
        tester,
        phases: const [],
        selectedTimestamp: 60,
      );
      final primary = schemeOf(tester).primary;

      final picked = rowDecorations(tester)['Back gas']!;
      expect(opaque(picked.color!), primary);
      expect((picked.border! as BorderDirectional).start.color, primary);
    });

    testWidgets('only the picked row is marked', (tester) async {
      await pumpSacSegmentsView(
        tester,
        gases: const [],
        selectedTimestamp: 420,
      );

      final rows = rowDecorations(tester);
      expect(rows['Bottom'], isNotNull);
      for (final label in ['Descent', 'Ascent', 'Safety stop']) {
        expect(rows[label], isNull, reason: label);
      }
    });

    testWidgets('no row is marked with nothing picked', (tester) async {
      await pumpSacSegmentsView(tester);

      expect(rowDecorations(tester).values, everyElement(isNull));
    });
  });

  group('on every theme', () {
    for (final preset in AppThemeRegistry.presets) {
      for (final brightness in Brightness.values) {
        final theme = AppThemeRegistry.resolveTheme(preset, brightness);
        final scheme = theme.colorScheme;
        final card = Color.alphaBlend(
          theme.cardTheme.color ?? scheme.surfaceContainerLow,
          scheme.surface,
        );
        final name = '${preset.id} ${brightness.name}';

        final phases = {
          for (final phase in DivePhase.values)
            phase.name: SacSegmentColors.forPhase(phase, brightness),
        };
        final columnHues = {...phases, 'primary': scheme.primary};
        final rowHues = {
          ...columnHues,
          'air': GasColors.air,
          'nitrox': GasColors.nitrox,
          'oxygen': GasColors.oxygen,
          'trimix': GasColors.trimix,
        };

        for (final MapEntry(key: hue, value: full) in columnHues.entries) {
          final faded = Color.alphaBlend(
            full.withValues(alpha: SacTimeColumns.unpickedAlpha),
            card,
          );

          test('a faded $hue column still shows on $name', () {
            expect(contrastRatio(faded, card), greaterThan(1.1));
          });

          test('a picked $hue column stands out on $name', () {
            expect(contrastRatio(full, faded), greaterThan(1.3));
          });
        }

        for (final MapEntry(key: hue, value: full) in rowHues.entries) {
          final tinted = Color.alphaBlend(
            full.withValues(alpha: SacSegmentTable.selectedTintAlpha),
            card,
          );

          test('a picked $hue row reads on $name', () {
            expect(contrastRatio(scheme.onSurface, tinted), greaterThan(4.5));
            expect(
              contrastRatio(scheme.onSurfaceVariant, tinted),
              greaterThan(4.5),
            );
          });
        }
      }
    }
  });
}
