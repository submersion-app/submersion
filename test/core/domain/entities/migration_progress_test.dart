import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/domain/entities/migration_progress.dart';

void main() {
  group('MigrationProgress', () {
    test('stores currentStep and totalSteps', () {
      const progress = MigrationProgress(currentStep: 3, totalSteps: 7);
      expect(progress.currentStep, 3);
      expect(progress.totalSteps, 7);
    });

    test('fraction returns currentStep / totalSteps', () {
      const progress = MigrationProgress(currentStep: 3, totalSteps: 7);
      expect(progress.fraction, closeTo(0.4286, 0.001));
    });

    test('fraction returns 0.0 when totalSteps is 0', () {
      const progress = MigrationProgress(currentStep: 0, totalSteps: 0);
      expect(progress.fraction, 0.0);
    });

    test('fraction returns 1.0 when complete', () {
      const progress = MigrationProgress(currentStep: 5, totalSteps: 5);
      expect(progress.fraction, 1.0);
    });
  });
}
