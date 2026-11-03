import 'dart:async';

import 'package:submersion/core/utils/off_isolate_types.dart';

/// Browser variant of [isolateRun]: there are no isolates, so [work] runs
/// on the calling thread.
Future<R> isolateRun<R>(FutureOr<R> Function() work) async => await work();

/// Browser variant of `runOffIsolate`: [work] runs inline whatever [bytes]
/// says. [isExpected] and [runner] are accepted for the shared signature; an
/// error from [work] reaches the caller as it would from inline native work.
Future<T> runOffIsolate<T>(
  FutureOr<T> Function() work, {
  required int bytes,
  int minBytes = kOffIsolateMinBytes,
  bool Function(Object error)? isExpected,
  OffIsolateRunner runner = isolateRun,
}) async => await work();
