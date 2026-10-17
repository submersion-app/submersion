import 'package:submersion/core/services/shared_library/shared_library_store.dart';

/// Records a library's [name] and [description] on this device: on its row
/// and, for a changed name, on every local profile's membership, which
/// personal sync carries to the profile's other devices (issue #3389).
/// A null [name] leaves the name as it is.
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
