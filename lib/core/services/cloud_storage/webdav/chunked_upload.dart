import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_multistatus.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart'
    show TransferProgressCallback;

/// Resume state for one chunked upload, persisted by the media queue and
/// replayed verbatim on retry.
class ChunkedUploadState {
  const ChunkedUploadState({
    required this.transferId,
    required this.chunkSize,
    required this.total,
    required this.dest,
  });

  final String transferId;
  final int chunkSize;
  final int total;

  /// The destination URL the chunks are assembled into.
  final String dest;

  Map<String, Object?> toJson() => {
    'v': 1,
    'transferId': transferId,
    'chunkSize': chunkSize,
    'total': total,
    'dest': dest,
  };

  String toJsonString() => jsonEncode(toJson());

  /// Null for absent, malformed or foreign state; never throws.
  static ChunkedUploadState? tryParse(String? json) {
    if (json == null) return null;
    try {
      final map = jsonDecode(json);
      if (map is! Map<String, Object?> || map['v'] != 1) return null;
      return ChunkedUploadState(
        transferId: map['transferId']! as String,
        chunkSize: map['chunkSize']! as int,
        total: map['total']! as int,
        dest: map['dest']! as String,
      );
    } catch (_) {
      return null;
    }
  }
}

/// The chunked upload protocol (v2) some WebDAV servers offer beside
/// `files/<user>/`: MKCOL an upload directory under `uploads/<user>/`, PUT
/// numbered chunks into it, then MOVE its `.file` onto the destination.
/// Gets past server and proxy body-size limits and lets an interrupted
/// media upload resume.
class ChunkedUpload {
  ChunkedUpload(
    this._client, {
    String Function()? newTransferId,
    Duration pollDelay = const Duration(seconds: 10),
    int pollAttempts = 6,
  }) : _newTransferId =
           newTransferId ?? (() => '$transferPrefix${const Uuid().v4()}'),
       _pollDelay = pollDelay,
       _pollAttempts = pollAttempts;

  final WebDavClient _client;
  final String Function() _newTransferId;
  final Duration _pollDelay;
  final int _pollAttempts;

  /// Deadline for the assembly MOVE. The server concatenates the chunks
  /// inside that request before it answers, which takes minutes for a large
  /// video, so the 30 second header deadline a bodiless request normally
  /// gets would fire mid-assembly and retry into a lock.
  static Duration moveDeadline(int totalBytes) {
    final scaled = Duration(seconds: totalBytes ~/ _minAssemblyBytesPerSecond);
    const floor = Duration(minutes: 10);
    return scaled > floor ? scaled : floor;
  }

  static const int _minAssemblyBytesPerSecond = 4 * 1024 * 1024;

  /// Whether [destPath] already holds all [total] bytes.
  Future<bool> _destinationComplete(String destPath, int total) async {
    final info = await _client.stat(destPath);
    return info != null && info.sizeBytes == total;
  }

  /// Waits out an assembly that is still running server-side.
  Future<bool> _awaitAssembled(String destPath, int total) async {
    for (var attempt = 0; attempt < _pollAttempts; attempt++) {
      if (await _destinationComplete(destPath, total)) return true;
      await Future<void>.delayed(_pollDelay);
    }
    return _destinationComplete(destPath, total);
  }

  static const int chunkBytes = 10 * 1024 * 1024;
  static const int thresholdBytes = chunkBytes;
  static const String transferPrefix = 'submersion-';

  static bool appliesTo(WebDavClient client, int length) =>
      client.config.chunkedUploadsRoot != null &&
      !client.chunkingUnsupported &&
      length > thresholdBytes;

  static String chunkName(int n) => n.toString().padLeft(5, '0');

  /// Derived once: the config is immutable, and every chunk addresses it.
  late final Uri? _uploadsRoot = _client.config.chunkedUploadsRoot;

  Uri get _uploads => _uploadsRoot!;

  Uri _under(Uri base, List<String> extra) => base.replace(
    pathSegments: [...base.pathSegments.where((s) => s.isNotEmpty), ...extra],
  );

