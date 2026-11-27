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

/// The real catalogue, through Windows ML's library. It is opened once and
/// kept open for the life of the process: Microsoft registers an engine's
/// library while the catalogue that prepared it is still open, and an
/// engine's place in the app's process may end with it. Each call runs in
/// an isolate of its own, since preparing an engine can download hundreds
/// of megabytes and must never block the caller's isolate. Windows only.
class WinMlCatalog implements WinMlCatalogue {
  const WinMlCatalog();

  /// The open catalogue's address, shared by every caller in the process.
  static Future<int>? _opened;

  static Future<Pointer<Void>> _catalog() async {
    final opening = _opened ??= Isolate.run(_open);
    try {
      return Pointer<Void>.fromAddress(await opening);
    } on Object {
      // A failed open is tried again by the next call.
      if (identical(_opened, opening)) _opened = null;
      rethrow;
    }
  }

  @override
  Future<List<WinMlEngine>> engines() async {
    final address = (await _catalog()).address;
    return Isolate.run(() => _listEngines(Pointer<Void>.fromAddress(address)));
  }

  @override
  Future<bool> ensureReady(String name) async {
    final address = (await _catalog()).address;
    return Isolate.run(() => _ensure(Pointer<Void>.fromAddress(address), name));
  }
}

int _open() {
  final out = calloc<Pointer<Void>>();
  try {
    _check(winMLEpCatalogCreate(out), 'opening the catalogue');
    return out.value.address;
  } finally {
    calloc.free(out);
  }
}

List<WinMlEngine> _listEngines(Pointer<Void> catalog) {
  final found = <WinMlEngine>[];
  final callback = NativeCallable<WinMLEpEnumCallback>.isolateLocal((
    Pointer<Void> ep,
    Pointer<WinMLEpInfo> info,
    Pointer<Void> _,
  ) {
    // Microsoft's own samples skip an entry with no information; reading
    // through a null pointer would end the process.
    if (info == nullptr) return 1;
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
}

bool _ensure(Pointer<Void> catalog, String name) {
  final nativeName = name.toNativeUtf8();
  final ep = calloc<Pointer<Void>>();
  try {
    _check(
      winMLEpCatalogFindProvider(catalog, nativeName, nullptr, ep),
      'finding $name',
    );
    if (ep.value == nullptr) return false;
    if (winMLEpEnsureReady(ep.value) < 0) return false;
    return _libraryPath(ep.value).isNotEmpty;
  } finally {
    calloc.free(nativeName);
    calloc.free(ep);
  }
}

String _libraryPath(Pointer<Void> ep) {
  final size = calloc<Size>();
  final used = calloc<Size>();
  try {
    if (winMLEpGetLibraryPathSize(ep, size) < 0) return '';
    final buffer = calloc<Uint8>(size.value + 1).cast<Utf8>();
    try {
      // The header marks the bytes-used argument optional; it is passed and
      // checked anyway, as Microsoft's sample does.
      if (winMLEpGetLibraryPath(ep, size.value + 1, buffer, used) < 0 ||
          used.value == 0) {
        return '';
      }
      return buffer.toDartString();
    } finally {
      calloc.free(buffer);
    }
  } finally {
    calloc.free(size);
    calloc.free(used);
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
