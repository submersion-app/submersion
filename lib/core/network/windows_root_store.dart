import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Reads DER-encoded root CA certificates from the live Windows `ROOT`
/// certificate store via the Win32 `crypt32` API.
///
/// Dart bundles BoringSSL and does its own X.509 verification rather than
/// deferring to SChannel, and its default [SecurityContext] does not
/// reliably surface the Windows trust store -- so a Flutter Windows app can
/// fail to verify certificates that Edge accepts on the same machine. This
/// bridges that gap by handing the OS-installed roots back to the caller,
/// which armors them into PEM for [SecurityContext.setTrustedCertificatesBytes].
///
/// Only the `ROOT` store is read. Its certificates are genuine trust anchors,
/// which is exactly how `setTrustedCertificatesBytes` treats every entry it
/// is given. The intermediate (`CA`) store is deliberately excluded: adding
/// intermediates as trust anchors would let BoringSSL terminate a chain at an
/// intermediate instead of requiring it to chain up to a root -- a real trust
/// distinction from OS chain-building. Endpoints we contact send their own
/// intermediates in the TLS handshake.
///
/// Returns an empty list on every non-Windows platform (the file still
/// compiles everywhere because `dart:ffi` is cross-platform and the
/// `crypt32.dll` lookup is deferred behind the [Platform.isWindows] guard).
List<Uint8List> readWindowsRootCertificates() {
  if (!Platform.isWindows) return const [];

  final crypt32 = DynamicLibrary.open('crypt32.dll');
  final certOpenSystemStore = crypt32
      .lookupFunction<_CertOpenSystemStoreNative, _CertOpenSystemStoreDart>(
        'CertOpenSystemStoreW',
      );
  final certEnumCertificates = crypt32
      .lookupFunction<_CertEnumNative, _CertEnumDart>(
        'CertEnumCertificatesInStore',
      );
  final certCloseStore = crypt32
      .lookupFunction<_CertCloseStoreNative, _CertCloseStoreDart>(
        'CertCloseStore',
      );

  final certificates = <Uint8List>[];
  final storeNamePtr = 'ROOT'.toNativeUtf16();
  try {
    final store = certOpenSystemStore(0, storeNamePtr);
    if (store == nullptr) return certificates;
    try {
      // CertEnumCertificatesInStore frees the previously returned context
      // on each call and returns nullptr (freeing the last) when done, so
      // no manual CertFreeCertificateContext is required.
      var context = certEnumCertificates(store, nullptr);
      while (context != nullptr) {
        final length = context.ref.cbCertEncoded;
        final data = context.ref.pbCertEncoded;
        if (length > 0 && data != nullptr) {
          // Copy out of native memory before the next enum call frees it.
          certificates.add(Uint8List.fromList(data.asTypedList(length)));
        }
        context = certEnumCertificates(store, context);
      }
    } finally {
      certCloseStore(store, 0);
    }
  } finally {
    malloc.free(storeNamePtr);
  }
  return certificates;
}

/// Mirror of the Win32 `CERT_CONTEXT` struct; only the encoded-bytes fields
/// are read, but the full layout is declared so offsets line up under the
/// C ABI.
final class _CertContext extends Struct {
  @Uint32()
  external int dwCertEncodingType;
  external Pointer<Uint8> pbCertEncoded;
  @Uint32()
  external int cbCertEncoded;
  external Pointer<Void> pCertInfo;
  external Pointer<Void> hCertStore;
}

typedef _CertOpenSystemStoreNative =
    Pointer<Void> Function(IntPtr hProv, Pointer<Utf16> szSubsystemProtocol);
typedef _CertOpenSystemStoreDart =
    Pointer<Void> Function(int hProv, Pointer<Utf16> szSubsystemProtocol);

typedef _CertEnumNative =
    Pointer<_CertContext> Function(
      Pointer<Void> hCertStore,
      Pointer<_CertContext> pPrevCertContext,
    );
typedef _CertEnumDart =
    Pointer<_CertContext> Function(
      Pointer<Void> hCertStore,
      Pointer<_CertContext> pPrevCertContext,
    );

typedef _CertCloseStoreNative =
    Int32 Function(Pointer<Void> hCertStore, Uint32 dwFlags);
typedef _CertCloseStoreDart =
    int Function(Pointer<Void> hCertStore, int dwFlags);
