/// Process start-up, behind one entry point so `lib/main.dart` serves every
/// platform and `flutter build web` needs no target flag.
///
/// The native bootstrap (`app_bootstrap_io.dart`) installs the HTTP
/// overrides, migrates the Windows app-data folders and starts the proxy
/// controller before it loads preferences and attaches the log file. The
/// browser bootstrap (`app_bootstrap_web.dart`) has none of those: the
/// browser owns networking, and there are no folders to migrate.
library;

export 'package:submersion/core/bootstrap/app_bootstrap_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/bootstrap/app_bootstrap_web.dart';
