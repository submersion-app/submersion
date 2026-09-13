/// Value objects for the Google Photos Picker API.
///
/// Field names follow the REST resources
/// (https://developers.google.com/photos/picker/reference/rest): a
/// `Session` and the `MediaItem`s it yields once the user has finished
/// picking.
library;

/// A picker session: the app creates one, sends the user to [pickerUri],
/// then polls until [mediaItemsSet] flips true.
class PickerSession {
  const PickerSession({
    required this.id,
    required this.pickerUri,
    required this.mediaItemsSet,
    this.pollInterval,
    this.expireTime,
  });

  final String id;

  /// The Google-hosted URL to open so the user can choose photos.
  final String pickerUri;

  /// True once the user has confirmed a selection and the media items are
  /// ready to list.
  final bool mediaItemsSet;

  /// How long to wait between polls, per the server's `pollingConfig`.
  final Duration? pollInterval;

  /// When the session (and its picked items' download URLs) expires.
  final DateTime? expireTime;

  factory PickerSession.fromJson(Map<String, Object?> json) {
    final polling = json['pollingConfig'];
    return PickerSession(
      id: json['id'] as String,
      pickerUri: json['pickerUri'] as String? ?? '',
      mediaItemsSet: json['mediaItemsSet'] as bool? ?? false,
      pollInterval: polling is Map<String, Object?>
          ? _parseDuration(polling['pollInterval'])
          : null,
      expireTime: _parseTime(json['expireTime']),
    );
  }
}

/// One photo or video the user picked.
class PickedMediaItem {
  const PickedMediaItem({
    required this.id,
    required this.type,
    required this.baseUrl,
    required this.mimeType,
    this.filename,
    this.createTime,
    this.width,
    this.height,
    this.cameraMake,
    this.cameraModel,
  });

  final String id;
  final PickedMediaType type;

  /// Base download URL. Append `=d` for the original bytes (with EXIF), or
  /// `=w<W>-h<H>` for a resized rendition. Requires the session's OAuth
  /// bearer token and stops working when the session expires.
  final String baseUrl;

  final String mimeType;
  final String? filename;

  /// Capture time reported by Google -- the value dive auto-linking matches
  /// against. Google derives it from the file's own metadata.
  final DateTime? createTime;

  final int? width;
  final int? height;
  final String? cameraMake;
  final String? cameraModel;

  bool get isVideo => type == PickedMediaType.video;

  factory PickedMediaItem.fromJson(Map<String, Object?> json) {
    final mediaFile = json['mediaFile'];
    final file = mediaFile is Map<String, Object?> ? mediaFile : const {};
    final meta = file['mediaFileMetadata'];
    final metadata = meta is Map<String, Object?> ? meta : const {};
    return PickedMediaItem(
      id: json['id'] as String,
      type: PickedMediaType.fromString(json['type'] as String?),
      baseUrl: file['baseUrl'] as String? ?? '',
      mimeType: file['mimeType'] as String? ?? '',
      filename: file['filename'] as String?,
      createTime: _parseTime(json['createTime']),
      width: _parseInt(metadata['width']),
      height: _parseInt(metadata['height']),
      cameraMake: metadata['cameraMake'] as String?,
      cameraModel: metadata['cameraModel'] as String?,
    );
  }
}

enum PickedMediaType {
  photo,
  video,
  unspecified;

  static PickedMediaType fromString(String? value) => switch (value) {
    'PHOTO' => PickedMediaType.photo,
    'VIDEO' => PickedMediaType.video,
    _ => PickedMediaType.unspecified,
  };
}

DateTime? _parseTime(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

/// Protobuf JSON renders a duration as a decimal-seconds string, e.g.
/// `"5s"` or `"1.500s"`.
Duration? _parseDuration(Object? value) {
  if (value is! String || !value.endsWith('s')) return null;
  final seconds = double.tryParse(value.substring(0, value.length - 1));
  if (seconds == null) return null;
  return Duration(milliseconds: (seconds * 1000).round());
}

int? _parseInt(Object? value) => switch (value) {
  final int v => v,
  final String v => int.tryParse(v),
  _ => null,
};
