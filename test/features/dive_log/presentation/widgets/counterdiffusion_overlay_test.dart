import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/counterdiffusion_analysis.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart';
import 'package:submersion/features/dive_log/presentation/widgets/counterdiffusion_overlay.dart';
import 'package:submersion/features/gas_calculators/domain/icd_calculator.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #4530: the bands, switch markers and tooltip lookup the profile
/// chart draws for counterdiffusion.
void main() {
  final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);

  const icd = CounterdiffusionRange(
    startSeconds: 600,
    endSeconds: 780,
    kind: CounterdiffusionKind.netOngassing,
    compartmentNumbers: [4, 5],
  );
  const opposing = CounterdiffusionRange(
    startSeconds: 1900,
    endSeconds: 3000,
    kind: CounterdiffusionKind.opposing,
    compartmentNumbers: [1, 2, 3, 9],
  );
  IcdSwitchMarker marker(int time, IcdSeverity severity) => IcdSwitchMarker(
    timestamp: time,
    severity: severity,
    from: const GasMix(o2: 18, he: 45),
    to: const GasMix(o2: 50),
  );
  final analysis = CounterdiffusionAnalysis(
    heliumPresent: true,
    icdRanges: const [icd],
    opposingRanges: const [opposing],
    switchMarkers: [
      marker(1910, IcdSeverity.violation),
      marker(2500, IcdSeverity.caution),
    ],
  );

  group('counterdiffusionBands', () {
    test('ICD only by default, in the warning orange', () {
      final bands = counterdiffusionBands(
        analysis,
        showAll: false,
        scheme: scheme,
        visibleMinX: 0,
        visibleMaxX: 4000,
      );

      expect(bands, hasLength(1));
      expect(bands.single.x1, 600);
      expect(bands.single.x2, 780);
      expect(bands.single.color, Colors.orange.withValues(alpha: 0.18));
    });

    test('All adds the opposing spans beneath the ICD ones', () {
      final bands = counterdiffusionBands(
        analysis,
        showAll: true,
        scheme: scheme,
        visibleMinX: 0,
        visibleMaxX: 4000,
      );

      expect(bands.map((b) => b.x1), [1900, 600]);
    });

    test('clips to the visible window and drops what lies outside', () {
      final bands = counterdiffusionBands(
        analysis,
        showAll: true,
        scheme: scheme,
        visibleMinX: 700,
        visibleMaxX: 2000,
      );

      expect(bands.map((b) => (b.x1, b.x2)), [
        (1900.0, 2000.0),
        (700.0, 780.0),
      ]);
    });

    test('no analysis, no bands', () {
      expect(
        counterdiffusionBands(
          null,
          showAll: true,
          scheme: scheme,
          visibleMinX: 0,
          visibleMaxX: 10,
        ),
        isEmpty,
      );
    });
  });

  group('icdSwitchMarkerLines', () {
    test('one dashed line per visible switch, coloured by severity', () {
      final lines = icdSwitchMarkerLines(
        analysis,
        warningsEnabled: true,
        scheme: scheme,
        visibleMinX: 0,
        visibleMaxX: 2000,
      );

      expect(lines, hasLength(1));
      expect(lines.single.x, 1910);
      expect(lines.single.color, scheme.error);
      expect(lines.single.dashArray, isNotNull);
    });

    test('ICD warnings off draws no switch line, as in the calculator', () {
      expect(
        icdSwitchMarkerLines(
          analysis,
          warningsEnabled: false,
          scheme: scheme,
          visibleMinX: 0,
          visibleMaxX: 4000,
        ),
        isEmpty,
      );
    });

    test('a caution reads orange', () {
      expect(icdSwitchMarkerColor(IcdSeverity.caution, scheme), Colors.orange);
    });
  });

  group('counterdiffusionRangeAt', () {
    test('finds the ICD span, and the opposing one only with All', () {
      expect(counterdiffusionRangeAt(analysis, 700, showAll: false), icd);
      expect(counterdiffusionRangeAt(analysis, 2000, showAll: false), isNull);
      expect(counterdiffusionRangeAt(analysis, 2000, showAll: true), opposing);
      expect(counterdiffusionRangeAt(null, 700, showAll: true), isNull);
    });
  });

  group('counterdiffusionTooltip', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('an ICD span names its compartments with the warning bullet', () {
      final row = counterdiffusionTooltip(
        analysis,
        700,
        showAll: false,
        l10n: l10n,
        scheme: scheme,
      );

      expect(row, isNotNull);
      expect(row!.label, l10n.diveLog_tooltip_counterdiffusion_icd);
      expect(
        row.value,
        l10n.diveLog_tooltip_counterdiffusion_compartments('4-5'),
      );
      expect(row.bulletColor, counterdiffusionIcdColor);
    });

    test('an opposing span shows only with All, in the neutral tone', () {
      final hidden = counterdiffusionTooltip(
        analysis,
        2000,
        showAll: false,
        l10n: l10n,
        scheme: scheme,
      );
      final shown = counterdiffusionTooltip(
        analysis,
        2000,
        showAll: true,
        l10n: l10n,
        scheme: scheme,
      );

      expect(hidden, isNull);
      expect(shown!.label, l10n.diveLog_tooltip_counterdiffusion_opposing);
      expect(
        shown.value,
        l10n.diveLog_tooltip_counterdiffusion_compartments('1-3, 9'),
      );
      expect(shown.bulletColor, counterdiffusionOpposingColor(scheme));
    });
  });

  group('formatCompartmentRuns', () {
    test('joins consecutive numbers into runs', () {
      expect(formatCompartmentRuns([3, 4, 5, 7]), '3-5, 7');
      expect(formatCompartmentRuns([9, 1, 2]), '1-2, 9');
      expect(formatCompartmentRuns([6]), '6');
      expect(formatCompartmentRuns(const []), '');
    });
  });
}
