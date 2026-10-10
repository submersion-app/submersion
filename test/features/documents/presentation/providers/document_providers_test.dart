import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/domain/document_expiry.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 1, 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Document doc(DocumentType type, DateTime? expiry, String title) {
    final now = DateTime.now();
    return Document(
      id: '',
      diverId: 'd1',
      owner: const DocumentOwner.personal(),
      type: type,
      title: title,
      expiryDate: expiry,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('attention list excludes insurance and sorts expired first', () async {
    final c = container();
    final now = DateTime.now();
    DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);
    final mutations = c.read(documentMutationsProvider);
    await mutations.save(doc(DocumentType.insurance, day(-1), 'ins'), const []);
    await mutations.save(doc(DocumentType.permit, day(5), 'permit'), const []);
    await mutations.save(
      doc(DocumentType.medicalClearance, day(-2), 'med'),
      const [],
    );
    await mutations.save(doc(DocumentType.other, day(400), 'far'), const []);
    final list = await c.read(attentionDocumentsProvider.future);
    expect([for (final (d, _) in list) d.title], ['med', 'permit']);
    expect(list.first.$2.kind, DocumentExpiryKind.expired);
  });

  test('owner, all and by-id providers see a saved document', () async {
    final c = container();
    final saved = await c
        .read(documentMutationsProvider)
        .save(doc(DocumentType.permit, null, 'Park'), const []);
    expect(
      await c.read(
        documentsForOwnerProvider(const DocumentOwner.personal()).future,
      ),
      hasLength(1),
    );
    expect(await c.read(allDocumentsProvider.future), hasLength(1));
    expect(
      (await c.read(documentByIdProvider(saved.id).future))!.title,
      'Park',
    );
  });

  test('delete removes the document', () async {
    final c = container();
    final mutations = c.read(documentMutationsProvider);
    final saved = await mutations.save(
      doc(DocumentType.permit, null, 'Park'),
      const [],
    );
    await mutations.delete(saved.id);
    expect(await c.read(documentByIdProvider(saved.id).future), isNull);
  });
}
