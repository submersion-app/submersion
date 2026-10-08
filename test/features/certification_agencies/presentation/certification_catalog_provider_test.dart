import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../helpers/test_database.dart';

void main() {
  late CustomCertificationRepository repo;

  setUp(() async {
    final db = await setUpTestDatabase();
    for (final id in ['a', 'b']) {
      await db.customStatement(
        'INSERT INTO divers (id, name, created_at, updated_at) '
        'VALUES (?, ?, 0, 0)',
        [id, id],
      );
    }
    repo = CustomCertificationRepository();
  });
  tearDown(tearDownTestDatabase);

  ProviderContainer container({String? diverId = 'a'}) {
    final c = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => diverId),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('the catalog holds custom rows and filters pickers by viewer', () async {
    final own = await repo.createAgency(
      diverId: 'a',
      name: 'Club A',
      isShared: false,
    );
    final private = await repo.createAgency(
      diverId: 'b',
      name: 'Club B',
      isShared: false,
    );
    final c = container();
    final catalog = await c.read(certificationCatalogProvider.future);
    expect(catalog.viewerDiverId, 'a');
    expect(catalog.agencies.map((e) => e.id), contains(own.id));
    expect(catalog.agencies.map((e) => e.id), isNot(contains(private.id)));
    // Another diver's private agency still resolves by name.
    expect(catalog.agency(private.id).name, 'Club B');
  });

  test('a new agency rebuilds the catalog', () async {
    final c = container();
    final sub = c.listen(certificationCatalogProvider, (_, _) {});
    addTearDown(sub.close);
    final before = await c.read(certificationCatalogProvider.future);
    expect(before.customAgency('x'), isNull);
    final created = await repo.createAgency(
      diverId: 'a',
      name: 'Club New',
      isShared: false,
    );
    await pumpEventQueue();
    final after = await c.read(certificationCatalogProvider.future);
    expect(after.agency(created.id).name, 'Club New');
  });

  test('the sync provider falls back to built-ins while loading', () {
    final c = container();
    final catalog = c.read(certificationCatalogSyncProvider);
    expect(catalog.agency('padi').isBuiltIn, isTrue);
    expect(identical(catalog, CertificationCatalog.builtInOnly), isTrue);
  });
}
