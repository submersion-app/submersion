import 'dart:async';
import 'dart:isolate';

/// A real isolate that keeps count. runOffIsolate reruns anything a worker
/// could not do on the calling isolate, so a closure that drags the database
/// along would still give the right answer. [failures] is what tells them
/// apart.
class IsolateHops {
  var count = 0;
  final failures = <Object>[];

  Future<R> run<R>(FutureOr<R> Function() work) async {
    count++;
    try {
      return await Isolate.run(work);
    } catch (e) {
      failures.add(e);
      rethrow;
    }
  }
}
