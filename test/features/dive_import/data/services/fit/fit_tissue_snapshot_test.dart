import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_summary_extractor.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_tissue_snapshot.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';

void main() {
  group('fitTissueSnapshot', () {
    test('is null when the summary carries no N2 loading', () {
      final summary = FitSummary(cnsStart: 0, cnsEnd: 12, decoModel: 'zhl_16c');
      expect(fitTissueSnapshot(summary), isNull);
    });

    test('builds start and end states from N2 and CNS', () {
      final summary = FitSummary(
        startN2: 0,
        endN2: 86,
        cnsStart: 1,
        cnsEnd: 23,
        decoModel: 'zhl_16c',
      );

      expect(
        fitTissueSnapshot(summary),
        const ComputerTissueSnapshot(
          algorithm: 'zhl_16c',
          start: ComputerTissueState(n2LoadPercent: 0, cnsPercent: 1),
          end: ComputerTissueState(n2LoadPercent: 86, cnsPercent: 23),
        ),
      );
    });

    test('leaves a side null when only the other N2 value is present', () {
      final onlyEnd = fitTissueSnapshot(FitSummary(endN2: 40, cnsEnd: 5));
      expect(onlyEnd, isNotNull);
      expect(onlyEnd!.start, isNull);
      expect(
        onlyEnd.end,
        const ComputerTissueState(n2LoadPercent: 40, cnsPercent: 5),
      );
      expect(onlyEnd.algorithm, isNull);

      final onlyStart = fitTissueSnapshot(FitSummary(startN2: 12));
      expect(onlyStart!.start, const ComputerTissueState(n2LoadPercent: 12));
      expect(onlyStart.end, isNull);
    });
  });
}
