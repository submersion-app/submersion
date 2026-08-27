import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('weighting feedback round-trips through create/getDiveById', () async {
    final created = await repository.createDive(
      Dive(
        id: '',
        dateTime: DateTime(2026, 1, 1),
        weightingFeedback: WeightingFeedback.overweighted,
        weightingFeedbackKg: 2.0,
      ),
    );
    final loaded = await repository.getDiveById(created.id);
    expect(loaded!.weightingFeedback, WeightingFeedback.overweighted);
    expect(loaded.weightingFeedbackKg, 2.0);
  });

  test('update can change feedback and clear the magnitude', () async {
    final created = await repository.createDive(
      Dive(
        id: '',
        dateTime: DateTime(2026, 1, 1),
        weightingFeedback: WeightingFeedback.underweighted,
        weightingFeedbackKg: 1.5,
      ),
    );
    await repository.updateDive(
      Dive(
        id: created.id,
        dateTime: DateTime(2026, 1, 1),
        weightingFeedback: WeightingFeedback.correct,
      ),
    );
    final loaded = await repository.getDiveById(created.id);
    expect(loaded!.weightingFeedback, WeightingFeedback.correct);
    expect(loaded.weightingFeedbackKg, isNull);
  });

  test('feedback defaults to null', () async {
    final created = await repository.createDive(
      Dive(id: '', dateTime: DateTime(2026, 1, 1)),
    );
    final loaded = await repository.getDiveById(created.id);
    expect(loaded!.weightingFeedback, isNull);
    expect(loaded.weightingFeedbackKg, isNull);
  });
}
