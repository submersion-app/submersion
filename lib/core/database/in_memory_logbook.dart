/// A logbook and local cache that live in memory and are gone once closed
/// (issue #5122): what species identification writes for a file the diver
/// has not kept goes here, never into the open logbook.
///
/// Native only; a browser has no Identify.
library;

export 'package:submersion/core/database/in_memory_logbook_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/database/in_memory_logbook_web.dart';
