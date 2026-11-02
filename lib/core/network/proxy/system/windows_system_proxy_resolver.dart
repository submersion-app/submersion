/// The Windows system proxy resolver.
///
/// Native builds ask WinHTTP over FFI (`windows_system_proxy_resolver_io.dart`).
/// The browser cannot, and does not need to: the browser applies the system
/// proxy to every request itself, so the web variant reports "direct".
library;

export 'package:submersion/core/network/proxy/system/windows_system_proxy_resolver_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/network/proxy/system/windows_system_proxy_resolver_web.dart';
