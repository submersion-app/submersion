import 'dart:async';

/// Below this many bytes the CPU work this helper is used for takes a few
/// milliseconds at most, so an isolate buys nothing. It also keeps small
/// manifests, changesets and markers on the calling isolate and in its zone.
const int kOffIsolateMinBytes = 256 * 1024;

/// Inflating costs what the output costs, and the input is what is known up
/// front. A threshold on compressed bytes divides by about this, a little over
/// what a repetitive base compresses by.
const int kCompressedCostFactor = 8;

typedef OffIsolateRunner = Future<R> Function<R>(FutureOr<R> Function() work);
