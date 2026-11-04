import 'dart:async';

/// A finished future to start a lazy singleton's work chain from.
///
/// A future remembers the zone it was made in and schedules every listener
/// there, finished or not. A lazy singleton is made by whichever caller
/// touches it first, and in a widget test that is a fake-async zone whose
/// microtasks stop running when the test ends. A chain started from a plain
/// `Future.value()` there never runs again for the isolate, and CI runs many
/// test files in one. Made in the root zone, it always runs.
Future<void> rootZoneFuture() => Zone.root.run(Future<void>.value);
