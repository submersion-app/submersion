/// A shared site library reader's sitting on the site page (issue #4527,
/// phase 2, plan 5): the reader suggests changes to the library's site and
/// keeps their own notes, rating and attachments.
library;

import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The profile's effective role in [libraryId] from the store, or null when
/// the library is not connected here. Read from the store, not the
/// providers: a one-shot read of a paused stream provider never returns,
/// and at Save the role as stored then decides.
Future<SharedLibraryRole?> libraryRoleNow(
  ProviderRead read,
  String libraryId,
) async {
  final store = read(sharedLibraryStoreProvider);
  final library = await store.getLibrary(libraryId);
  if (library == null) return null;
  final diverId = await read(validatedCurrentDiverIdProvider.future);
  final membership = diverId == null
      ? null
      : await store.membership(diverId: diverId, libraryId: libraryId);
  if (membership == null) return SharedLibraryRole.reader;
  return effectiveRole(
    listed: library.roles.roleOf(membership.memberId),
    readOnlyDetected: library.writesHeld,
  );
}

const _readerKey = 'site.readerSitting';

/// Marks [session] as a reader's: it suggests the library's changes and
/// saves the reader's own.
void markReaderSitting(EditSession<DiveSite> session) =>
    session.remember(_readerKey, true);

/// Whether [session] is a reader's sitting.
bool isReaderSitting(EditSession<DiveSite>? session) =>
    session != null &&
    !session.isDisposed &&
    session.recall<bool>(_readerKey) == true;
