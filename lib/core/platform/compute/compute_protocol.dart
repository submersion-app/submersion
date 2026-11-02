import 'package:cryptography/cryptography.dart'
    show SecretBoxAuthenticationError;

import 'package:submersion/core/platform/zlib/zlib_exceptions.dart';

/// The jobs the compute worker runs for the app.
///
/// Native builds run the same jobs on an isolate; the browser posts them to
/// `compute_worker.js`. Every job's arguments and result are JSON scalars,
/// lists and maps plus `Uint8List` values, which is what `postMessage`
/// clones.
enum ComputeJob {
  inflateBounded,
  deflate,
  gzip,
  gunzip,
  aesGcmEncrypt,
  aesGcmDecrypt,
  argon2id,
  sha256,
  hashStart,
  hashAddPart,
  hashFinish,
  hashDispose,
  opfsCreate,
  opfsAppend,
  opfsWriteAt,
  opfsClose,
  opfsRead,
  opfsLength,
  opfsExists,
  opfsDelete,
  baseParseScalars,
  baseParseStart,
  baseParseNext,
  baseParseDispose,
}

/// One job call: [id] pairs it with its reply.
class ComputeRequest {
  const ComputeRequest({
    required this.id,
    required this.job,
    required this.args,
  });

  final int id;
  final ComputeJob job;
  final Map<String, Object?> args;

  Map<String, Object?> toJson() => {'id': id, 'job': job.name, 'args': args};

  factory ComputeRequest.fromJson(Map<Object?, Object?> json) => ComputeRequest(
    id: (json['id'] as num).toInt(),
    job: ComputeJob.values.byName(json['job'] as String),
    args: Map<String, Object?>.from(json['args'] as Map),
  );
}

/// The kinds of error a reply can carry, so the caller gets the exception
/// type it expects back from the other side of `postMessage`.
abstract final class ComputeErrorKind {
  static const String authentication = 'authentication';
  static const String bound = 'bound';
  static const String format = 'format';
  static const String state = 'state';
  static const String argument = 'argument';
  static const String other = 'other';
}

/// A reply to [ComputeRequest] with the same [id]: a result, an error, or a
/// progress tick for a long parse (which completes nothing).
class ComputeReply {
  const ComputeReply({
    required this.id,
    this.result,
    this.error,
    this.errorKind,
  }) : progressBytes = null,
       progressTotal = null;

  const ComputeReply.progress({
    required this.id,
    required int bytes,
    required int total,
  }) : result = null,
       error = null,
       errorKind = null,
       progressBytes = bytes,
       progressTotal = total;

  final int id;
  final Object? result;
  final String? error;
  final String? errorKind;
  final int? progressBytes;
  final int? progressTotal;

  bool get isProgress => progressBytes != null;

  Map<String, Object?> toJson() => {
    'id': id,
    if (result != null) 'result': result,
    if (error != null) 'error': error,
    if (errorKind != null) 'errorKind': errorKind,
    if (isProgress)
      'progress': {'bytes': progressBytes, 'total': progressTotal},
  };

  factory ComputeReply.fromJson(Map<Object?, Object?> json) {
    final progress = json['progress'];
    if (progress is Map) {
      return ComputeReply.progress(
        id: (json['id'] as num).toInt(),
        bytes: (progress['bytes'] as num).toInt(),
        total: (progress['total'] as num).toInt(),
      );
    }
    return ComputeReply(
      id: (json['id'] as num).toInt(),
      result: json['result'],
      error: json['error'] as String?,
      errorKind: json['errorKind'] as String?,
    );
  }
}

/// A job failed for a reason no caller catches by type.
class ComputeJobException implements Exception {
  const ComputeJobException(this.message, {this.kind = ComputeErrorKind.other});

  final String message;
  final String kind;

  @override
  String toString() => 'ComputeJobException($kind): $message';
}

/// The wire kind for [error], so the other side can rebuild its type.
String computeErrorKindOf(Object error) => switch (error) {
  SecretBoxAuthenticationError() => ComputeErrorKind.authentication,
  ZlibBoundExceeded() => ComputeErrorKind.bound,
  ZlibFormatException() => ComputeErrorKind.format,
  StateError() => ComputeErrorKind.state,
  ArgumentError() => ComputeErrorKind.argument,
  _ => ComputeErrorKind.other,
};

/// The exception a reply of [kind] stands for. [args] are the request's
/// arguments, which supply the cap a bound error names.
Object computeErrorFromWire(
  String kind,
  String message,
  Map<String, Object?> args,
) => switch (kind) {
  ComputeErrorKind.authentication => SecretBoxAuthenticationError(),
  ComputeErrorKind.bound => ZlibBoundExceeded(
    (args['maxBytes'] as num?)?.toInt() ?? 0,
  ),
  ComputeErrorKind.format => ZlibFormatException(message),
  ComputeErrorKind.state => StateError(message),
  ComputeErrorKind.argument => ArgumentError(message),
  _ => ComputeJobException(message, kind: kind),
};
