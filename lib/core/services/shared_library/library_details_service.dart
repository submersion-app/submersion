import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';

/// Only an owner changes a library's name and description.
class NotLibraryOwnerError extends StateError {
  NotLibraryOwnerError(String libraryId)
    : super('only an owner may change the details of $libraryId');
}

/// This device holds its writes back (roles it refused, an ownership reset
/// waiting for an answer, or storage that only reads): the details wait too.
class LibraryWritesHeldError extends StateError {
  LibraryWritesHeldError(String libraryId)
    : super('writes to $libraryId are held on this device');
}

/// An owner's edit of a library's name and description (issue #3389),
/// written to the folder's `info.json`, where every member's next sync
/// reads it. The file is not signed (any member whose storage keys can
/// write the folder could change it), so the owner rule is the app's.
class LibraryDetailsService {
  LibraryDetailsService({
    required SharedLibraryStore store,
    required Future<SharedLibraryTransport> Function(SharedLibrary)
    transportFor,
  }) : _store = store,
       _transportFor = transportFor;

  static const int maxNameLength = 80;
  static const int maxDescriptionLength = 500;

  final SharedLibraryStore _store;
  final Future<SharedLibraryTransport> Function(SharedLibrary) _transportFor;

  /// Saves [name] and [description] (blank clears it) for [libraryId] as
  /// the profile [diverId], which must own it. The folder is written first:
  /// when the storage refuses, nothing changes here. Behind any sync in
  /// flight, whose read of the old details would otherwise land after.
  Future<void> save({
    required String libraryId,
    required String diverId,
    required String name,
    String? description,
  }) => SyncCoordinator.run(() async {
    final trimmedName = name.trim();
    final trimmedDescription = description?.trim() ?? '';
    if (trimmedName.isEmpty || trimmedName.length > maxNameLength) {
      throw ArgumentError.value(name, 'name');
    }
    if (trimmedDescription.length > maxDescriptionLength) {
      throw ArgumentError.value(description, 'description');
    }
    final library = await _store.getLibrary(libraryId);
    if (library == null) throw StateError('library $libraryId not connected');
    final membership = await _store.membership(
      diverId: diverId,
      libraryId: libraryId,
    );
    if (membership == null ||
        library.roles.roleOf(membership.memberId) != SharedLibraryRole.owner) {
      throw NotLibraryOwnerError(libraryId);
    }
    if (library.writesHeld) throw LibraryWritesHeldError(libraryId);
    final t = await _transportFor(library);
    // Keys this version does not know are kept for the versions that do;
    // a file no one can read (any member's storage keys may write it) is
    // replaced, which is how an owner repairs it.
    Map<String, dynamic>? existing;
    try {
      existing = await t.readInfo();
    } catch (e) {
      if (!SharedLibraryTransport.isUnreadable(e)) rethrow;
    }
    final info = {...?existing, 'name': trimmedName}..remove('description');
    if (trimmedDescription.isNotEmpty) info['description'] = trimmedDescription;
    await t.writeInfo(info);
    await applyLibraryDetails(
      _store,
      libraryId,
      name: trimmedName,
      description: trimmedDescription.isEmpty ? null : trimmedDescription,
      clearDescription: trimmedDescription.isEmpty,
    );
  });
}

/// What a sync read: [details] from `info.json` (null when it names no
/// library this device can read, which leaves the description alone), else
/// the [manifest]'s name. An owner may have renamed or described the
/// library since the last sync.
Future<void> applyReadDetails(
  SharedLibraryStore store,
  String libraryId,
  ({String name, String? description})? details,
  Map<String, dynamic> manifest,
) => applyLibraryDetails(
  store,
  libraryId,
  name:
      details?.name ??
      switch (manifest['name']) {
        final String n => n,
        _ => null,
      },
  description: details?.description,
  clearDescription: details != null && details.description == null,
);

/// Records a library's [name] and [description] on this device: on its row
/// and, for a changed name, on every local profile's membership, which
/// personal sync carries to the profile's other devices (issue #3389).
/// A null [name] leaves the name as it is.
Future<void> applyLibraryDetails(
  SharedLibraryStore store,
  String libraryId, {
  required String? name,
  String? description,
  bool clearDescription = false,
}) async {
  await store.setLibraryStatus(
    libraryId,
    name: name,
    description: description,
    clearDescription: clearDescription,
  );
  if (name == null) return;
  for (final m in await store.membershipsForLibrary(libraryId)) {
    if (m.libraryName != name) {
      await store.upsertMembership(m.copyWith(libraryName: name));
    }
  }
}
