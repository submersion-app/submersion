import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Reads DER-encoded root CA certificates from the live Windows `ROOT`
/// certificate store -- in both the current-user and local-machine contexts
/// -- via the Win32 `crypt32` API.
///
/// Dart bundles BoringSSL and does its own X.509 verification rather than
/// deferring to SChannel, and its default [SecurityContext] does not
/// reliably surface the Windows trust store -- so a Flutter Windows app can
/// fail to verify certificates that Edge accepts on the same machine. This
/// bridges that gap by handing the OS-installed roots back to the caller,
/// which armors them into PEM for [SecurityContext.setTrustedCertificatesBytes].
///
/// Both the current-user and local-machine `ROOT` stores are read and the
/// results unioned (deduped): enterprise/managed trust anchors are commonly
/// installed only at the machine level (e.g. via Group Policy), which the
/// current-user store alone can miss. Only the `ROOT` store is read, never
/// the intermediate (`CA`) store -- its certificates are genuine trust
/// anchors, which is exactly how `setTrustedCertificatesBytes` treats every
/// entry; trusting intermediates as anchors would let BoringSSL terminate a
/// chain early instead of requiring chain-up to a root. Endpoints we contact
/// send their own intermediates in the TLS handshake.
///
/// Returns an empty list on every non-Windows platform (the file still
/// compiles everywhere because `dart:ffi` is cross-platform and the
/// `crypt32.dll` lookup is deferred behind the [Platform.isWindows] guard).
List<Uint8List> readWindowsRootCertificates() {
  if (!Platform.isWindows) return const [];

  // The crypt32 FFI path only loads and runs on Windows, so it cannot be
  // exercised by the non-Windows CI host; excluded from coverage. Verified
  // on Windows hardware instead.
  // coverage:ignore-start
  final crypt32 = DynamicLibrary.open('crypt32.dll');
  final certOpenStore = crypt32
      .lookupFunction<_CertOpenStoreNative, _CertOpenStoreDart>(
        'CertOpenStore',
      );
  final certEnumCertificates = crypt32
      .lookupFunction<_CertEnumNative, _CertEnumDart>(
        'CertEnumCertificatesInStore',
      );
  final certCloseStore = crypt32
      .lookupFunction<_CertCloseStoreNative, _CertCloseStoreDart>(
        'CertCloseStore',
      );

  const certStoreProvSystemW = 10; // CERT_STORE_PROV_SYSTEM_W
  const certSystemStoreCurrentUser = 0x00010000;
  const certSystemStoreLocalMachine = 0x00020000;

  final certificates = <Uint8List>[];
  final seen = <String>{};
  final storeNamePtr = 'ROOT'.toNativeUtf16();
  try {
    for (final location in const [
      certSystemStoreCurrentUser,
      certSystemStoreLocalMachine,
    ]) {
      final store = certOpenStore(
        certStoreProvSystemW,
        0,
        0,
        location,
        storeNamePtr.cast(),
      );
      if (store == nullptr) continue;
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
            final der = Uint8List.fromList(data.asTypedList(length));
            // The two store locations overlap (the user view aggregates
            // machine roots), so keep only the first sighting of each cert.
            if (seen.add(base64.encode(der))) certificates.add(der);
          }
          context = certEnumCertificates(store, context);
        }
      } finally {
        certCloseStore(store, 0);
      }
    }
  } finally {
    malloc.free(storeNamePtr);
  }
  return certificates;
  // coverage:ignore-end
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

// CertOpenStore(lpszStoreProvider, dwEncodingType, hCryptProv, dwFlags,
// pvPara). lpszStoreProvider is the predefined CERT_STORE_PROV_SYSTEM_W (an
// integer passed in the pointer slot), and pvPara is the wide store name.
typedef _CertOpenStoreNative =
    Pointer<Void> Function(
      IntPtr lpszStoreProvider,
      Uint32 dwEncodingType,
      IntPtr hCryptProv,
      Uint32 dwFlags,
      Pointer<Void> pvPara,
    );
typedef _CertOpenStoreDart =
    Pointer<Void> Function(
      int lpszStoreProvider,
      int dwEncodingType,
      int hCryptProv,
      int dwFlags,
      Pointer<Void> pvPara,
    );

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
