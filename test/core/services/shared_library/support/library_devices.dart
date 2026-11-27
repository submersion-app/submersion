import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/library_document_stamper.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/shared_site_models.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/shared_library_test_keys.dart';
import '../../../../helpers/test_database.dart';

/// Devices of the members of library L on one fake storage, for shared
/// library sync tests (issues #2567 and #4713).
const testLibrary = SharedLibrary(
  id: 'L',
  name: 'Reef Club',
  connectedAccountId: 'acc',
  prefix: 'site-sync',
);

/// A device for [member]: fresh, or the one kept in [file] when a test
/// returns to it. One device is open at a time.
Future<SharedLibraryService> libraryDevice(
  FakeCloudStorageProvider cloud,
  String member, {
  File? file,
  DateTime Function()? now,
}) async {
  final open = DatabaseService.instance.databaseOrNull;
  if (open != null) {
    await open.close();
    DatabaseService.instance.resetForTesting();
  }
  final returning = file != null && file.existsSync();
  if (file != null) {
    DatabaseService.instance.setTestDatabase(
      AppDatabase(NativeDatabase(file, setup: registerAppSqlFunctions)),
    );
  } else {
    await setUpTestDatabase();
  }
  if (!returning) {
    await DiverRepository().createDiver(
      Diver(
        id: 'd-$member',
        name: member,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    final store = SharedLibraryStore();
    await store.upsertLibrary(testLibrary);
    await store.upsertMembership(
      SharedLibraryMembership(
        id: 'ms-$member',
        diverId: 'd-$member',
        libraryId: 'L',
        memberId: member,
        displayName: member,
        libraryName: 'Reef Club',
        backendKind: 's3',
        signingKey: await testMemberKey(member),
      ),
    );
  }
  return SharedLibraryService(
    store: SharedLibraryStore(),
    transportFor: (lib) async =>
        SharedLibraryTransport(cloud, prefix: lib.prefix),
    now: now,
  );
}

/// Closes the open device, if any.
Future<void> closeLibraryDevice() async {
  final open = DatabaseService.instance.databaseOrNull;
  if (open == null) return;
  await open.close();
  DatabaseService.instance.resetForTesting();
}

/// Writes library L's manifest and roles, signed by its first owner.
Future<void> seedTestLibrary(
  FakeCloudStorageProvider cloud, {
  Set<String> owners = const {'a'},
  Set<String> editors = const {},
}) async {
  final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
  await t.writeManifest({'id': 'L', 'name': 'Reef Club', 'formatVersion': 2});
  await t.writeRoles(
    await signedTestRoles(
      owners: owners,
      editors: editors,
      members: {'a', 'b', 'c'},
    ),
  );
}

/// A library site [siteId] on this device, marked for upload with every
/// field clocked under [member].
Future<void> addLibrarySite(String siteId, String member) async {
  await SiteRepository().createSite(
    DiveSite(id: siteId, name: 'Site $siteId', sharedLibraryId: 'L'),
  );
  await markSiteDirty(siteId, member);
}

/// Marks library site [siteId] for upload with fresh clocks under [member].
Future<void> markSiteDirty(String siteId, String member) =>
    SharedLibraryStore().putSiteState(
      SharedSiteState(
        siteId: siteId,
        libraryId: 'L',
        dirty: true,
        clocks: {
          for (final f in SiteDocument.fieldNames)
            f: FieldClock(
              hlc: Hlc(DateTime.now().millisecondsSinceEpoch, 0, member),
              memberId: member,
            ),
        },
      ),
    );

/// A document filed on library site [siteId] with one page of [bytes],
/// shared with library L by [member]. Returns its id.
Future<String> addSharedDocument(
  String siteId,
  String member, {
  List<int> bytes = const [1, 2, 3],
  String title = 'Access',
}) async {
  final id = (await DocumentRepository().save(
    Document(
      id: '',
      diverId: 'd-$member',
      owner: DocumentOwner(DocumentOwnerKind.site, siteId),
      type: DocumentType.map,
      title: title,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    [testPage(bytes)],
  )).id;
  await LibraryDocumentStamper().share(
    id,
    libraryId: 'L',
    actingDiverId: 'd-$member',
  );
  return id;
}

/// A new page of [bytes].
DocumentPage testPage(List<int> bytes, {int index = 0}) => DocumentPage(
  id: '',
  documentId: '',
  pageIndex: index,
  fileName: 'page$index.pdf',
  mimeType: 'application/pdf',
  sizeBytes: bytes.length,
  bytes: Uint8List.fromList(bytes),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