  /// Uploads [source] to [destPath]. False when the server has no chunking
  /// (the caller falls back to a single PUT); the client remembers that.
  Future<bool> upload(
    String destPath,
    File source, {
    String? resumeStateJson,
    void Function(String resumeStateJson)? onResumeStateChanged,
    TransferProgressCallback? onProgress,
  }) async {
    final total = await source.length();
    final dest = _client.uriFor(destPath).toString();
    var state = ChunkedUploadState.tryParse(resumeStateJson);
    if (state != null &&
        (state.total != total ||
            state.dest != dest ||
            state.chunkSize != chunkBytes)) {
      state = null;
    }

    var present = <String, int>{};
    if (state != null) {
      try {
        final listing = await _client.propfindRaw(
          _under(_uploads, [state.transferId, '']),
          1,
        );
        present = {
          for (final r in listing)
            if (!r.isCollection && r.pathSegments.isNotEmpty)
              r.pathSegments.last: r.contentLength ?? -1,
        };
      } on WebDavException catch (e) {
        if (e.code != WebDavErrorCode.notFound) rethrow;
        // The directory is gone: the server expired it, or an earlier attempt
        // finished assembling it before its reply was lost.
        if (await _destinationComplete(destPath, total)) {
          onProgress?.call(total, total);
          return true;
        }
        state = null;
      }
    }

    await _client.ensureCollection(WebDavClient.parentOf(destPath));
    if (state == null) {
      final fresh = ChunkedUploadState(
        transferId: _newTransferId(),
        chunkSize: chunkBytes,
        total: total,
        dest: dest,
      );
      final response = await _client.request(
        'MKCOL',
        _under(_uploads, [fresh.transferId, '']),
        headers: {'destination': dest},
        // The address shape alone turns chunking on, so any refusal of the
        // uploads collection short of an auth failure means a single PUT.
        accept: const {400, 403, 404, 405, 409, 415, 501},
      );
      await response.stream.drain<void>();
      if (response.statusCode != 201) {
        _client.chunkingUnsupported = true;
        return false;
      }
      state = fresh;
      onResumeStateChanged?.call(state.toJsonString());
    }

    final headers = {'destination': dest, 'oc-total-length': '$total'};
    final count = (total + chunkBytes - 1) ~/ chunkBytes;
    final raf = await source.open();
    var sent = 0;
    try {
      for (var n = 1; n <= count; n++) {
        final offset = (n - 1) * chunkBytes;
        final size = min(chunkBytes, total - offset);
        final name = chunkName(n);
        if (present[name] != size) {
          await raf.setPosition(offset);
          final bytes = await raf.read(size);
          final response = await _client.request(
            'PUT',
            _under(_uploads, [state.transferId, name]),
            headers: headers,
            bytes: bytes,
          );
          await response.stream.drain<void>();
        }
        sent += size;
        onProgress?.call(sent, total);
      }
    } finally {
      await raf.close();
    }

    try {
      final response = await _client.request(
        'MOVE',
        _under(_uploads, [state.transferId, '.file']),
        headers: {...headers, 'overwrite': 'T'},
        timeout: moveDeadline(total),
      );
      await response.stream.drain<void>();
    } on WebDavException catch (e) {
      // A retried MOVE whose first attempt landed finds its source gone; one
      // that timed out or hit the assembly lock may still be finishing.
      const settling = {
        WebDavErrorCode.notFound,
        WebDavErrorCode.locked,
        WebDavErrorCode.unreachable,
        WebDavErrorCode.server,
      };
      if (!settling.contains(e.code)) rethrow;
      if (!await _awaitAssembled(destPath, total)) rethrow;
    }
    return true;
  }

  /// Best effort; never throws on malformed state.
  Future<void> abandon(String? resumeStateJson) async {
    final state = ChunkedUploadState.tryParse(resumeStateJson);
    if (state == null || _uploadsRoot == null) return;
    try {
      final response = await _client.request(
        'DELETE',
        _under(_uploads, [state.transferId, '']),
        accept: const {404},
      );
      await response.stream.drain<void>();
    } catch (_) {
      // The server expires abandoned upload directories on its own.
    }
  }

  /// Deletes this app's upload directories last touched before
  /// [olderThan]; returns how many.
  Future<int> reapStale(DateTime olderThan) async {
    if (_uploadsRoot == null) return 0;
    final List<DavResource> listing;
    try {
      listing = await _client.propfindRaw(_under(_uploads, ['']), 1);
    } on WebDavException catch (e) {
      if (e.code == WebDavErrorCode.notFound) return 0;
      rethrow;
    }
    var reaped = 0;
    final ownDepth =
        _uploads.pathSegments.where((s) => s.isNotEmpty).length + 1;
    for (final r in listing) {
      final segs = r.pathSegments;
      final modified = r.lastModified;
      if (!r.isCollection || segs.length != ownDepth) continue;
      if (!segs.last.startsWith(transferPrefix)) continue;
      if (modified == null || !modified.isBefore(olderThan)) continue;
      final response = await _client.request(
        'DELETE',
        _under(_uploads, [segs.last, '']),
        accept: const {404},
      );
      await response.stream.drain<void>();
      reaped++;
    }
    return reaped;
  }
}
