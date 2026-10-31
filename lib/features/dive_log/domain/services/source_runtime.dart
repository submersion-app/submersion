/// The runtime of a dive whose measured snapshot follows one data source, in
/// seconds.
///
/// `Dive.effectiveRuntime` trusts a stored runtime before it looks at the
/// timestamps, so anything that rebuilds a dive from a single source (split, a
/// primary swap) has to replace the runtime along with the entry and exit
/// times, or the dive keeps the previous source's figure across the new
/// source's span (issue #3899).
///
/// [durationSeconds] is what the source measured (issue #2421) and wins. A
/// source that reports none falls back to the span from [entryTimeMs] to
/// [exitTimeMs], under the guard `Dive.effectiveRuntime` applies: a zero or
/// negative span means the timestamps are unusable, not that the dive lasted
/// no time. Null when neither gives a runtime.
int? sourceRuntimeSeconds({
  required int? durationSeconds,
  required int? entryTimeMs,
  required int? exitTimeMs,
}) {
  if (durationSeconds != null && durationSeconds > 0) return durationSeconds;
  if (entryTimeMs == null || exitTimeMs == null) return null;
  if (exitTimeMs <= entryTimeMs) return null;
  final seconds = (exitTimeMs - entryTimeMs) ~/ Duration.millisecondsPerSecond;
  return seconds > 0 ? seconds : null;
}
