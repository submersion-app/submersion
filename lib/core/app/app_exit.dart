import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:clock/clock.dart';

/// Hard ceiling on database closing during app exit.
///
/// Deliberately shorter than the sum of the close helpers' own internal
/// timeouts, which come to roughly 13 seconds across the two databases. Those
/// are `Future.timeout`s: they cannot interrupt work already in progress, and
/// they cannot fire at all if the isolate is blocked, so they bound the happy
/// path and nothing else. This is the bound that holds regardless.
const Duration kAppExitCloseBudget = Duration(seconds: 8);

/// Closes both databases, then answers the platform's exit request.
///
/// **Always** completes with [AppExitResponse.exit], never throws, and never
/// takes longer than [budget].
///
/// That totality is the whole point of the function existing. On macOS the
/// inherited `FlutterAppDelegate.applicationShouldTerminate` returns
/// `NSTerminateLater` and hands the decision to Dart; this handler is the only
/// thing that can send the reply, and nothing on the native side re-checks. An
/// unguarded throw, or a close that never returns, therefore left AppKit
/// deferring forever: the window had already been dismissed, so the user saw
/// the app quit while the process stayed alive. Reported against the Media
/// section, whose local-file reads are the likeliest thing to be in flight at
/// quit. `AppDelegate`'s watchdog is the backstop for the case this cannot
/// reach, a main isolate too blocked to run any of these timers.
///
/// The two closes run sequentially and share one budget. Sequentially because
/// racing two shutdown sequences is not worth the second it saves; one shared
/// budget because a budget per close would make the worst case twice what the
/// name promises. [closeCache] is attempted even when [closeMain] fails or
/// times out, so one bad database cannot strand the other, and it is attempted
/// even when the remainder is zero: `Future.timeout(Duration.zero)` still runs
/// the close, it just does not wait, which is strictly better than skipping it.
Future<AppExitResponse> closeDatabasesForExit({
  required Future<void> Function() closeMain,
  required Future<void> Function() closeCache,
  Duration budget = kAppExitCloseBudget,
  void Function(Object error, StackTrace stack)? onError,
}) async {
  // clock.now() rather than a Stopwatch: a Stopwatch reads the wall clock, so
  // under fake_async the budget would never deplete and the shared-budget
  // guarantee below would be untestable, which is how the two-closes case got
  // written wrong the first time.
  final startedAt = clock.now();

  Duration remaining() {
    final left = budget - clock.now().difference(startedAt);
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> attempt(Future<void> Function() close) async {
    try {
      await close().timeout(remaining());
    } catch (error, stack) {
      onError?.call(error, stack);
    }
  }

  await attempt(closeMain);
  await attempt(closeCache);
  return AppExitResponse.exit;
}
