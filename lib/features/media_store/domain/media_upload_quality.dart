/// Per-device, per-media-type upload quality. `original` uploads the
/// untouched file (today's behavior); the others upload a compressed
/// rendition. Persisted by name via [MediaUploadQuality.name].
enum MediaUploadQuality { original, high, balanced, small }
