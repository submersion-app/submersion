/// What a fresh look at the attached store found, which decides the choices
/// the reconnect sheet offers (issue #2303, guided reconnect design 5.2).
///
/// [heldOnlyInCloud] counts the logbook's photos and videos whose only copy
/// is in the store this device was attached to: whatever is chosen, they
/// open again only if the account still holds them.
sealed class MediaStoreReconnectSituation {
  const MediaStoreReconnectSituation({this.heldOnlyInCloud = 0});

  final int heldOnlyInCloud;
}

/// The store carries this device's marker again: nothing to choose. The
/// mismatch flag has been cleared, so uploads resume.
final class ReconnectResolved extends MediaStoreReconnectSituation {
  const ReconnectResolved();
}

/// This device is not attached to a store any more (a detach landed while
/// the sheet was opening): nothing to reconnect.
final class ReconnectDetached extends MediaStoreReconnectSituation {
  const ReconnectDetached();
}

/// The store carries another store's marker. [knownToLibrary] is whether the
/// library has a record of that store (another device announced it), which
/// is the difference between joining your own copies and adopting a folder
/// this logbook has never seen.
final class ReconnectOtherStore extends MediaStoreReconnectSituation {
  const ReconnectOtherStore({
    required this.storeId,
    required this.knownToLibrary,
    super.heldOnlyInCloud,
  });

  final String storeId;
  final bool knownToLibrary;
}

/// The store carries no marker at all: the copies were wiped. Starting them
/// again mints a new one, and no other device is attached to anything there.
final class ReconnectNoMarker extends MediaStoreReconnectSituation {
  const ReconnectNoMarker({super.heldOnlyInCloud});
}

/// The marker could not be read: offline, signed out, or the provider
/// refused. [message] is the store's own diagnostic English.
final class ReconnectUnreadable extends MediaStoreReconnectSituation {
  const ReconnectUnreadable(this.message, {super.heldOnlyInCloud});

  final String message;
}

/// The attachment names no account this device can use: a pre-accounts
/// attachment, a removed account, or one with no keys here. It cannot be
/// reconnected in place; the account has to be chosen again.
final class ReconnectNeedsAccount extends MediaStoreReconnectSituation {
  const ReconnectNeedsAccount({super.heldOnlyInCloud});
}
