import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:submersion/features/demo_mode/domain/demo_manifest.dart';

enum DemoDownloadFailure {
  network,
  httpStatus,
  checksumMismatch,
  sizeMismatch,
  cancelled,
}

class DemoDownloadException implements Exception {
  const DemoDownloadException(this.reason, [this.detail]);

  final DemoDownloadFailure reason;
  final String? detail;

  @override
  String toString() =>
      'DemoDownloadException(${reason.name}${detail == null ? '' : ': $detail'})';
}

/// Downloads a sample logbook package and checks it against the manifest.
///
/// The body streams to `<dest>.tmp` while its SHA-256 is computed, and the
/// file is renamed to [dest] only when both the size and the hash match.
/// Every failure deletes the temporary file, so a broken or tampered download
/// never reaches the extractor.
class DemoDownloader {
  DemoDownloader({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<File> download(
    DemoPackage pkg,
    File dest, {
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    await dest.parent.create(recursive: true);
    final tmp = File('${dest.path}.tmp');
    try {
      await _streamTo(pkg, tmp, onProgress, isCancelled);
      await tmp.rename(dest.path);
      return dest;
    } finally {
      if (await tmp.exists()) await tmp.delete();
    }
  }

  Future<void> _streamTo(
    DemoPackage pkg,
    File tmp,
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  ) async {
    final http.StreamedResponse response;
    try {
      response = await _client.send(http.Request('GET', pkg.url));
    } on Exception catch (e) {
      throw DemoDownloadException(DemoDownloadFailure.network, '$e');
    }
    if (response.statusCode != 200) {
      throw DemoDownloadException(
        DemoDownloadFailure.httpStatus,
        '${response.statusCode}',
      );
    }

    final digest = _DigestSink();
    final hasher = sha256.startChunkedConversion(digest);
    final out = tmp.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        if (isCancelled?.call() ?? false) {
          throw const DemoDownloadException(DemoDownloadFailure.cancelled);
        }
        received += chunk.length;
        if (received > pkg.size) {
          throw const DemoDownloadException(DemoDownloadFailure.sizeMismatch);
        }
        hasher.add(chunk);
        out.add(chunk);
        onProgress?.call(received, pkg.size);
      }
    } on DemoDownloadException {
      rethrow;
    } on Exception catch (e) {
      throw DemoDownloadException(DemoDownloadFailure.network, '$e');
    } finally {
      await out.close();
    }
    hasher.close();

    if (received != pkg.size) {
      throw const DemoDownloadException(DemoDownloadFailure.sizeMismatch);
    }
    if (digest.value.toString() != pkg.sha256) {
      throw const DemoDownloadException(DemoDownloadFailure.checksumMismatch);
    }
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
