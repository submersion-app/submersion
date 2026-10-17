import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart' hide ConnectedAccount;
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/crypto/library_cipher.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_errors.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
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
  }) : _store = store,
       _transportFor = transportFor;

  final SharedLibraryStore _store;
  final LibraryTransportFactory _transportFor;
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
    final verdict = found.check.verdict;
    if (verdict != LibraryLocationVerdict.same &&
        !(acceptOlder && verdict == LibraryLocationVerdict.olderCopy)) {
      throw LibraryLocationRejected(found.check);
    }
    final opened = found.opened;
    final openedKey = await opened?.exportKey();
    final before = (await _store.getLibrary(libraryId))!;
    // Saved where it already was: nothing moves, so neither the stamps nor
    // the location hints the profile's other devices see.
    final moved =
        before.connectedAccountId != account.id || before.prefix != prefix;
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

  Future<({LibraryLocationCheck check, LibraryCipher? opened})> _inspect({
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
    final manifest = await t.readManifest();
    if (manifest == null) {
      return (check: verdict(LibraryLocationVerdict.noLibrary), opened: null);
    }
    final version = (manifest['formatVersion'] as num?)?.toInt() ?? 1;
    if (version < SharedLibraryLayout.minFormatVersion) {
      return (check: verdict(LibraryLocationVerdict.retired), opened: null);
    }
    if (version > SharedLibraryLayout.formatVersion) {
      return (
        check: verdict(LibraryLocationVerdict.needsNewerApp),
        opened: null,
      );
    }
    final encrypted = manifest['encrypted'] == true;
    if (manifest['id'] != library.id) {
      final name = encrypted
          ? null
          : await t.readName() ??
                switch (manifest['name']) {
                  final String n => n,
                  _ => null,
                };
      return (
        check: verdict(LibraryLocationVerdict.differentLibrary, name),
        opened: null,
      );
    }
    LibraryCipher? opened;
    if (encrypted) {
      final keyId = manifest['keyId'];
      var cipher = keyId is String
          ? await _store.libraryCipherFor(library.id, keyId: keyId)
          : null;
      if (cipher == null) {
        if (secret == null) {
          return (check: verdict(LibraryLocationVerdict.locked), opened: null);
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
    final name = await t.readName() ?? library.name;
    final roles = await t.readRolesOrNull();
    final trusted = library.roles.version;
    final older = trusted > 0 && (roles == null || roles.version < trusted);
    return (
      check: verdict(
        older ? LibraryLocationVerdict.olderCopy : LibraryLocationVerdict.same,
        name,
      ),
      opened: opened,
    );
  }
}
