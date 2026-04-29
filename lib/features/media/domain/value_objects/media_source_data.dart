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
}

/// A handle to displayable media bytes — or, when unavailable, a structured
/// explanation for the UI placeholder.
///
/// Returned by `MediaSourceResolver.resolve()` and pattern-matched by the
/// universal `MediaItemView` widget. Each variant maps to the most
/// efficient Flutter widget for that kind of source.
sealed class MediaSourceData {
  const MediaSourceData();
}

/// Bytes live in a local file the OS can read directly.
/// Maps to `Image.file` / `VideoPlayerController.file`.
class FileData extends MediaSourceData {
  final File file;
  const FileData({required this.file});
}

/// Bytes live at an HTTP(S) URL that requires the given headers.
/// Maps to `CachedNetworkImage(headers: ...)`.
class NetworkData extends MediaSourceData {
  final Uri url;
  final Map<String, String> headers;
  const NetworkData({required this.url, this.headers = const {}});
}

/// Bytes are already in memory (used for signature BLOBs and small assets).
/// Maps to `Image.memory`.
class BytesData extends MediaSourceData {
  final Uint8List bytes;
  const BytesData({required this.bytes});
}

/// We cannot resolve the bytes on the current device.
/// Renders an informational badge via `UnavailableMediaPlaceholder`.
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
