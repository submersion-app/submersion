/// Where demo mode keeps its state, the preferences it set aside and the
/// sample logbook (issue #3708). Natively it is a directory of files under
/// the app support folder; a browser keeps the state and the snapshot in
/// local storage and the logbook as one of drift's databases (issue #4121).
library;

export 'package:submersion/features/demo_mode/data/demo_state_store_io.dart'
    if (dart.library.js_interop) 'package:submersion/features/demo_mode/data/demo_state_store_web.dart';
