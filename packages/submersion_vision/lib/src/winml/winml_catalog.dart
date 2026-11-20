import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'package:submersion_vision/src/winml/winml_native.dart';

/// Whether a hardware engine Windows ML offers can be used now.
enum WinMlReadyState {
  /// Installed and prepared: its library can be registered.
  ready,

  /// Installed, but needs preparing first.
  notReady,

  /// Not on this PC; Windows ML can download it from Microsoft.
  notPresent,
}

/// One hardware engine Windows ML offers for this PC.
class WinMlEngine {
  const WinMlEngine({
    required this.name,
    required this.state,
    required this.libraryPath,
  });

  /// The execution provider's name, the one it is registered under.
  final String name;
  final WinMlReadyState state;

  /// Its library, empty until it is ready.
  final String libraryPath;
}

/// Windows ML's catalogue of hardware engines (Windows 11 24H2 and later
/// offer them; earlier Windows lists none).
abstract interface class WinMlCatalogue {
  Future<List<WinMlEngine>> engines();

  /// Prepares [name], downloading it from Microsoft when it is not on this
  /// PC; true when it is ready afterwards.
  Future<bool> ensureReady(String name);
}

/// The real catalogue, through Windows ML's library. Each call opens the
/// catalogue in an isolate of its own and releases it there: preparing an
/// engine can download hundreds of megabytes, which must never block the
/// caller's isolate. Windows only.
class WinMlCatalog implements WinMlCatalogue {
  const WinMlCatalog();

  @override
  Future<List<WinMlEngine>> engines() => Isolate.run(_listEngines);

  @override
  Future<bool> ensureReady(String name) => Isolate.run(() => _ensure(name));
}

List<WinMlEngine> _listEngines() => _withCatalog((catalog) {
  final found = <WinMlEngine>[];
  final callback = NativeCallable<WinMLEpEnumCallback>.isolateLocal((
    Pointer<Void> ep,
    Pointer<WinMLEpInfo> info,
    Pointer<Void> _,
  ) {
    final i = info.ref;
    if (i.name != nullptr) {
      found.add(
        WinMlEngine(
          name: i.name.toDartString(),
          state: switch (i.readyState) {
            0 => WinMlReadyState.ready,
            1 => WinMlReadyState.notReady,
            _ => WinMlReadyState.notPresent,
          },
          libraryPath: i.libraryPath == nullptr
              ? ''
              : i.libraryPath.toDartString(),
        ),
      );
    }
    return 1;
  }, exceptionalReturn: 0);
  try {
    _check(
      winMLEpCatalogEnumProviders(catalog, callback.nativeFunction, nullptr),
      'listing engines',
    );
  } finally {
    callback.close();
  }
  return found;
});

bool _ensure(String name) => _withCatalog((catalog) {
  final nativeName = name.toNativeUtf8();
  final ep = calloc<Pointer<Void>>();
  try {
    _check(
      winMLEpCatalogFindProvider(catalog, nativeName, nullptr, ep),
      'finding $name',
    );
    if (winMLEpEnsureReady(ep.value) < 0) return false;
    return _libraryPath(ep.value).isNotEmpty;
  } finally {
    calloc.free(nativeName);
    calloc.free(ep);
  }
});

String _libraryPath(Pointer<Void> ep) {
  final size = calloc<Size>();
  try {
    if (winMLEpGetLibraryPathSize(ep, size) < 0) return '';
    final buffer = calloc<Uint8>(size.value + 1).cast<Utf8>();
    try {
      if (winMLEpGetLibraryPath(ep, size.value + 1, buffer, nullptr) < 0) {
        return '';
      }
      return buffer.toDartString();
    } finally {
      calloc.free(buffer);
    }
  } finally {
    calloc.free(size);
  }
}

T _withCatalog<T>(T Function(Pointer<Void> catalog) work) {
  final out = calloc<Pointer<Void>>();
  try {
    _check(winMLEpCatalogCreate(out), 'opening the catalogue');
    try {
      return work(out.value);
    } finally {
      winMLEpCatalogRelease(out.value);
    }
  } finally {
    calloc.free(out);
  }
}

void _check(int hresult, String what) {
  if (hresult < 0) {
    throw StateError(
      'Windows ML failed $what '
      '(0x${(hresult & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0')})',
    );
  }
}
