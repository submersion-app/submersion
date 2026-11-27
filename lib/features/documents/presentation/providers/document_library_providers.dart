import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/library_document_stamper.dart';
import 'package:submersion/core/services/shared_library/shared_document_state.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';

/// A shared site library as a document filed on one of its sites sees it
/// (issue #4713): its name, and whether the active profile may share,
/// unshare and change its documents.
class DocumentLibraryView {
  const DocumentLibraryView({
    required this.libraryId,
    required this.libraryName,
    required this.canEdit,
  });

  final String libraryId;
  final String libraryName;
  final bool canEdit;
}

final libraryDocumentStamperProvider = Provider<LibraryDocumentStamper>(
  (ref) => LibraryDocumentStamper(),
);

/// The library of site [siteId] as the active profile sees it; null for a
/// personal site, or a library the profile does not belong to.
final siteLibraryViewProvider =
    FutureProvider.family<DocumentLibraryView?, String>((ref, siteId) async {
      // Roles, names and read-only state change with each library sync.
      await ref.watch(sharedLibrariesProvider.future);
      final libraryId = await ref
          .watch(libraryDocumentStamperProvider)
          .libraryOfSite(siteId);
      if (libraryId == null) return null;
      final membership = await ref.watch(
        currentMembershipProvider(libraryId).future,
      );
      if (membership == null) return null;
      final role = await ref.watch(libraryRoleProvider(libraryId).future);
      return DocumentLibraryView(
        libraryId: libraryId,
        libraryName: membership.libraryName,
        canEdit: role != SharedLibraryRole.reader,
      );
    });

/// This device's library state of shared document [documentId]: who last
/// edited it, and when.
final documentLibraryStateProvider =
    StreamProvider.family<SharedDocumentState?, String>((
      ref,
      documentId,
    ) async* {
      final store = ref.watch(sharedLibraryStoreProvider);
      yield await store.getDocumentState(documentId);
      await for (final _ in store.watchDocumentStates()) {
        yield await store.getDocumentState(documentId);
      }
    });
