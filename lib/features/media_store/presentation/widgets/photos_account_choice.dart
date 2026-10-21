import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';
import 'package:submersion/features/media_store/presentation/media_store_error_message.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/photos_copies_provider.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_error_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// What the Using row needs, beyond [PhotosCopies], to say what choosing an
/// account does (spec section 8.3): the roster row this device's
/// attachment names, and how many photos only the attached store holds.
typedef PhotosChoiceFacts = ({String? attachedAccountId, int heldOnlyHere});

/// Reads [PhotosChoiceFacts] for [copies]. A count that cannot be read is
/// zero: it only adds a warning.
Future<PhotosChoiceFacts> readPhotosChoiceFacts(
  ProviderContainer container,
  PhotosCopies copies,
) async {
  if (!copies.attached) return (attachedAccountId: null, heldOnlyHere: 0);
  final attachState = container.read(mediaStoreAttachStateProvider);
  final accountId = await attachState.attachedAccountId();
  final storeId = await attachState.attachedStoreId();
  var held = 0;
  if (storeId != null) {
    try {
      held = await container
          .read(mediaRepositoryProvider)
          .countHeldOnlyInStore(storeId);
    } on Object {
      held = 0;
    }
  }
  return (attachedAccountId: accountId, heldOnlyHere: held);
}

/// Whether [choice] is the account this device's copies are in. Decided
/// by the row the attachment names, so an account removed and added again
/// (same row id, no group known) is still recognised, else by the group
/// known to hold it. An attachment that names neither falls back to the
/// account's name ([_matchedByNameOnly]).
bool isCurrentPhotosAccount(
  PhotosCopies copies,
  PhotosChoiceFacts facts,
  AccountGroup choice,
) {
  if (!copies.attached) return false;
  final id = facts.attachedAccountId;
  if (id != null && choice.rows.any((r) => r.id == id)) return true;
  final group = copies.group;
  if (group != null) return choice.key == group.key;
  if (id != null) return false;
  final label = copies.label;
  return label != null && choice.label == label;
}

/// Whether the account in use is known only by its name, so a match may
/// not be the account the copies live in.
bool _matchedByNameOnly(PhotosCopies copies, PhotosChoiceFacts facts) =>
    facts.attachedAccountId == null && copies.group == null;

/// Whether choosing [choice] moves this device's copies to another account.
bool isPhotosSwitch(
  PhotosCopies copies,
  PhotosChoiceFacts facts,
  AccountGroup choice,
) => copies.attached && !isCurrentPhotosAccount(copies, facts, choice);

/// What choosing [c] does, said in the sheet before it happens; null when
/// it only joins (or re-attaches) the copies already in use. Derived from
/// the same decision [isPhotosSwitch] makes, so the text always matches
/// the action.
String? photosChoiceConsequence(
  AppLocalizations l10n,
  PhotosCopies copies,
  PhotosChoiceFacts facts,
  AccountGroup c,
) {
  final label = copies.label;
  if (copies.attached) {
    if (isCurrentPhotosAccount(copies, facts, c)) {
      // Matched by name only: the account may not be the one the copies
      // live in, so say so once.
      return _matchedByNameOnly(copies, facts)
          ? l10n.settings_photos_joinConsequence(c.label)
          : null;
    }
    final base = label == null
        ? l10n.settings_photos_switchConsequenceUnnamed(c.label)
        : l10n.settings_photos_switchConsequence(label, c.label);
    if (facts.heldOnlyHere == 0) return base;
    return '$base ${l10n.settings_photos_switchHeldOnly(facts.heldOnlyHere)}';
  }
  // Not joined here yet: choosing another account than the one the
  // library's copies are in starts a second set.
  final store = copies.store;
  if (label == null || store == null) return null;
  final recorded = store.accountId;
  if (recorded != null) {
    return c.rows.any((r) => r.id == recorded)
        ? null
        : l10n.settings_photos_separateConsequence(label, c.label);
  }
  // A store announced before stores recorded their account: an account of
  // another kind cannot hold it, and one of the same kind under another
  // name may not.
  if (store.providerType != c.kind.cloudProviderType?.name) {
    return l10n.settings_photos_separateConsequence(label, c.label);
  }
  return c.label == label
      ? null
      : l10n.settings_photos_joinConsequence(c.label);
}

/// The text for a failed attach to [choice]: a WebDAV server's own
/// localized reason, the sign-in prompt for an account with no usable keys
/// here, else the store's message.
String photosAttachErrorText(
  AppLocalizations l10n,
  MediaStoreException e,
  AccountGroup choice,
) {
  if (e is MediaStoreAccountUnusable) {
    return l10n.settings_accounts_signInTo(choice.label);
  }
  final cause = e.cause;
  if (cause is WebDavException) return webDavErrorText(l10n, cause);
  return mediaStoreErrorMessage(l10n, e);
}

/// The self-signed certificate a WebDAV attach refused, for the caller to
/// offer trust; null for every other failure.
WebDavUntrustedCertificateException? untrustedCertificateOf(Object e) =>
    switch (e) {
      WebDavUntrustedCertificateException() => e,
      MediaStoreException(cause: final WebDavUntrustedCertificateException c) =>
        c,
      _ => null,
    };
