/// The hasher a base transfer runs its part and whole-file digests through.
///
/// Native builds hash a large transfer on a worker isolate
/// (`base_part_hasher_io.dart`); the browser hashes it in the compute worker
/// (`base_part_hasher_web.dart`). Small transfers hash inline on both.
library;

export 'package:submersion/core/services/sync/changeset_log/base_part_hasher_inline.dart';
export 'package:submersion/core/services/sync/changeset_log/base_part_hasher_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/services/sync/changeset_log/base_part_hasher_web.dart';
export 'package:submersion/core/services/sync/changeset_log/base_part_hasher_types.dart';
