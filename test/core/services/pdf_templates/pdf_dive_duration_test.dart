import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/pdf_templates/pdf_shared_components.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  group('pdfDiveDuration (#644)', () {
    Dive dive({Duration? runtime, Duration? bottomTime}) => Dive(
      id: 'd1',
      diveNumber: 1,
      dateTime: DateTime(2026, 1, 15, 9),
      runtime: runtime,
      bottomTime: bottomTime,
    );

    test('prints total runtime, not bottom time', () {
      final d = dive(
        runtime: const Duration(minutes: 62),
        bottomTime: const Duration(minutes: 50),
      );
      expect(
        pdfDiveDurationMinutes(d),
        '62',
        reason:
            'the logbook Duration field must show the dive runtime; bottom '
            'time understates it (#644)',
      );
    });

    test('prints a dash for a dive with only a bottom time (#3304)', () {
      expect(
        pdfDiveDurationMinutes(dive(bottomTime: const Duration(minutes: 50))),
        '-',
      );
    });

    test('prints a dash when no duration is known', () {
      expect(pdfDiveDurationMinutes(dive()), '-');
    });
  });

  group('pdfDiveDurationCompact', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('prints the minutes with their unit', () {
      final dive = Dive(
        id: 'd1',
        dateTime: DateTime(2026, 1, 15, 9),
        runtime: const Duration(minutes: 62),
      );
      expect(pdfDiveDurationCompact(dive, l10n), '62min');
    });

    test('prints a bare dash, with no unit, when no runtime is known', () {
      final dive = Dive(
        id: 'd1',
        dateTime: DateTime(2026, 1, 15, 9),
        bottomTime: const Duration(minutes: 50),
      );
      expect(pdfDiveDurationCompact(dive, l10n), '-');
    });
  });

  group('pdfTotalRuntime (#644)', () {
    test('sums measured runtimes across dives (#3304)', () {
      final dives = [
        Dive(
          id: 'a',
          diveNumber: 1,
          dateTime: DateTime(2026, 1, 15),
          runtime: const Duration(minutes: 62),
          bottomTime: const Duration(minutes: 50),
        ),
        Dive(
          id: 'b',
          diveNumber: 2,
          dateTime: DateTime(2026, 1, 16),
          bottomTime: const Duration(minutes: 40),
        ),
      ];
      expect(
        pdfTotalRuntime(dives),
        const Duration(minutes: 62),
        reason: 'the runtime (62), with no bottom time counted as one',
      );
    });
  });
}
