/// The HTTP client the app builds when a caller injects none.
///
/// Native builds wrap `dart:io`'s HttpClient so the TCP connect is bounded
/// and the app's proxy and certificate hooks apply
/// (`platform_http_client_io.dart`). The browser sends every request through
/// the page's own fetch, where the browser owns timeouts, proxies and
/// certificate trust, so the web variant ignores those arguments.
library;

export 'package:submersion/core/network/platform_http_client_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/network/platform_http_client_web.dart';
