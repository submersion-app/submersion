/// Root certificates from the Windows certificate store.
///
/// Native builds read the live `ROOT` store over FFI
/// (`windows_root_store_io.dart`); every other platform, the browser
/// included, gets an empty list, since the browser owns certificate trust.
library;

export 'package:submersion/core/network/windows_root_store_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/network/windows_root_store_web.dart';
