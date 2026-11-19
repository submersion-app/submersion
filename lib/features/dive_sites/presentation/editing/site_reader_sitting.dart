/// A shared site library reader's sitting on the site page (issue #4527,
/// phase 2, plan 5): the reader suggests changes to the library's site and
/// keeps their own notes, rating and attachments.
library;

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

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

/// The cards a reader's sitting keeps as the reader's own: notes, rating
/// and their attachments.
const siteReaderPrivateCards = {'notes', 'rating', 'media', 'documents'};

/// The library's cards, which a reader's sitting does not change: features
/// and expected species.
const siteReaderLibraryCards = {'features', 'marineLife'};

/// [cardId]'s place in a reader's sitting: one of
/// [siteReaderPrivateCards] or [siteReaderLibraryCards], or, for every
/// other card (the header block included), suggested.
SiteReaderCard siteReaderCardRule(String cardId) =>
    siteReaderPrivateCards.contains(cardId)
    ? SiteReaderCard.private
    : siteReaderLibraryCards.contains(cardId)
    ? SiteReaderCard.library
    : SiteReaderCard.suggested;

/// Whether [session] holds a change of the library's cards, which a
/// reader's Send can neither write nor propose: one made while the profile
/// could edit the site.
bool readerSittingHoldsLibraryChange(EditSession<DiveSite> session) => session
    .changedCardIds
    .any((id) => siteReaderCardRule(id) == SiteReaderCard.library);
