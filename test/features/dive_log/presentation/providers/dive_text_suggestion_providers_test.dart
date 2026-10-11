import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_text_suggestion_field.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_text_suggestion_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The editor's suggestions are scoped to the validated active diver, so a
/// raw diver id that has not resolved yet (null at startup, or no stored
/// selection) never offers another diver's boats (#3229, PR review).
void main() {
  late AppDatabase db;
  late DiveRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDiver(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insertOnConflictUpdate(
          DiversCompanion(
            id: Value(id),
            name: Value('Diver $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  test('uses the validated diver while the raw id is still null', () async {
    await insertDiver('eric');
    await insertDiver('chris');
    for (final (diver, boat) in [('eric', 'Mine'), ('chris', 'Theirs')]) {
      await repository.createDive(
        domain.Dive(
          id: '',
          diverId: diver,
          dateTime: DateTime.utc(2026, 7, 1, 10),
          boatName: boat,
        ),
      );
    }

    final container = ProviderContainer(
      overrides: [
        diveRepositoryProvider.overrideWithValue(repository),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'eric'),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(
        diveTextSuggestionsProvider(DiveTextSuggestionField.boatName).future,
      ),
      ['Mine'],
    );
  });
}
