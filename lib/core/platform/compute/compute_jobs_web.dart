import 'dart:typed_data';

import 'package:submersion/core/platform/compute/compute_jobs_shared.dart';
import 'package:submersion/core/platform/compute/compute_protocol.dart';
import 'package:submersion/core/platform/compute/compute_worker_client.dart';
import 'package:submersion/core/platform/zlib/zlib_framing.dart';
import 'package:submersion/core/utils/off_isolate.dart'
    show OffIsolateRunner, isolateRun, kOffIsolateMinBytes;

/// Browser implementation of the compute facade: a job runs inline below
/// [minBytes] and in the compute worker above it. A worker that cannot start
/// is reported once and the job runs inline, as a failed isolate does on a
/// native build. [runner] is accepted for the shared signature and unused.
abstract final class ComputeJobs {
  static Future<Uint8List> inflateBounded(
    Uint8List bytes, {
    required int maxBytes,
    ZlibFraming framing = ZlibFraming.zlib,
    int minBytes = kOffIsolateMinBytes,
    OffIsolateRunner runner = isolateRun,
  }) => _run(
    ComputeJob.inflateBounded,
    {'bytes': bytes, 'maxBytes': maxBytes, 'framing': framing.name},
    bytes: bytes.length,
    minBytes: minBytes,
  );

  static Future<Uint8List> deflate(
    Uint8List bytes, {
    int level = 6,
    int minBytes = kOffIsolateMinBytes,
    OffIsolateRunner runner = isolateRun,
  }) => _run(
    ComputeJob.deflate,
    {'bytes': bytes, 'level': level},
    bytes: bytes.length,
    minBytes: minBytes,
  );

  static Future<Uint8List> gzip(
    Uint8List bytes, {
    int level = 6,
    int minBytes = kOffIsolateMinBytes,
    OffIsolateRunner runner = isolateRun,
  }) => _run(
    ComputeJob.gzip,
    {'bytes': bytes, 'level': level},
    bytes: bytes.length,
    minBytes: minBytes,
  );

  static Future<Uint8List> gunzip(
    Uint8List bytes, {
    int minBytes = kOffIsolateMinBytes,
    OffIsolateRunner runner = isolateRun,
  }) => _run(
    ComputeJob.gunzip,
    {'bytes': bytes},
    bytes: bytes.length,
    minBytes: minBytes,
  );

  static Future<Uint8List> aesGcmEncrypt({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List plaintext,
    Uint8List? aad,
    int minBytes = kOffIsolateMinBytes,
    OffIsolateRunner runner = isolateRun,
  }) => _run(
    ComputeJob.aesGcmEncrypt,
    {'key': key, 'nonce': nonce, 'plaintext': plaintext, 'aad': aad},
    bytes: plaintext.length,
    minBytes: minBytes,
  );

  static Future<Uint8List> aesGcmDecrypt({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List ciphertextWithMac,
    Uint8List? aad,
    int minBytes = kOffIsolateMinBytes,
    OffIsolateRunner runner = isolateRun,
  }) => _run(
    ComputeJob.aesGcmDecrypt,
    {
      'key': key,
      'nonce': nonce,
      'ciphertextWithMac': ciphertextWithMac,
      'aad': aad,
    },
    bytes: ciphertextWithMac.length,
    minBytes: minBytes,
  );

  static Future<Uint8List> argon2id({
    required Uint8List password,
    required Uint8List salt,
    required int memoryKiB,
    required int iterations,
    required int parallelism,
    required int hashLength,
    int minBytes = kOffIsolateMinBytes,
    OffIsolateRunner runner = isolateRun,
  }) => _run(
    ComputeJob.argon2id,
    argon2idArgs(
      password: password,
      salt: salt,
      memoryKiB: memoryKiB,
      iterations: iterations,
      parallelism: parallelism,
      hashLength: hashLength,
    ),
    bytes: memoryKiB * 1024,
    minBytes: minBytes,
  );

  static Future<Uint8List> sha256(
    Uint8List bytes, {
    int minBytes = kOffIsolateMinBytes,
    OffIsolateRunner runner = isolateRun,
  }) => _run(
    ComputeJob.sha256,
    {'bytes': bytes},
    bytes: bytes.length,
    minBytes: minBytes,
  );

  static Future<Uint8List> _run(
    ComputeJob job,
    Map<String, Object?> args, {
    required int bytes,
    required int minBytes,
  }) async {
    if (bytes < minBytes) return runComputeJobInline(job, args);
    try {
      return (await ComputeWorkerClient.instance.call(job, args))! as Uint8List;
    } on ComputeWorkerUnavailable {
      return runComputeJobInline(job, args);
    }
  }
}
