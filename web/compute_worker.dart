// The browser's compute worker.
//
// Compiled apart from the Flutter app by scripts/web/compile_workers.sh, so
// everything it reaches must be plain Dart (the worker import-graph guard
// checks that). It runs the jobs native code runs on isolates: inflating
// and compressing sync payloads, AES-GCM, Argon2id, hashing, and streaming
// a large sync base to and from a temporary file in the origin private file
// system. One request in, one reply out, matched by id; a long parse also
// posts progress ticks.
import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:submersion/core/platform/compute/compute_job_handlers.dart';
import 'package:submersion/core/platform/compute/compute_protocol.dart';
import 'package:submersion/core/platform/compute/opfs_files_fallback.dart';
import 'package:submersion/core/platform/compute/opfs_files_web.dart';

void main() {
  final self = globalContext as web.DedicatedWorkerGlobalScope;
  final handler = ComputeJobHandler(files: FallbackOpfsFiles(WebOpfsFiles()));
  self.onmessage = ((web.MessageEvent event) {
    unawaited(_serve(self, handler, event.data.dartify()));
  }).toJS;
}

Future<void> _serve(
  web.DedicatedWorkerGlobalScope self,
  ComputeJobHandler handler,
  Object? data,
) async {
  if (data is! Map) return;
  void post(ComputeReply reply) => self.postMessage(reply.toJson().jsify());
  final ComputeRequest request;
  try {
    request = ComputeRequest.fromJson(data.cast<Object?, Object?>());
  } catch (e) {
    final id = data['id'];
    if (id is num) {
      post(
        ComputeReply(
          id: id.toInt(),
          error: 'malformed request: $e',
          errorKind: ComputeErrorKind.argument,
        ),
      );
    }
    return;
  }
  try {
    final result = await handler.handle(
      request.job,
      request.args,
      onProgress: (bytes, total) => post(
        ComputeReply.progress(id: request.id, bytes: bytes, total: total),
      ),
    );
    post(ComputeReply(id: request.id, result: result));
  } catch (e) {
    post(
      ComputeReply(
        id: request.id,
        error: e.toString(),
        errorKind: computeErrorKindOf(e),
      ),
    );
  }
}
