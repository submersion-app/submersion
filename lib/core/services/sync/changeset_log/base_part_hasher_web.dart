import 'dart:typed_data';

import 'package:submersion/core/platform/compute/compute_protocol.dart';
import 'package:submersion/core/platform/compute/compute_worker_client.dart';
import 'package:submersion/core/services/sync/changeset_log/base_part_hasher_inline.dart';
import 'package:submersion/core/services/sync/changeset_log/base_part_hasher_types.dart';
import 'package:submersion/core/utils/off_isolate.dart'
    show kOffIsolateMinBytes;

/// Opens the hasher for a transfer whose first part is [firstPartBytes]
/// long: inline for a small one, a session in the compute worker for a large
/// one. A worker that cannot start degrades to inline and reports the cause
/// through [onWorkerUnavailable].
Future<BasePartHasher> openBasePartHasher(
  int firstPartBytes, {
  void Function(Object error)? onWorkerUnavailable,
}) async {
  if (firstPartBytes < kOffIsolateMinBytes) return InlineBasePartHasher();
  try {
    return await ComputeBasePartHasher.open();
  } catch (e) {
    onWorkerUnavailable?.call(e);
    return InlineBasePartHasher();
  }
}

/// One hash session in the compute worker, holding the rolling digest. A
/// failure latches: the call in flight and every later call throw
/// [BasePartHasherException], since the rolling hash is lost with the
/// session.
class ComputeBasePartHasher implements BasePartHasher {
  ComputeBasePartHasher._(this._session);

  final int _session;
  bool _failed = false;
  bool _disposed = false;

  static Future<ComputeBasePartHasher> open() async {
    final session = await ComputeWorkerClient.instance.call(
      ComputeJob.hashStart,
      const {},
    );
    return ComputeBasePartHasher._((session as num).toInt());
  }

  @override
  Future<String> addPart(Uint8List part) =>
      _call(ComputeJob.hashAddPart, {'session': _session, 'bytes': part});

  @override
  Future<String> finish() =>
      _call(ComputeJob.hashFinish, {'session': _session});

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await ComputeWorkerClient.instance.call(ComputeJob.hashDispose, {
        'session': _session,
      });
    } catch (_) {
      // Releasing a session that died with its worker has nothing to do.
    }
  }

  Future<String> _call(ComputeJob job, Map<String, Object?> args) async {
    if (_failed) {
      throw BasePartHasherException('the hash session failed earlier');
    }
    try {
      return (await ComputeWorkerClient.instance.call(job, args)) as String;
    } catch (e) {
      _failed = true;
      throw BasePartHasherException('$e');
    }
  }
}
