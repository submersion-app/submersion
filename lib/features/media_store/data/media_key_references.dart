import 'package:submersion/core/services/media_store/media_key_reference.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';

/// The three content-addressed namespaces of the smv1 media store.
enum StoreNamespace { objects, thumbs, renditions }

/// Whether some row with this hash could still need the key in [namespace]
/// with [extension] (storage GC design, leak 3).
///
/// Deliberately conservative. An empty [refs] is a plain orphan. Otherwise a
/// row with no upload stamp at all (an upload still pending, a reverse
/// repair, or a database restored from before the upload) keeps every object
/// under the hash, since nothing yet says which one it will use. Thumbs are
/// keyed by hash alone, so any row keeps them. Only when every row has
/// settled on a stamp can an extension or namespace no stamped row resolves
/// to be called unreferenced: the leftover of a switch between original and
/// compressed, or a second extension of the same bytes.
bool isKeyReferenced({
  required StoreNamespace namespace,
  required String extension,
  required List<MediaKeyReference> refs,
}) {
  if (refs.isEmpty) return false;
  if (refs.any((r) => !r.hasOriginalStamp && !r.hasRenditionStamp)) {
    return true;
  }
  return switch (namespace) {
    StoreNamespace.thumbs => true,
    StoreNamespace.objects => refs.any(
      (r) => r.hasOriginalStamp && r.originalExtension == extension,
    ),
    StoreNamespace.renditions => refs.any(
      (r) =>
          r.hasRenditionStamp &&
          extension == StoreKeys.renditionExtension(isVideo: r.isVideo),
    ),
  };
}
