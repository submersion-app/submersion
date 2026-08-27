import 'dart:async';

import 'package:submersion/core/services/logger_service.dart';

/// Start [work] without awaiting it, attributing a failure to [owner] in the
/// log rather than leaving it to the zone handler.
///
/// A Dart future with NO listener sends its error to the zone. In the running
/// app `main`'s `runZonedGuarded` catches that and logs it, so nothing is lost,
/// but it arrives as a bare "Uncaught zone error" with no clue what started it.
///
/// Under `package:test` there is no such safety net. The error is attributed to
/// whichever test happens to be running when it surfaces, so work that outlives
/// its own test fails a LATER, unrelated test with "This test failed after it
/// had already completed". Which test that is depends on timing, which is why
/// re-running the job usually clears it and why the failure never seems to
/// belong to the branch that hit it.
///
/// A load started in a notifier constructor or an `initState` is the common
/// case: the test finishes, teardown closes the database, and the query that
/// is still in flight fails with nobody listening.
///
/// Attaching a listener is the whole fix. [work] itself is untouched, and a
/// Dart future may carry several listeners, so anything that also awaits it
/// still sees the error and still has to handle it.
void logFailure(Future<void> work, Type owner, String task) {
  // The future catchError hands back is of no interest: attaching the listener
  // is the entire point, and unawaited says that rather than leaving a reader
  // to wonder whether the drop was an oversight.
  unawaited(
    work.catchError((Object error, StackTrace stackTrace) {
      LoggerService.forClass(
        owner,
      ).error('Failed to $task', error: error, stackTrace: stackTrace);
    }),
  );
}
