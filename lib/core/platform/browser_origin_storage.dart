/// The browser's storage for this origin and the page itself: removing a
/// top-level entry of the origin private file system, and reloading the
/// page. Native builds have neither (`browser_origin_storage_io.dart`
/// throws); the web file reaches `navigator.storage` and `window.location`.
library;

export 'package:submersion/core/platform/browser_origin_storage_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/platform/browser_origin_storage_web.dart';
