import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart' hide ConnectedAccount;
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/shared_library/crypto/library_cipher.dart';
import 'package:submersion/core/services/shared_library/crypto/roles_trust.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';

/// What a candidate location holds, against a connected library.
enum LibraryLocationVerdict {
  /// This library, as current as the one this device trusts.
  same,

  /// This library, but its roles are older than the ones this device
  /// trusts (or missing): a stale copy, perhaps restored from a backup.
  olderCopy,

  /// This library, encrypted under a key this device does not hold.
  locked,
  differentLibrary,
  noLibrary,
  retired,
  needsNewerApp,
}

class LibraryLocationCheck {
  const LibraryLocationCheck(this.verdict, {this.foundName});

  final LibraryLocationVerdict verdict;

  /// The name of the library found, when it can be read.
  final String? foundName;

  bool get canSave =>
      verdict == LibraryLocationVerdict.same ||
      verdict == LibraryLocationVerdict.olderCopy;
}

/// A repoint refused: the location does not hold this library (or holds an
/// older copy the caller did not accept).
class LibraryLocationRejected extends StateError {
  LibraryLocationRejected(this.check)
    : super('The location does not hold this library (${check.verdict.name})');

  final LibraryLocationCheck check;
}

/// Checks another account and folder for a connected library and points
/// this device at it (issue #3389). Only this device's row and its
/// profiles' location hints change: the library's files are moved by
/// whoever moved them, and other devices keep their own connection.
class LibraryConnectionService {
  LibraryConnectionService({
    required SharedLibraryStore store,
    required LibraryTransportFactory transportFor,
    String appVersion = 'unknown',
  }) : _store = store,
       _transportFor = transportFor,
       _appVersion = appVersion;

  final SharedLibraryStore _store;
  final LibraryTransportFactory _transportFor;
  final String _appVersion;
  final _log = LoggerService.forClass(LibraryConnectionService);
  AppDatabase get _db => DatabaseService.instance.database;

  /// What [prefix] of [account] holds, for the profile [diverId]. A
  /// [secret] opens an encrypted copy whose key this device lacks; a wrong
  /// one throws [WrongPassphraseError].
  Future<LibraryLocationCheck> check({
    required String libraryId,
    required String diverId,
    required ConnectedAccount account,
    required String prefix,
    String? secret,
  }) async => (await _inspect(
    libraryId: libraryId,
    account: account,
    prefix: prefix,
    secret: secret,
  )).check;

  /// Points this device's [libraryId] at [prefix] of [account], once a fresh
  /// check finds the same library there ([acceptOlder] takes an older copy
  /// too); else throws [LibraryLocationRejected] and changes nothing. Runs
  /// behind any sync in flight, so none writes the old location after.
  Future<SharedLibrary> repoint({
    required String libraryId,
    required String diverId,
    required ConnectedAccount account,
    required String prefix,
    String? secret,
    bool acceptOlder = false,
  }) => SyncCoordinator.run(() async {
    final found = await _inspect(
      libraryId: libraryId,
      account: account,
      prefix: prefix,
      secret: secret,
    );
    if (!found.check.canSave ||
        (found.check.verdict == LibraryLocationVerdict.olderCopy &&
            !acceptOlder)) {
      throw LibraryLocationRejected(found.check);
    }
    final opened = found.opened;
    final openedKey = await opened?.exportKey();
    final before = (await _store.getLibrary(libraryId))!;
    // Saved where it already was: nothing moves, so neither the stamps nor
    // the location hints the profile's other devices see.
    final moved =
        before.connectedAccountId != account.id || before.prefix != prefix;
    if (moved) await _writeCards(found.transport, libraryId);
    await _db.transaction(() async {
      await (_db.update(
        _db.sharedLibraries,
      )..where((t) => t.id.equals(libraryId))).write(
        SharedLibrariesCompanion(
          connectedAccountId: Value(account.id),
          prefix: Value(prefix),
          lastError: const Value(null),
        ),
      );
      for (final m
          in moved
              ? await _store.membershipsForLibrary(libraryId)
              : const <SharedLibraryMembership>[]) {
        await _store.upsertMembership(
          m.copyWith(
            backendKind: account.kind.name,
            locationHint: '${account.label}: $prefix',
          ),
        );
      }
      if (opened != null) {
        await _store.setLibraryKey(
          diverId: diverId,
          libraryId: libraryId,
          keyId: opened.keyId,
          key: openedKey,
        );
        await _store.setLibraryStatus(
          libraryId,
          encrypted: true,
          keyId: opened.keyId,
        );
      }
      // The old location's modified times say nothing about this one's.
      if (moved) await _store.clearRemoteStamps(libraryId);
    });
    return (await _store.getLibrary(libraryId))!;
  });

