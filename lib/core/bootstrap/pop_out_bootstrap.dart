/// Starts a desktop pop-out window's engine (issue #5078) instead of the
/// app, when this engine was launched as one. Browsers have no pop-outs.
library;

export 'package:submersion/core/bootstrap/pop_out_bootstrap_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/bootstrap/pop_out_bootstrap_web.dart';
