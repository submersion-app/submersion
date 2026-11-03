/// Hands a file to the user in a browser: a download (issue #4121).
///
/// Native builds have the share sheet and the save dialog, reached through
/// `file_export_utils`, so the native file here only says it is not a
/// browser download and refuses to be used.
library;

export 'package:submersion/core/platform/file_saver_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/platform/file_saver_web.dart';
