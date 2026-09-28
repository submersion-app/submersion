import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_presets_warm_up.dart';

/// Whether every google_fonts load in the isolate completes within [within].
Future<bool> _fontsSettle(Duration within) => GoogleFonts.pendingFonts()
    .then((_) => true, onError: (_) => true)
    .timeout(within, onTimeout: () => false);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('puts debugPrint and runtime fetching back', () async {
    final printBefore = debugPrint;
    final fetchingBefore = GoogleFonts.config.allowRuntimeFetching;

    await warmUpThemePresets();

    expect(identical(debugPrint, printBefore), isTrue);
    expect(GoogleFonts.config.allowRuntimeFetching, fetchingBefore);
  });

  test('returns within its bound while a font load is stranded', () async {
    final printBefore = debugPrint;
    final fetchingBefore = GoogleFonts.config.allowRuntimeFetching;
    debugPrint = (String? message, {int? wrapWidth}) {};
    GoogleFonts.config.allowRuntimeFetching = false;
    // Start a load on a fake clock and walk away from it, as a widget test
    // that is the first to build a Google Font does. Nothing advances that
    // clock, so the load cannot complete. Once the tear-down below lets it
    // run, it fails, as expected with no font bundled in the test assets, and
    // the failure reaches the guarded zone.
    late FakeAsync strandedClock;
    var strandedLoadFinished = false;
    fakeAsync((clock) {
      strandedClock = clock;
      runZonedGuarded(
        () => GoogleFonts.getFont('Lato'),
        (error, stack) => strandedLoadFinished = true,
      );
    });
    addTearDown(() async {
      // Drain the stranded load so it does not delay the files that share
      // this isolate: each real-async hop of the load needs a real turn of
      // the event loop, then a flush of the fake clock to run its
      // continuation. Other files may have stranded loads of their own, so
      // only this one is waited for.
      for (var i = 0; i < 100 && !strandedLoadFinished; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        strandedClock.flushMicrotasks();
      }
      GoogleFonts.config.allowRuntimeFetching = fetchingBefore;
      debugPrint = printBefore;
      expect(strandedLoadFinished, isTrue);
    });
    expect(await _fontsSettle(const Duration(milliseconds: 200)), isFalse);

    final elapsed = Stopwatch()..start();
    await warmUpThemePresets(limit: const Duration(milliseconds: 200));

    expect(elapsed.elapsed, lessThan(const Duration(seconds: 5)));
  });
}
