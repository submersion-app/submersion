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

/// What a reader's sitting does with a card's changes.
enum SiteReaderCard {
  /// A field of the library's site: proposed to the owner at Send.
  suggested,

  /// The reader's own: written for them at Send, never proposed.
  private,

  /// The library's, which a reader's sitting does not change: faded.
  library,
}

/// [cardId]'s place in a reader's sitting. Notes, rating and the reader's
/// attachments are their own; features and expected species are the
/// library's; every other card, the header block included, is suggested.
SiteReaderCard siteReaderCardRule(String cardId) => switch (cardId) {
  'notes' || 'rating' || 'media' || 'documents' => SiteReaderCard.private,
  'features' || 'marineLife' => SiteReaderCard.library,
  _ => SiteReaderCard.suggested,
};
