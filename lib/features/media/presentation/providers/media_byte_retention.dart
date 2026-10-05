export 'package:submersion/core/providers/retain_for.dart' show retainFor;

/// How long a byte-carrying media provider is held exempt from auto-disposal,
/// measured from when it builds. See [retainFor] for the exact semantics.
///
/// Riverpod 3 flipped a default that matters a great deal here: `FutureProvider`
/// takes `isAutoDispose = false` (riverpod 3.4.2,
/// `providers/future_provider.dart:107`), so a `.family` returning a
/// `Uint8List` retains one full-resolution image buffer PER KEY for the whole
/// process lifetime. Every photo the user opened stayed on the heap until the
/// app died, which on Android means it gets killed first (#1175).
///
/// The answer is not "cache nothing": the providers were made caching on
/// purpose, so that a swipe back to the previous photo does not re-read it
/// from the photo library. A window keeps that and drops the permanence.
/// [fullResolutionRetention] is short because the objects are megabytes each;
/// [thumbnailRetention] is longer because they are tens of kilobytes and
/// re-fetching one costs a PhotoKit round-trip.
const Duration fullResolutionRetention = Duration(seconds: 30);

/// See [fullResolutionRetention].
const Duration thumbnailRetention = Duration(minutes: 5);
