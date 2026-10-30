import 'dart:async';
import 'dart:developer' as developer;
import 'dart:isolate';

/// Below this many bytes the CPU work this helper is used for takes a few
/// milliseconds at most, so an isolate buys nothing. It also keeps small
/// manifests, changesets and markers on the calling isolate and in its zone.
const int kOffIsolateMinBytes = 256 * 1024;

/// Inflating costs what the output costs, and the input is what is known up
/// front. A threshold on compressed bytes divides by about this, a little over
/// what a repetitive base compresses by.
const int kCompressedCostFactor = 8;

typedef OffIsolateRunner = Future<R> Function<R>(FutureOr<R> Function() work);

/// [Isolate.run] as a value, for callers that pass a test seam through.
Future<R> isolateRun<R>(FutureOr<R> Function() work) => Isolate.run(work);

/// Runs [work] in a one-shot isolate when [bytes] reaches [minBytes], and
/// inline otherwise, so CPU-heavy work on a large payload does not stall the
/// calling isolate. On the app's UI isolate, that is a dropped frame.
///
/// [isExpected] names the errors that are real answers about the data, such as
/// a failed authentication. They are rethrown. Anything else (the isolate
/// could not start, it died, or a message could not be sent) says nothing
/// about the data, so [work] reruns inline and the caller sees what it would
/// have seen without the isolate.
///
/// That makes [work] responsible for being repeatable, which is why this is
/// for stateless work. A closure declared inside a method can capture the
/// whole enclosing context, keys included, so [work] should be a small
/// function that closes over its arguments alone.
Future<T> runOffIsolate<T>(
  FutureOr<T> Function() work, {
  required int bytes,
  int minBytes = kOffIsolateMinBytes,
  bool Function(Object error)? isExpected,
  OffIsolateRunner runner = isolateRun,
}) async {
  if (bytes < minBytes) return work();
  try {
    return await runner<T>(work);
  } catch (e) {
    if (isExpected?.call(e) ?? false) rethrow;
    // Logged here, not through LoggerService, to stay free of Flutter imports.
    developer.log(
      'Running on this isolate instead',
      name: 'runOffIsolate',
      error: e,
    );
    return work();
  }
}
