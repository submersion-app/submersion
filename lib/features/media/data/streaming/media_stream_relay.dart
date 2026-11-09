import 'dart:math';
import 'dart:typed_data';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/media_streaming.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';

/// The most a relayed answer carries. The stream worker stitches pieces of
/// this size into the whole range a browser asked for.
const int kRelayChunkBytes = 2 * 1024 * 1024;

/// One answer to a relayed request, as the stream worker turns it into a
/// response.
class RelayAnswer {
  const RelayAnswer({required this.status, this.headers = const {}, this.body});

  final int status;
  final Map<String, String> headers;
  final Uint8List? body;
}

/// The page's side of the media stream worker (issue #4162).
///
/// A video from Google Drive or WebDAV plays from a same-site
/// `media-stream/<ticket>` address. The worker relays each of the player's
/// requests here, with its `Range` header, and this reads that range
/// through the store the page is already signed in to: no credential ever
/// leaves the page. Each answer carries at most [chunkBytes]; the worker
/// asks again for the rest.
class MediaStreamRelay {
  MediaStreamRelay({
    required this.base,
    this.chunkBytes = kRelayChunkBytes,
    String Function()? newTicket,
  }) : _newTicket = newTicket ?? _randomTicket;

  /// The page's base address; stream addresses sit under it, so a site
  /// hosted under a sub-path works.
  final Uri base;
  final int chunkBytes;
  final String Function() _newTicket;
  final Map<String, _Ticket> _tickets = {};

  static const _log = LoggerService(
    'MediaStreamRelay',
    category: LogCategory.media,
  );

  static final Random _random = Random.secure();

  static String _randomTicket() => [
    for (var i = 0; i < 16; i++)
      _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();

  /// The address a player streams [key] of [store] from, until [release].
  /// [extension] gives the response's content type.
  Uri register({
    required MediaObjectStore store,
    required String key,
    required String extension,
  }) {
    if (store is! RangeReadStore) {
      throw ArgumentError.value(store, 'store', 'cannot read ranges');
    }
    final ticket = _newTicket();
    _tickets[ticket] = _Ticket(
      store: store,
      reader: store as RangeReadStore,
      key: key,
      contentType: StoreKeys.contentTypeFor(extension),
    );
    return base.resolve('media-stream/$ticket');
  }

  /// Forgets the ticket in [url]; later requests for it answer 404.
  void release(Uri url) {
    if (url.pathSegments.isEmpty) return;
    _tickets.remove(url.pathSegments.last);
  }

  /// Answers one relayed request for [ticket] with [range] (a `Range`
  /// header, or null for none, read as `bytes=0-`).
  Future<RelayAnswer> answer(String ticket, String? range) async {
    final entry = _tickets[ticket];
    if (entry == null) return const RelayAnswer(status: 404);
    try {
      final total = await entry.total();
      final match = RegExp(
        r'^bytes=(\d+)-(\d*)$',
      ).firstMatch(range ?? 'bytes=0-');
      final start = match == null ? null : int.parse(match.group(1)!);
      if (start == null || start >= total) {
        return RelayAnswer(
          status: 416,
          headers: {'Content-Range': 'bytes */$total'},
        );
      }
      final asked = match!.group(2)!.isEmpty
          ? total - 1
          : int.parse(match.group(2)!);
      final end = min(min(asked, total - 1), start + chunkBytes - 1);
      final body = await entry.reader.readRange(
        entry.key,
        start: start,
        endInclusive: end,
      );
      final last = start + body.length - 1;
      return RelayAnswer(
        status: 206,
        headers: {
          'Content-Range': 'bytes $start-$last/$total',
          'Content-Length': '${body.length}',
          'Content-Type': entry.contentType,
          'Accept-Ranges': 'bytes',
        },
        body: body,
      );
    } on Exception catch (e) {
      _log.warning('Stream read failed for ${entry.key}: $e');
      return const RelayAnswer(status: 502);
    }
  }
}

class _Ticket {
  _Ticket({
    required this.store,
    required this.reader,
    required this.key,
    required this.contentType,
  });

  final MediaObjectStore store;
  final RangeReadStore reader;
  final String key;
  final String contentType;
  int? _total;

  /// The object's size, asked of the store until it answers once. A failed
  /// ask is not kept, so the next request tries again.
  Future<int> total() async {
    final known = _total;
    if (known != null) return known;
    final size = (await store.head(key))?.sizeBytes;
    if (size == null) {
      throw MediaStoreException(
        'no size for $key',
        kind: MediaStoreErrorKind.notFound,
      );
    }
    return _total = size;
  }
}
