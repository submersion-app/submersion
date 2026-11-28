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

/// The Documents page's search narrows the Shared libraries list too
/// (issue #4713): shared documents belong to no diver, so the query must not
/// be scoped to the diver's own.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = await setUpTestDatabase();
    await seedDivers(db, ['me']);
    await db.customStatement(
      'INSERT INTO dive_sites (id, name, created_at, updated_at, '
      "shared_library_id) VALUES ('s1', 'North Point', 0, 0, 'L')",
    );
    await db.customStatement(
      'INSERT INTO shared_library_memberships (id, diver_id, library_id, '
      'member_id, display_name, library_name, backend_kind, created_at, '
      "updated_at) VALUES ('ms', 'me', 'L', 'm1', 'Me', 'Survey', 's3', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO documents (id, diver_id, shared_library_id, site_id, '
      'type, title, created_at, updated_at) VALUES '
      "('map', NULL, 'L', 's1', 'map', 'Pier map', 1, 1), "
      "('rules', NULL, 'L', 's1', 'permit', 'Park rules', 1, 1)",
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
    final sub = container.listen(
      filteredSharedLibraryDocumentsProvider,
      (_, _) {},
    );
    addTearDown(sub.close);
    for (var i = 0; i < 20; i++) {
      final value = container.read(filteredSharedLibraryDocumentsProvider);
      if (value.hasValue) return {for (final e in value.value!) e.document.id};
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    fail('the shared documents never loaded');
  }

  test('no query lists every shared document', () async {
    expect(await ids(), {'map', 'rules'});
  });

  test('a word narrows the shared documents', () async {
    container.read(documentQueryProvider.notifier).state = TextNode(['pier']);
    expect(await ids(), {'map'});
  });
}
