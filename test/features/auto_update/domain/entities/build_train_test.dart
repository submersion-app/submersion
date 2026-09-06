import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/auto_update/domain/entities/build_train.dart';

void main() {
  group('BuildTrainConfig.fromName', () {
    test('parses every declared train', () {
      for (final train in BuildTrain.values) {
        expect(BuildTrainConfig.fromName(train.name), train);
      }
    });

    test('falls back to stable for null, empty and unknown values', () {
      // Only the release pipeline sets BUILD_TRAIN, so an unparseable value is
      // a misconfigured build. A stable binary must never claim to be a beta.
      expect(BuildTrainConfig.fromName(null), BuildTrain.stable);
      expect(BuildTrainConfig.fromName(''), BuildTrain.stable);
      expect(BuildTrainConfig.fromName('BETA'), BuildTrain.stable);
      expect(BuildTrainConfig.fromName('nightly'), BuildTrain.stable);
    });
  });

  group('BuildTrainConfig.current', () {
    test('is stable when no dart-define was passed', () {
      // The test host compiles without --dart-define=BUILD_TRAIN, which is the
      // same state as a local flutter run and as any build predating the
      // define. Both must read as stable.
      expect(BuildTrainConfig.current, BuildTrain.stable);
    });
  });
}
