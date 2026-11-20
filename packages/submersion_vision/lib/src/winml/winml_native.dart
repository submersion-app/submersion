import 'dart:ffi';

import 'package:ffi/ffi.dart';

// Windows ML's flat C catalogue (WinMLEpCatalog.h in the
// Microsoft.Windows.AI.MachineLearning package), declared here by hand:
// the package's licence lets an app redistribute only the files placed
// beside it, not its headers. Bound to the library the build hook ships
// under this file's asset id, on Windows only. Each function returns an
// HRESULT, negative on failure.

/// `WinMLEpInfo`.
final class WinMLEpInfo extends Struct {
  external Pointer<Utf8> name;
  external Pointer<Utf8> version;
  external Pointer<Utf8> packageFamilyName;
  external Pointer<Utf8> libraryPath;
  external Pointer<Utf8> packageRootPath;

  /// 0 ready, 1 not ready (present, needs preparing), 2 not present.
  @Int32()
  external int readyState;

  @Int32()
  external int certification;
}

/// `WinMLEpEnumCallback`: nonzero to keep enumerating.
typedef WinMLEpEnumCallback =
    Int32 Function(Pointer<Void> ep, Pointer<WinMLEpInfo> info, Pointer<Void>);

@Native<Int32 Function(Pointer<Pointer<Void>>)>(symbol: 'WinMLEpCatalogCreate')
external int winMLEpCatalogCreate(Pointer<Pointer<Void>> catalog);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<NativeFunction<WinMLEpEnumCallback>>,
    Pointer<Void>,
  )
>(symbol: 'WinMLEpCatalogEnumProviders')
external int winMLEpCatalogEnumProviders(
  Pointer<Void> catalog,
  Pointer<NativeFunction<WinMLEpEnumCallback>> callback,
  Pointer<Void> context,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Utf8>,
    Pointer<Utf8>,
    Pointer<Pointer<Void>>,
  )
>(symbol: 'WinMLEpCatalogFindProvider')
external int winMLEpCatalogFindProvider(
  Pointer<Void> catalog,
  Pointer<Utf8> providerName,
  Pointer<Utf8> packageFamilyName,
  Pointer<Pointer<Void>> ep,
);

@Native<Int32 Function(Pointer<Void>)>(symbol: 'WinMLEpEnsureReady')
external int winMLEpEnsureReady(Pointer<Void> ep);

@Native<Int32 Function(Pointer<Void>, Pointer<Size>)>(
  symbol: 'WinMLEpGetLibraryPathSize',
)
external int winMLEpGetLibraryPathSize(Pointer<Void> ep, Pointer<Size> size);

@Native<Int32 Function(Pointer<Void>, Size, Pointer<Utf8>, Pointer<Size>)>(
  symbol: 'WinMLEpGetLibraryPath',
)
external int winMLEpGetLibraryPath(
  Pointer<Void> ep,
  int bufferSize,
  Pointer<Utf8> buffer,
  Pointer<Size> used,
);
