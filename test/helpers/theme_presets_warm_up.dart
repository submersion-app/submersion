import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';

import 'google_fonts_settle.dart';

/// Builds every theme preset outside a widget test, and waits for the
/// google_fonts loads that building them starts.
///
/// [AppThemeRegistry.presets] is built once per isolate, by whichever test
/// touches it first, and the console and tropical themes start google_fonts
/// loads as they are built. When the first touch is inside a `testWidgets`
/// body, the loads continue on that test's fake-async clock, which stops when
/// the test ends, so they never complete. Every later [settleGoogleFonts] in
/// the same CI isolate (issue #2500) then waits out its full limit.
///
/// Call it from `setUpAll`, which runs outside the fake clock, in a widget
/// test file that reads the registry and shares a bundle with a later file
/// that waits on the loads (see "Shared Isolates in CI" in
/// docs/developer/testing.md):
///
/// ```dart
/// setUpAll(warmUpThemePresets);
/// ```
///
/// The wait is [settleGoogleFonts], bounded by [limit], so a load some other
/// file left stranded delays this one instead of hanging it. Fetching fonts
/// over the network is turned off while the loads run, and the expected load
/// failures are kept out of the test output. Both are put back before it
/// returns, on every path.
Future<void> warmUpThemePresets({
  Duration limit = const Duration(seconds: 2),
}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalDebugPrint = debugPrint;
  final originalFetching = GoogleFonts.config.allowRuntimeFetching;
  debugPrint = (String? message, {int? wrapWidth}) {};
  GoogleFonts.config.allowRuntimeFetching = false;
  try {
    // The guarded zone keeps a load error from escaping as an uncaught error.
    await runZonedGuarded(() async {
      // ignore: unnecessary_statements
      AppThemeRegistry.presets;
      await settleGoogleFonts(limit: limit);
    }, (error, stack) {});
  } finally {
    GoogleFonts.config.allowRuntimeFetching = originalFetching;
    debugPrint = originalDebugPrint;
  }
}
