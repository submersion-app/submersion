import 'dart:io';
import 'dart:typed_data';

/// Why a media item is unavailable on the current device.
enum UnavailableKind {
  /// Source pointer is dead (file deleted, URL 404, etc.)
  notFound,

  /// Source requires authentication that hasn't been configured.
  unauthenticated,

  /// Source is reachable only on a different device (e.g., a local-file
  /// link from another machine, or a service connector not yet signed in
  /// here).
  fromOtherDevice,

  /// Transient network error during display (cleared on retry).
  networkError,

  /// Service connector account needs to be (re-)authenticated.
  signInRequired,

  /// The file's volume (network share, external disk) is not mounted right
  /// now. Recovers by itself when the volume comes back; never orphaned.
  volumeOffline,

  /// The fetch is still running and outlived the caller's budget.
  ///
  /// Distinct from every other kind because nothing is wrong: the bytes exist
  /// and are on their way. It exists so a slow source (a network share, a cold
  /// store object, an iCloud asset still coming down) can stop occupying a
  /// concurrency slot without the tile claiming the item is missing. Always
  /// recoverable by retrying, and the underlying fetch may well have finished
  /// by the time the user does.
  stillFetching,

  /// The source refused to answer, so nothing is known about the item. The
  /// gallery case is a revoked or not-yet-granted photo permission.
  ///
  /// Never evidence of absence, and deliberately distinct from [notFound]:
  /// `reconciledOrphanFlag` leaves the orphan flag alone for this kind. It is
  /// the difference between "your photo is gone" and "let me look at your
  /// photos", and only one of those is safe to write down and sync.
  accessDenied,
}

/// Which concrete source produced a [MediaSourceData]'s bytes.
///
/// Distinct from `MediaSourceType`, which records where a row was LINKED
/// from and never changes. This records where the bytes came from on THIS
/// resolution, which can differ: a gallery-sourced row whose asset has been
/// deleted from the photo library is served from the cloud store instead.
enum ServedFrom {
  /// A file read directly off a mounted volume by `LocalFileResolver`.
  localDisk,

  /// Bytes handed over by photo_manager from the device photo library.
  platformGallery,

  /// A hit in the local media cache. No network was touched.
  storeCache,

  /// Downloaded from the cloud media store during this resolution.
  storeNetwork,

  /// A URL handed to `cached_network_image`, which owns the transport.
  networkUrl,

  /// A hit in the service connector's own cache pool.
  connectorCache,

  /// Fetched from the service connector's API during this resolution.
  connectorNetwork,

  /// A BLOB stored inline on the media row (signatures).
  embedded,
}

/// Which of the three store tiers a [MediaSourceData]'s bytes are.
///
/// Orthogonal to [ServedFrom]: the store can serve any tier from either its
/// cache or the network, so "a cached thumbnail" and "a freshly downloaded
/// thumbnail" differ in [ServedFrom] while sharing a tier.
enum ServedTier {
  /// The item's own full-resolution bytes.
  original,

  /// A derived small image: a resized photo, a video poster frame, or a
  /// document page-1 render.
  thumbnail,

  /// A compressed rendition uploaded in place of the original by a
  /// non-original upload quality setting.
  rendition,
}

/// A handle to displayable media bytes — or, when unavailable, a structured
/// explanation for the UI placeholder.
///
/// Returned by `MediaSourceResolver.resolve()` and pattern-matched by the
/// universal `MediaItemView` widget. Each variant maps to the most
/// efficient Flutter widget for that kind of source.
sealed class MediaSourceData {
  const MediaSourceData({
    this.servedFrom,
    this.servedTier = ServedTier.original,
  });

  /// Which source produced these bytes, or null when nothing did
  /// ([UnavailableData]) or the producer did not say.
  ///
  /// Stamped at construction rather than computed by consumers: the two
  /// independent native-then-store fallback paths (`MediaItemView._resolve`
  /// and `mediaBytesProvider`) therefore inherit it without either being
  /// rewritten, and cannot disagree about it.
  final ServedFrom? servedFrom;

  /// Which tier these bytes are. Meaningful mainly for store-served data;
  /// every other producer leaves it at [ServedTier.original] except when it
  /// returns a derived image.
  final ServedTier servedTier;
}

/// Bytes live in a local file the OS can read directly.
/// Maps to `Image.file` / `VideoPlayerController.file`.
class FileData extends MediaSourceData {
  final File file;

  /// Whether [file] holds a still image standing in for the item rather than
  /// the item's own bytes — a poster frame derived from a video, or a page-1
  /// render of a document.
  ///
  /// A video or document row's [FileData] is normally raw bytes that
  /// `Image.file` cannot decode, so the view substitutes a placeholder. A
  /// stand-in is the one case where such a row's file IS decodable, and only
  /// the producer knows which it handed back: `MediaItemView` sees the same
  /// `FileData` either way. A photo's thumbnail is NOT a stand-in — it is the
  /// photo itself, resized.
  final bool isPoster;

  const FileData({
    required this.file,
    this.isPoster = false,
    super.servedFrom,
    super.servedTier,
  });
}

/// Bytes live at an HTTP(S) URL that requires the given headers.
/// Maps to `CachedNetworkImage(headers: ...)`.
class NetworkData extends MediaSourceData {
  final Uri url;
  final Map<String, String> headers;
  const NetworkData({
    required this.url,
    this.headers = const {},
    super.servedFrom,
    super.servedTier,
  });
}

/// Bytes are already in memory (used for signature BLOBs and small assets).
/// Maps to `Image.memory`.
class BytesData extends MediaSourceData {
  final Uint8List bytes;
  const BytesData({required this.bytes, super.servedFrom, super.servedTier});
}

/// We cannot resolve the bytes on the current device.
/// Renders an informational badge via `UnavailableMediaPlaceholder`.
///
/// Deliberately does not accept [MediaSourceData.servedFrom] or
/// [MediaSourceData.servedTier]: nothing served these bytes, so there is no
/// honest value to pass. Omitting the parameters makes that unrepresentable
/// rather than merely conventional.
class UnavailableData extends MediaSourceData {
  final UnavailableKind kind;
  final String? userMessage;
  final String? originDeviceLabel;

  const UnavailableData({
    required this.kind,
    this.userMessage,
    this.originDeviceLabel,
  });
}
