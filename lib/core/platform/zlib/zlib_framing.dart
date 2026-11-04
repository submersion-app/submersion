/// The wrapper around a deflate body.
enum ZlibFraming {
  /// RFC 1950: a two byte header and an Adler-32 trailer.
  zlib,

  /// RFC 1952: a ten byte header with optional fields, a CRC-32 and the
  /// original length as the trailer.
  gzip,
}
