/// Native variant: one process, so the body runs with no further lock.
Future<T> withCrossTabLock<T>(String name, Future<T> Function() body) => body();
