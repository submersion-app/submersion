import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/logger_service.dart';

/// Downloads network videos into a directory so the player can open them as
/// files.
///
/// A video player opens a URL without the headers a source may need (a
/// shared album's session cookie is one), so a video from such a source is
/// fetched here with them and played from disk. A file already here is
/// reused; one download per URL runs at a time; the directory is kept under
/// [maxBytes] by deleting the least recently used files.
class NetworkVideoCache {
  NetworkVideoCache({
    required http.Client client,
    required Future<Directory> Function() directory,
    required Future<Map<String, String>?> Function(Uri uri) headersFor,
    this.maxBytes = 2 * 1024 * 1024 * 1024,
  }) : _client = client,
       _directory = directory,
       _headersFor = headersFor;

  final http.Client _client;
  final Future<Directory> Function() _directory;
  final Future<Map<String, String>?> Function(Uri uri) _headersFor;

  /// Upper bound of the directory's size after a download.
  final int maxBytes;

  final _log = LoggerService.forClass(NetworkVideoCache);
  final Map<String, Future<String?>> _downloads = {};

  /// A local file holding the video at [url], downloading it when it is not
  /// here yet; null when it could not be fetched (logged, never thrown: the
  /// viewer shows its own "not found" then).
  Future<String?> fileFor(Uri url) {
    final key = sha1.convert(utf8.encode(url.toString())).toString();
    return _downloads[key] ??= _fetch(
      url,
      key,
    ).whenComplete(() => _downloads.remove(key));
  }

  Future<String?> _fetch(Uri url, String key) async {
    final dir = await _directory();
    final target = File(p.join(dir.path, '$key.mp4'));
    if (await target.exists() && await target.length() > 0) {
      // Touched so eviction keeps what is watched.
      await target.setLastModified(DateTime.now());
      return target.path;
    }
    await dir.create(recursive: true);
    final part = File('${target.path}.part');
    try {
      final headers = await _headersFor(url) ?? const <String, String>{};
      final response = await _client.send(
        http.Request('GET', url)..headers.addAll(headers),
      );
      final type = response.headers['content-type'] ?? '';
      // A source that answers an error as a page or JSON (a share's lost
      // session, a refused password) is not a video, whatever its status.
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          type.contains('json') ||
          type.contains('html')) {
        await response.stream.drain<void>();
        _log.warning(
          'Video download refused for ${url.host}: '
          'HTTP ${response.statusCode}, $type',
        );
        return null;
      }
      final sink = part.openWrite();
      try {
        await response.stream.pipe(sink);
      } finally {
        await sink.close();
      }
      await part.rename(target.path);
      await _evict(dir, keep: target.path);
      return target.path;
    } catch (e, st) {
      _log.warning('Video download failed for ${url.host}: $e', stackTrace: st);
      if (await part.exists()) await part.delete();
      return null;
    }
  }

  /// Deletes the least recently used files until the directory fits
  /// [maxBytes], never [keep] (the file about to play).
  Future<void> _evict(Directory dir, {required String keep}) async {
    try {
      final files = [
        for (final e in await dir.list().toList())
          if (e is File && !e.path.endsWith('.part')) e,
      ];
      final stats = {for (final f in files) f: await f.stat()};
      var total = stats.values.fold<int>(0, (sum, s) => sum + s.size);
      final oldestFirst = [...files]
        ..sort((a, b) => stats[a]!.modified.compareTo(stats[b]!.modified));
      for (final f in oldestFirst) {
        if (total <= maxBytes) break;
        if (f.path == keep) continue;
        total -= stats[f]!.size;
        await f.delete();
      }
    } catch (e) {
      _log.warning('Video cache cleanup failed: $e');
    }
  }
}
