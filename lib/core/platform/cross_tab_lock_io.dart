/// Native variant: one process, so the body runs with no further lock.
Future<T> withCrossTabLock<T>(String name, Future<T> Function() body) => body();

/// Native variant: nothing else holds a lock here, so the body always runs.
Future<bool> withCrossTabLockIfAvailable(
  String name,
  Future<void> Function() body,
) async {
  await body();
  return true;
}