  /// Every local profile's signed card at the new location, as joining
  /// writes one: a copy may lack them, and a sync rewrites only the card of
  /// the profile it runs for. A card already there as this device would
  /// write it is left alone. A card the storage refuses is no failed move
  /// (readers may write cards by policy): the others are still written, and
  /// the sync retries it.
  Future<void> _writeCards(SharedLibraryTransport t, String libraryId) async {
    final Map<String, SharedLibraryMember> there;
    try {
      there = {for (final m in await t.listMembers()) m.memberId: m};
    } catch (e) {
      _log.warning('Could not list member cards for $libraryId: $e');
      return;
    }
    // The join date as this device last read it, for a card the copy lacks.
    final known = {
      for (final m in await _store.getMembers(libraryId)) m.memberId: m,
    };
    for (final m in await _store.membershipsForLibrary(libraryId)) {
      final key = m.signingKey;
      if (key == null) continue;
      final current = there[m.memberId];
      if (current != null &&
          current.cardVerified &&
          current.displayName == m.displayName &&
          current.publicKey == key.publicKey) {
        continue;
      }
      try {
        final card = await SharedLibraryMember.signed(
          memberId: m.memberId,
          displayName: m.displayName,
          joinedAt:
              current?.joinedAt ??
              known[m.memberId]?.joinedAt ??
              DateTime.now().toUtc(),
          key: key,
        );
        await t.writeMember(card, appVersion: _appVersion);
      } catch (e) {
        _log.warning('Could not write the card of ${m.memberId}: $e');
      }
    }
  }

  Future<
    ({
      LibraryLocationCheck check,
      LibraryCipher? opened,
      SharedLibraryTransport transport,
    })
  >
  _inspect({
    required String libraryId,
    required ConnectedAccount account,
    required String prefix,
    String? secret,
  }) async {
    LibraryLocationCheck verdict(LibraryLocationVerdict v, [String? name]) =>
        LibraryLocationCheck(v, foundName: name);
    final library = await _store.getLibrary(libraryId);
    if (library == null) throw StateError('library $libraryId not connected');
    final t = await _transportFor(account: account, prefix: prefix);
    // Read as the connect page reads a folder, so both judge it alike.
    final found = await SharedLibraryMembershipService.probeWith(t);
    final early = !found.exists
        ? LibraryLocationVerdict.noLibrary
        : found.retired
        ? LibraryLocationVerdict.retired
        : found.needsNewerApp
        ? LibraryLocationVerdict.needsNewerApp
        : found.id != library.id
        ? LibraryLocationVerdict.differentLibrary
        : null;
    if (early != null) {
      return (check: verdict(early, found.name), opened: null, transport: t);
    }
    LibraryCipher? opened;
    if (found.encrypted) {
      final keyId = found.keyId;
      var cipher = keyId != null
          ? await _store.libraryCipherFor(library.id, keyId: keyId)
          : null;
      if (cipher == null) {
        if (secret == null) {
          return (
            check: verdict(LibraryLocationVerdict.locked),
            opened: null,
            transport: t,
          );
        }
        final slots = await t.readKeyslots();
        cipher = slots == null
            ? null
            : await LibraryCipher.unlock(slots, secret);
        if (cipher == null) throw WrongPassphraseError();
        opened = cipher;
      }
      t
        ..cipher = cipher
        ..encrypting = true;
    }
    final name = found.name ?? await t.readName() ?? library.name;
    // Current: the very roles this device trusts, or newer ones the sync
    // would take. Older, missing, or signed by no owner it knows: a copy
    // to warn about.
    final roles = await t.readRolesOrNull();
    final trusted = library.roles;
    final current =
        trusted.version == 0 ||
        (roles != null &&
            (roles == trusted ||
                (roles.version > trusted.version &&
                    await judgeRoles(
                          trusted: trusted,
                          incoming: roles,
                          libraryId: library.id,
                        ) !=
                        RolesVerdict.rejected)));
    return (
      check: verdict(
        current
            ? LibraryLocationVerdict.same
            : LibraryLocationVerdict.olderCopy,
        name,
      ),
      opened: opened,
      transport: t,
    );
  }
}
