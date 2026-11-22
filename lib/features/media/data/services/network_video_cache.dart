import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/motion_photo.dart';

/// Downloads network videos into a directory so the player can open them as
/// files.
///
/// A video player opens a URL without the headers a source may need (a
/// shared album's session cookie is one), so a video from such a source is
/// fetched here with them and played from disk. A file already here is
/// reused; one download per URL runs at a time; the directory is kept under
/// [maxBytes] by deleting the least recently used files, never the one
/// about to play.
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

  /// Upper bound of the directory's size after a download, apart from the
  /// file just fetched: it is about to play, so it stays even when it alone
  /// is larger, and goes on the next download like any other file.
  /// Refusing it instead would leave a long video unplayable.
  final int maxBytes;

  final _log = LoggerService.forClass(NetworkVideoCache);
  final Map<String, Future<String?>> _downloads = {};

  /// A local file holding the video at [url], downloading it when it is not
  /// here yet; null when it could not be fetched (logged, never thrown: the
  /// viewer shows its own "not found" then).
  Future<String?> fileFor(Uri url) {
    final key = sha1.convert(utf8.encode(url.toString())).toString();
    // The callback must return nothing: whenComplete waits for a Future it
    // returns, and Map.remove would return this very future, which then
    // waits on itself forever.
    return _downloads[key] ??=
        _guarded(() => _fetch(url, key), 'Video download', url).whenComplete(
          () {
            _downloads.remove(key);
          },
        );
  }

  /// [body], with any failure (the cache directory unavailable, a file the
  /// OS refuses) logged and answered as null, as [fileFor] and
  /// [motionClipFor] promise: their callers resolve media and must fall
  /// through to "not found", not fail.
  Future<String?> _guarded(
    Future<String?> Function() body,
    String what,
    Uri url,
  ) async {
    try {
      return await body();
    } catch (e, st) {
      _log.warning('$what failed for ${url.host}: $e', stackTrace: st);
      return null;
    }
  }

  /// Whether the photo at [url] is a motion photo, from its first
  /// [kMotionPhotoProbeBytes] (a Range request; a server that ignores Range
  /// is read only that far). Null when it could not be read. Remembered per
  /// URL for the session: a viewer pages back and forth.
  Future<bool?> isMotionPhoto(Uri url) {
    final key = url.toString();
    final known = _motionProbes[key];
    if (known != null) return known;
    final probe = _probeMotion(url);
    _motionProbes[key] = probe;
    // A failed read is asked again next time.
    unawaited(
      probe.then((v) {
        if (v == null) _motionProbes.remove(key);
      }),
    );
    return probe;
  }

  final Map<String, Future<bool?>> _motionProbes = {};

  Future<bool?> _probeMotion(Uri url) async {
    try {
      final headers = await _headersFor(url) ?? const <String, String>{};
      final response = await _client.send(
        http.Request('GET', url)
          ..headers.addAll(headers)
          ..headers['Range'] = 'bytes=0-${kMotionPhotoProbeBytes - 1}',
      );
      final type = response.headers['content-type'] ?? '';
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          type.contains('json') ||
          type.contains('html')) {
        await response.stream.drain<void>();
        return null;
      }
      final head = BytesBuilder(copy: false);
      await for (final chunk in response.stream) {
        head.add(chunk);
        if (head.length >= kMotionPhotoProbeBytes) break;
      }
      return looksLikeMotionPhoto(head.takeBytes());
    } catch (e) {
      _log.warning('Motion photo probe failed for ${url.host}: $e');
      return null;
    }
  }

  /// A local MP4 file with the video appended to the motion photo at
  /// [url]: the photo is downloaded once, the clip cut out and kept beside
  /// the downloaded videos. Null when there is none or it could not be read.
  Future<String?> motionClipFor(Uri url) {
    final key = 'motion-${sha1.convert(utf8.encode(url.toString()))}';
    return _downloads[key] ??=
        _guarded(
          () => _cutMotionClip(url, key),
          'Motion photo download',
          url,
        ).whenComplete(() {
          _downloads.remove(key);
        });
  }

  Future<String?> _cutMotionClip(Uri url, String key) async {
    final dir = await _directory();
    final target = File(p.join(dir.path, '$key.mp4'));
    if (await target.exists() && await target.length() > 0) {
      return target.path;
    }
    try {
      final headers = await _headersFor(url) ?? const <String, String>{};
      final response = await _client.send(
        http.Request('GET', url)..headers.addAll(headers),
      );
      final type = response.headers['content-type'] ?? '';
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          type.contains('json') ||
          type.contains('html')) {
        await response.stream.drain<void>();
        _log.warning(
          'Motion photo download refused for ${url.host}: '
          'HTTP ${response.statusCode}, $type',
        );
        return null;
      }
      final bytes = await response.stream.toBytes();
      final clip = extractMotionVideo(bytes);
      if (clip == null) {
        _log.info('No motion video in the photo from ${url.host}');
        return null;
      }
      await dir.create(recursive: true);
      await target.writeAsBytes(clip, flush: true);
      await _evict(dir, keep: target.path);
      return target.path;
    } catch (e, st) {
      _log.warning(
        'Motion photo download failed for ${url.host}: $e',
        stackTrace: st,
      );
      return null;
    }
  }

  Future<String?> _fetch(Uri url, String key) async {
    final dir = await _directory();
    final target = File(p.join(dir.path, '$key.mp4'));
    if (await target.exists() && await target.length() > 0) {
      // Touched so eviction keeps what is watched. A file the player still
      // holds may refuse it; the video plays all the same.
      try {
        await target.setLastModified(DateTime.now());
      } catch (_) {}
      _log.debug('Video served from cache: $key');
      return target.path;
    }
    _log.info('Downloading video from ${url.host} into the cache: $key');
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
      try {
        if (await part.exists()) await part.delete();
      } catch (_) {}
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
