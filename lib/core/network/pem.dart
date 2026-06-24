import 'dart:convert';
import 'dart:typed_data';

/// Converts a single DER-encoded X.509 certificate into PEM text.
///
/// [SecurityContext.setTrustedCertificatesBytes] only ingests PEM (or
/// PKCS12), so DER blobs read from a native trust store -- where the OS
/// hands back raw `pbCertEncoded` bytes -- must be armored first. The body
/// is wrapped at 64 characters per line to match the conventional PEM
/// layout that BoringSSL's parser expects.
String derToPem(Uint8List der) {
  final base64Body = base64.encode(der);
  final buffer = StringBuffer('-----BEGIN CERTIFICATE-----\n');
  for (var offset = 0; offset < base64Body.length; offset += 64) {
    final end = offset + 64 < base64Body.length
        ? offset + 64
        : base64Body.length;
    buffer
      ..write(base64Body.substring(offset, end))
      ..write('\n');
  }
  buffer.write('-----END CERTIFICATE-----\n');
  return buffer.toString();
}
