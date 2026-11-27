import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/crypto/library_cipher.dart';
import 'package:submersion/core/services/shared_library/library_document_record.dart';
import 'package:submersion/core/services/shared_library/library_document_stamper.dart';
import 'package:submersion/core/services/shared_library/library_encryption_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/shared_library_test_account.dart';
import '../../../helpers/test_database.dart';

const _fast = KdfParams(m: 1024, t: 1);

/// Shared documents follow the library's encryption (issue #4713): turning
/// it on, changing the passphrase and turning it off rewrite them, and a
/// file left in the wrong form by an older owner app is put right by the
/// next sync of a member who may write it.
void main() {
  late FakeCloudStorageProvider cloud;
  late SharedLibraryMembershipService memberships;
  late LibraryEncryptionService encryption;
  late SharedLibrary lib;
  final account = ConnectedAccount(
    id: 'acc',
    kind: AccountKind.s3,
    label: 'Club bucket',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  SharedLibraryTransport folder() =>
      SharedLibraryTransport(cloud, prefix: 'site-sync');

  SharedLibraryService syncer() => SharedLibraryService(
    store: SharedLibraryStore(),
    transportFor: (l) => memberships.transportForLibrary(l),
  );

  Future<Map<String, bool>> documentForms() async {
    final t = folder();
    return {
      for (final e in (await t.sealableFiles()).entries)
        if (e.key.startsWith('documents/') || e.key.startsWith('pages/'))
          e.key: LibraryCipher.isSealed(await cloud.downloadFile(e.value)),
    };
  }

  Future<void> diver(String id) => DiverRepository().createDiver(
    Diver(
      id: id,
      name: id,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );

  setUp(() async {
    await setUpTestDatabase();
    await diver('d1');
    cloud = FakeCloudStorageProvider();
    memberships = SharedLibraryMembershipService(
      accountById: anyTestAccount,
      store: SharedLibraryStore(),
      transportFor: ({required account, required prefix}) async =>
          SharedLibraryTransport(cloud, prefix: prefix),
      recoveryKdf: _fast,
    );
    encryption = LibraryEncryptionService(
      store: SharedLibraryStore(),
      memberships: memberships,
      kdf: _fast,
    );
    lib = await memberships.create(
      account: account,
      prefix: 'site-sync',
      name: 'Reef Club',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await SiteRepository().createSite(
      DiveSite(id: 's1', name: 'Pier', sharedLibraryId: lib.id),
    );
    final id = (await DocumentRepository().save(
      Document(
        id: '',
        diverId: 'd1',
        owner: const DocumentOwner(DocumentOwnerKind.site, 's1'),
        type: DocumentType.map,
        title: 'Access',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      [
        DocumentPage(
          id: '',
          documentId: '',
          pageIndex: 0,
          fileName: 'a.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 2,
          bytes: Uint8List.fromList([1, 2]),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    )).id;
    await LibraryDocumentStamper().share(
      id,
      libraryId: lib.id,
      actingDiverId: 'd1',
    );
    await syncer().sync(lib.id, diverId: 'd1');
  });

  tearDown(() async {
    SyncCoordinator.reset();
    await tearDownTestDatabase();
  });

  test('turning encryption on seals document and page files', () async {
    await encryption.turnOn(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'correct horse battery',
    );
    final forms = await documentForms();
    expect(forms, hasLength(2));
    expect(forms.values, everyElement(isTrue));
  });

  test('changing the passphrase re-seals them, and they still open', () async {
    await encryption.turnOn(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'correct horse battery',
    );
    await encryption.changePassphrase(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'another horse battery',
    );
    expect((await documentForms()).values, everyElement(isTrue));
    final r = await syncer().sync(lib.id, diverId: 'd1');
    expect(r.status, SharedLibrarySyncStatus.success);
  });

  test('turning it off writes them plain', () async {
    await encryption.turnOn(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'correct horse battery',
    );
    await encryption.turnOff(libraryId: lib.id, diverId: 'd1');
    expect((await documentForms()).values, everyElement(isFalse));
  });

  test('a document file left plain in an encrypted library is sealed by '
      "an editor's sync", () async {
    await diver('d2');
    await memberships.join(
      account: account,
      prefix: 'site-sync',
      diverId: 'd2',
      displayName: 'Bo',
    );
    final ann = (await SharedLibraryStore().membership(
      diverId: 'd1',
      libraryId: lib.id,
    ))!;
    final bo = (await SharedLibraryStore().membership(
      diverId: 'd2',
      libraryId: lib.id,
    ))!;
    await memberships.approveMember(
      libraryId: lib.id,
      memberId: bo.memberId,
      actingMemberId: ann.memberId,
      publicKey: bo.signingKey!.publicKey,
    );
    await memberships.setRole(
      libraryId: lib.id,
      actingMemberId: ann.memberId,
      memberId: bo.memberId,
      role: SharedLibraryRole.editor,
    );
    await encryption.turnOn(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'correct horse battery',
    );
    // An older owner app wrote a document plain after the switch.
    final plain = folder()..encrypting = false;
    await plain.writeDocument(
      const LibraryDocumentRecord(id: 'late', siteId: 's1', fields: {}),
    );
    expect((await documentForms())['documents/document-late.json'], isFalse);

    final r = await syncer().sync(lib.id, diverId: 'd2');
    expect(r.status, isNot(SharedLibrarySyncStatus.failed));
    expect((await documentForms())['documents/document-late.json'], isTrue);
  });
}
