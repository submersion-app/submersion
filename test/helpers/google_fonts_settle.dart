import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Waits briefly for pending Google Fonts loads, and never for ever.
///
/// google_fonts keeps every pending load in one set for the whole isolate,
/// and [GoogleFonts.pendingFonts] waits for all of them. A load started inside
/// another file's widget test never finishes once that test's fake clock
/// stops, so in a test bundle (issue #2500) an unbounded wait hangs until the
/// test times out. The loads a theme test starts itself fail within
/// milliseconds, because runtime fetching is off and the fonts are not in the
/// test assets.
Future<void> settleGoogleFonts({
  Duration limit = const Duration(seconds: 2),
}) async {
  try {
    await GoogleFonts.pendingFonts().timeout(limit);
  } catch (_) {
    // A load that failed, or one that belongs to another file's test: either
    // way there is nothing left worth waiting for.
  }
}
