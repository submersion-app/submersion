import 'dart:typed_data';

import 'package:cryptography/cryptography.dart'
    show SecretBoxAuthenticationError;

import 'package:submersion/core/platform/compute/compute_jobs_shared.dart';
import 'package:submersion/core/platform/compute/compute_protocol.dart';
import 'package:submersion/core/platform/zlib/zlib_exceptions.dart';
import 'package:submersion/core/platform/zlib/zlib_framing.dart';
import 'package:submersion/core/utils/off_isolate.dart';

/// Native implementation of the compute facade: each job runs on a one-shot
/// isolate through [runOffIsolate] once the payload reaches [minBytes], and
/// inline otherwise, with the same fallback the sync code has always had.
///
/// [minBytes] and [runner] are the test seams the callers already expose.
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
    runner: runner,
    isExpected: (e) => e is ZlibBoundExceeded || e is ZlibFormatException,
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
    runner: runner,
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
    runner: runner,
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
    runner: runner,
    isExpected: (e) => e is ZlibFormatException,
  );

  /// AES-256-GCM; the result is the ciphertext followed by the 16 byte tag.
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
    runner: runner,
  );

  /// AES-256-GCM; [ciphertextWithMac] is the ciphertext followed by the
  /// 16 byte tag. Throws [SecretBoxAuthenticationError] on a wrong key,
  /// nonce, tag or additional data.
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
    runner: runner,
    isExpected: (e) => e is SecretBoxAuthenticationError,
  );

  /// Argon2id. Its cost is the memory parameter, not the password, so the
  /// threshold is measured against [memoryKiB].
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
    runner: runner,
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
    runner: runner,
  );

  static Future<Uint8List> _run(
    ComputeJob job,
    Map<String, Object?> args, {
    required int bytes,
    required int minBytes,
    required OffIsolateRunner runner,
    bool Function(Object error)? isExpected,
  }) => runOffIsolate(
    // A fresh handler inside the closure: it captures only the job and its
    // arguments, both of which cross the isolate boundary.
    () => runComputeJobInline(job, args),
    bytes: bytes,
    minBytes: minBytes,
    isExpected: isExpected,
    runner: runner,
  );
}
