import 'dart:typed_data';

import 'package:submersion/core/platform/compute/compute_job_handlers.dart';
import 'package:submersion/core/platform/compute/compute_protocol.dart';
import 'package:submersion/core/platform/compute/opfs_files.dart';

/// Runs a stateless [job] on the calling thread. Shared by the native and
/// browser facades for payloads below the off-thread threshold, and by the
/// native isolate as the body it runs.
Future<Uint8List> runComputeJobInline(
  ComputeJob job,
  Map<String, Object?> args,
) async {
  final result = await ComputeJobHandler(
    files: const UnavailableOpfsFiles(),
  ).handle(job, args);
  return result! as Uint8List;
}

/// The arguments for an Argon2id derivation, shared so both facades send
/// the same shape.
Map<String, Object?> argon2idArgs({
  required Uint8List password,
  required Uint8List salt,
  required int memoryKiB,
  required int iterations,
  required int parallelism,
  required int hashLength,
}) => {
  'password': password,
  'salt': salt,
  'memoryKiB': memoryKiB,
  'iterations': iterations,
  'parallelism': parallelism,
  'hashLength': hashLength,
};
