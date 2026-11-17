import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';

/// Where the model pack's manifest is published (issue #4668). A
/// development build points it at a locally served pack with
/// `--dart-define=SPECIES_PACK_MANIFEST_URL=...`.
const String kSpeciesPackManifestUrl = String.fromEnvironment(
  'SPECIES_PACK_MANIFEST_URL',
  defaultValue:
      'https://github.com/submersion-app/submersion/releases/download/species-pack/manifest.json',
);

enum PackDownloadFailure {
  network,
  httpStatus,
  checksumMismatch,
  sizeMismatch,
  cancelled,

  /// The file could not be written: usually a full disk.
  storage,

  /// The manifest is a format this build does not know.
  unsupportedFormat,

  /// The published manifest is broken.
  malformed,
}

class PackDownloadException implements Exception {
  const PackDownloadException(this.reason, [this.detail]);

  final PackDownloadFailure reason;
  final String? detail;

  @override
  String toString() =>
      'PackDownloadException(${reason.name}${detail == null ? '' : ': $detail'})';
}

/// Fetches the published model pack manifest.
class SpeciesPackManifestClient {
  SpeciesPackManifestClient({
    http.Client? client,
    Uri? url,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client(),
       _url = url ?? Uri.parse(kSpeciesPackManifestUrl);

  final http.Client _client;
  final Uri _url;
  final Duration timeout;

  /// Null when nothing is published (HTTP 404).
  Future<SpeciesPackManifest?> fetch() async {
    final http.Response response;
    try {
      response = await _client.get(_url).timeout(timeout);
    } on TimeoutException {
      throw const PackDownloadException(PackDownloadFailure.network, 'timeout');
    } on Exception catch (e) {
      throw PackDownloadException(PackDownloadFailure.network, '$e');
    }
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw PackDownloadException(
        PackDownloadFailure.httpStatus,
        'HTTP ${response.statusCode}',
      );
    }
    try {
      // Always UTF-8: release assets come with no charset, and
      // `response.body` would then read them as Latin-1.
      return SpeciesPackManifest.parse(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
    } on PackManifestException catch (e) {
      throw PackDownloadException(
        e.reason == PackManifestFailure.unsupportedFormat
            ? PackDownloadFailure.unsupportedFormat
            : PackDownloadFailure.malformed,
        e.detail,
      );
    }
  }

  /// A pack's files are published beside its manifest.
  Uri fileUrl(PackFile file) => _url.resolve(file.name);
}

/// Downloads one pack file, verified against its manifest entry.
///
/// Bytes go to `<dest>.part`, and the file is renamed into place only when
/// its size and SHA-256 match. A broken connection, a cancel or a full disk
/// keeps the part, and the next attempt resumes it with a Range request; a
/// file that fails verification is discarded.
class SpeciesPackDownloader {
  SpeciesPackDownloader({
    http.Client? client,
    this.connectTimeout = const Duration(seconds: 30),
    this.idleTimeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration connectTimeout;
  final Duration idleTimeout;

  Future<void> downloadFile({
    required Uri url,
    required PackFile file,
    required File dest,
    void Function(int receivedForThisFile)? onProgress,
    bool Function()? isCancelled,
  }) async {
    // Finished by an earlier attempt: kept only if its hash still matches,
    // so a file republished under the same version is fetched again.
    if (await _length(dest) == file.size) {
      if (await _digestOf(dest) == file.sha256) {
        onProgress?.call(file.size);
        return;
      }
      await _delete(dest);
    }
    final part = File('${dest.path}.part');
    var existing = await _length(part);
    if (existing > file.size) {
      await _delete(part);
      existing = 0;
    }
    if (existing == file.size) {
      if (await _digestOf(part) == file.sha256) {
        onProgress?.call(existing);
        return _rename(part, dest);
      }
      await _delete(part);
      existing = 0;
    }

    final request = http.Request('GET', url);
    if (existing > 0) request.headers['Range'] = 'bytes=$existing-';
    final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(connectTimeout);
    } on TimeoutException {
      throw const PackDownloadException(PackDownloadFailure.network, 'timeout');
    } on Exception catch (e) {
      throw PackDownloadException(PackDownloadFailure.network, '$e');
    }
    final resuming = existing > 0 && response.statusCode == 206;
    if (!resuming && response.statusCode != 200) {
      await response.stream.drain<void>().catchError((_) {});
      throw PackDownloadException(
        PackDownloadFailure.httpStatus,
        'HTTP ${response.statusCode}',
      );
    }
    if (!resuming) existing = 0;

    final digest = _DigestSink();
    final hasher = sha256.startChunkedConversion(digest);
    if (resuming) {
      await for (final chunk in part.openRead()) {
        hasher.add(chunk);
      }
    }

    // Each chunk is written before the next is read: a full disk ends the
    // download at the failing chunk, and nothing piles up in memory.
    final RandomAccessFile out;
    try {
      await part.parent.create(recursive: true);
      out = await part.open(mode: resuming ? FileMode.append : FileMode.write);
    } on FileSystemException catch (e) {
      throw PackDownloadException(PackDownloadFailure.storage, e.message);
    }

    var received = existing;
    var oversize = false;
    try {
      try {
        await for (final chunk in response.stream.timeout(idleTimeout)) {
          if (isCancelled?.call() ?? false) {
            throw const PackDownloadException(PackDownloadFailure.cancelled);
          }
          received += chunk.length;
          if (received > file.size) {
            oversize = true;
            break;
          }
          await out.writeFrom(chunk);
          hasher.add(chunk);
          onProgress?.call(received);
        }
      } finally {
        await out.close();
      }
    } on PackDownloadException {
      rethrow;
    } on FileSystemException catch (e) {
      throw PackDownloadException(PackDownloadFailure.storage, e.message);
    } on TimeoutException {
      throw const PackDownloadException(PackDownloadFailure.network, 'stalled');
    } on Exception catch (e) {
      throw PackDownloadException(PackDownloadFailure.network, '$e');
    }

    if (oversize) {
      await _delete(part);
      throw PackDownloadException(
        PackDownloadFailure.sizeMismatch,
        'more than ${file.size} bytes',
      );
    }
    if (received < file.size) {
      // The body ended early: keep what arrived for a resume.
      throw PackDownloadException(
        PackDownloadFailure.network,
        'ended at $received of ${file.size} bytes',
      );
    }
    hasher.close();
    if (digest.value.toString() != file.sha256) {
      await _delete(part);
      throw const PackDownloadException(PackDownloadFailure.checksumMismatch);
    }
    await _rename(part, dest);
  }

  static Future<int> _length(File file) async {
    try {
      return await file.exists() ? await file.length() : 0;
    } on FileSystemException {
      return 0;
    }
  }

  static Future<void> _delete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Nothing to do: the next attempt starts over either way.
    }
  }

  static Future<String> _digestOf(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  static Future<void> _rename(File part, File dest) async {
    try {
      if (await dest.exists()) await dest.delete();
      await part.rename(dest.path);
    } on FileSystemException catch (e) {
      throw PackDownloadException(PackDownloadFailure.storage, e.message);
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
