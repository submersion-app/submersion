/// Temporary files for streaming sync: the base a device exports before it
/// uploads it in parts, and the base it assembles from a peer's parts before
/// it applies them.
///
/// Native builds keep them in the app's temp directory
/// (`sync_temp_files_io.dart`). The browser keeps them in the origin private
/// file system through the compute worker (`sync_temp_files_web.dart`),
/// the one OPFS write path all three browsers share; its paths are
/// `opfs://submersion-sync-tmp/<name>`.
library;

export 'package:submersion/core/services/sync/changeset_log/sync_temp_files_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/services/sync/changeset_log/sync_temp_files_web.dart';
export 'package:submersion/core/services/sync/changeset_log/sync_temp_sink.dart';
