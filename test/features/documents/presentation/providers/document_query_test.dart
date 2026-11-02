import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';
import 'package:submersion/features/query/presentation/providers/query_id_set_providers.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// The Documents page's query (#3882) narrows the list the way every other
/// list's query does.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedDivers(db, ['me']);
    await db.customStatement(
      "INSERT INTO documents (id, diver_id, type, title, created_at, "
      "updated_at) VALUES "
      "('ins', 'me', 'insurance', 'DAN', 1, 1), "
      "('map', 'me', 'map', 'Pier map', 1, 1)",
    );
    container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        queryIdSetRunnerProvider.overrideWithValue(QueryIdSetRunner(db)),
        documentRepositoryProvider.overrideWithValue(
          DocumentRepository(cancelReminders: (_) async {}),
        ),
      ],
    );
    addTearDown(container.dispose);
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> ids() async {
    final sub = container.listen(filteredDocumentsProvider, (_, _) {});
    addTearDown(sub.close);
    for (var i = 0; i < 20; i++) {
      final value = container.read(filteredDocumentsProvider);
      if (value.hasValue) return {for (final e in value.value!) e.document.id};
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    fail('the documents never loaded');
  }

  test('no query passes every document through', () async {
    expect(await ids(), {'ins', 'map'});
  });

  test('a word and a field query narrow the list', () async {
    container.read(documentQueryProvider.notifier).state = TextNode(['pier']);
    expect(await ids(), {'map'});
    container.read(documentQueryProvider.notifier).state = ConditionNode(
      FieldPath(['type']),
      QueryOp.eq,
      const EnumValue('insurance'),
    );
    expect(await ids(), {'ins'});
  });
}
