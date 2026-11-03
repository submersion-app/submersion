/// The client of the base-file parse worker: pass one for the scalars and
/// deletions, pass two for the data rows of the requested tables, pulled a
/// batch at a time.
///
/// Native builds parse on an isolate (`base_parse_client_io.dart`); the
/// browser parses in the compute worker over a temporary file in the origin
/// private file system (`base_parse_client_web.dart`).
library;

export 'package:submersion/core/services/sync/changeset_log/base_parse_client_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/services/sync/changeset_log/base_parse_client_web.dart';
export 'package:submersion/core/services/sync/changeset_log/base_parse_exception.dart';
