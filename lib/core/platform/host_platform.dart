/// What the app runs on.
///
/// Every platform question the app asks goes through here, so the browser
/// build can answer it without `dart:io`. The native file reads
/// `dart:io`'s `Platform` unchanged (`host_platform_io.dart`), so native
/// behaviour and every existing test are what they were; the web file
/// (`host_platform_web.dart`) answers from the browser's `navigator`.
library;

export 'package:submersion/core/platform/host_platform_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/platform/host_platform_web.dart';
