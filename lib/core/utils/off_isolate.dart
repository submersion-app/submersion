/// Running CPU-heavy work off the calling isolate.
///
/// Native builds hop to a one-shot isolate (`off_isolate_io.dart`). A browser
/// has no isolates: the work that must leave the main thread goes through
/// the compute worker instead, and what reaches these helpers runs inline
/// (`off_isolate_web.dart`).
library;

export 'package:submersion/core/utils/off_isolate_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/utils/off_isolate_web.dart';
export 'package:submersion/core/utils/off_isolate_types.dart';
