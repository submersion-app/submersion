import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/editing/document_edit_fields.dart';
import 'package:submersion/features/documents/presentation/editing/document_new_sitting.dart';
import 'package:submersion/features/documents/presentation/editing/document_record.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Answers whether the diver has a primary insurance.
class _Primary extends DocumentRepository {
  _Primary({required this.has});

  final bool has;

  @override
  Future<bool> hasPrimaryInsurance(String diverId) async => has;
}

/// A new document's sitting (issue #4527, phase 3, plan 11): its seed and
/// what its opener brings, as changes.
void main() {
  ProviderContainer container({bool hasPrimary = false, String? diver = 'd1'}) {
    final c = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => diver),
        documentRepositoryProvider.overrideWithValue(_Primary(has: hasPrimary)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<DocumentRecord> seed({bool hasPrimary = false}) =>
      newDocumentSeed(container(hasPrimary: hasPrimary).read, id: 'n1');

  test(
    'a seed is the diver\'s, Personal, other, with the default lead',
    () async {
      final record = await seed();

      expect(record.id, 'n1');
      expect(record.document.diverId, 'd1');
      expect(record.document.owner, const DocumentOwner.personal());
      expect(record.document.type, DocumentType.other);
      expect(record.document.reminderLeadDays, isNull);
      expect(record.pages, isEmpty);
      expect(record.tagIds, isEmpty);
      expect(EditSession(record, isNew: true).isDirty, isFalse);
    },
  );

  test('a first insurance seeds primary, a second does not', () async {
    expect((await seed()).document.isPrimary, isTrue);
    expect((await seed(hasPrimary: true)).document.isPrimary, isFalse);
  });

  test('a type and an owner from the opener are changes of Details', () async {
    final session = EditSession(await seed(), isNew: true);
    addTearDown(session.dispose);

    applyNewDocumentPrefill(
      session,
      const NewDocumentRequest(
        type: DocumentType.insurance,
        owner: DocumentOwner(DocumentOwnerKind.trip, 't1'),
      ),
    );

    expect(session.isDirty, isTrue);
    expect(session.changedCardIds, {'details'});
    expect(session.working.document.type, DocumentType.insurance);
    expect(
      session.working.document.owner,
      const DocumentOwner(DocumentOwnerKind.trip, 't1'),
    );
  });

  test('a fixed owner is noted, and is no change', () async {
    final session = EditSession(await seed(), isNew: true);
    addTearDown(session.dispose);

    applyNewDocumentPrefill(
      session,
      const NewDocumentRequest(ownerFixed: true),
    );

    expect(documentOwnerFixed(session), isTrue);
    expect(session.isDirty, isFalse);
    expect(session.working.document.owner, const DocumentOwner.personal());
  });

  test('the request reads the address as the route does', () {
    final request = NewDocumentRequest.fromQuery(const {
      'ownerKind': 'trip',
      'ownerId': 't1',
      'type': 'medicalClearance',
    });

    expect(request.owner, const DocumentOwner(DocumentOwnerKind.trip, 't1'));
    expect(request.type, DocumentType.medicalClearance);
    expect(NewDocumentRequest.fromQuery(const {}).owner, isNull);
    expect(
      NewDocumentRequest.fromQuery(const {'ownerKind': 'personal'}).owner,
      isNull,
    );
  });

  test('the laid-out cards are Details and Pages', () {
    expect(newDocumentLaidOut, ['details', 'pages']);
  });

  test('no active diver leaves the diver to Save', () async {
    final record = await newDocumentSeed(container(diver: null).read, id: 'n1');

    expect(record.document.diverId, isEmpty);
    expect(record.document.isPrimary, isFalse);
  });

  test('the owner field can be set as any other', () async {
    final session = EditSession(await seed(), isNew: true);
    addTearDown(session.dispose);

    session.set(
      documentOwnerField,
      const DocumentOwner(DocumentOwnerKind.dive, 'v1'),
    );

    expect(session.changedCardIds, {'details'});
  });
}
