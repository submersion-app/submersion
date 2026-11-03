/// Where the app keeps its own files.
///
/// Native builds ask `path_provider` (`app_directories_io.dart`). The browser
/// has no filesystem paths; its database and temporary files live in the
/// origin private file system, and the web file answers with fixed names
/// under an `/opfs` root so callers that only compose a path keep working.
library;

export 'package:submersion/core/platform/app_directories_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/platform/app_directories_web.dart';
