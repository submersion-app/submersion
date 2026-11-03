/// Where this build keeps a credential.
///
/// Native builds use the OS keychain through `flutter_secure_storage`, with
/// the macOS legacy keychain when the data-protection keychain is closed to
/// the build (`secure_storage_backend_io.dart`). The browser has no
/// keychain: it keeps a session store in page memory and, when the user
/// asks to be remembered, browser local storage
/// (`secure_storage_backend_web.dart`). `FallbackSecureStorage` is the
/// wrapper every credentials store goes through; this is what it wraps.
library;

export 'package:submersion/core/platform/secure_storage_backend_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/platform/secure_storage_backend_web.dart';
