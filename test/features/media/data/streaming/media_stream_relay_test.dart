import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/media_streaming.dart';
import 'package:submersion/features/media/data/streaming/media_stream_relay.dart';

/// A store holding one object of [total] bytes (byte i is i % 251), read a
/// range at a time; counts its heads and reads.
class _RangeStore implements MediaObjectStore, RangeReadStore {
  _RangeStore(this.total);

  final int total;
  int heads = 0;
  int reads = 0;
  bool failReads = false;

  /// Reads return nothing, as a server ignoring Range does for an object
  /// shorter than its listed size.
  bool emptyReads = false;

  @override
  Future<StoreObjectInfo?> head(String key) async {
    heads++;
    return StoreObjectInfo(
      key: key,
      sizeBytes: total,
      lastModified: DateTime.utc(2026),
    );
  }

  @override
  Future<Uint8List> readRange(
    String key, {
    required int start,
    required int endInclusive,
  }) async {
    reads++;
    if (failReads) {
      throw const MediaStoreException(
        'offline',
        kind: MediaStoreErrorKind.transient,
      );
    }
    if (emptyReads) return Uint8List(0);
    final end = endInclusive < total ? endInclusive : total - 1;
    return Uint8List.fromList([for (var i = start; i <= end; i++) i % 251]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final base = Uri.parse('https://app.test/sub/');
  late _RangeStore store;
  late MediaStreamRelay relay;
  late String ticket;

  setUp(() {
    store = _RangeStore(10000);
    relay = MediaStreamRelay(
      base: base,
      chunkBytes: 1000,
      newTicket: () => 'ticket1',
    );
    final url = relay.register(store: store, key: 'k', extension: 'mp4');
    expect(url, Uri.parse('https://app.test/sub/media-stream/ticket1'));
    ticket = 'ticket1';
  });

  test('the default chunk is 2 MiB', () {
    expect(kRelayChunkBytes, 2 * 1024 * 1024);
  });

  test('answers bytes=0- with the first chunk', () async {
    final answer = await relay.answer(ticket, 'bytes=0-');
    expect(answer.status, 206);
    expect(answer.headers, {
      'Content-Range': 'bytes 0-999/10000',
      'Content-Length': '1000',
      'Content-Type': 'video/mp4',
      'Accept-Ranges': 'bytes',
    });
    expect(answer.body, hasLength(1000));
    expect(answer.body!.first, 0);
  });

  test('clamps bytes=0-1', () async {
    final answer = await relay.answer(ticket, 'bytes=0-1');
    expect(answer.headers['Content-Range'], 'bytes 0-1/10000');
    expect(answer.body, [0, 1]);
  });

  test('handles a request with no Range header', () async {
    final answer = await relay.answer(ticket, null);
    expect(answer.status, 206);
    expect(answer.headers['Content-Range'], 'bytes 0-999/10000');
  });

  test('clamps the end to the total', () async {
    final answer = await relay.answer(ticket, 'bytes=9500-20000');
    expect(answer.headers['Content-Range'], 'bytes 9500-9999/10000');
    expect(answer.body, hasLength(500));
    expect(answer.body!.first, 9500 % 251);
  });

  test('answers 416 at or past the end', () async {
    final answer = await relay.answer(ticket, 'bytes=10000-');
    expect(answer.status, 416);
    expect(answer.headers['Content-Range'], 'bytes */10000');
    expect(answer.body, isNull);
    expect(store.reads, 0);
  });

  test('answers 416 for a range it cannot parse', () async {
    final answer = await relay.answer(ticket, 'bytes=-500');
    expect(answer.status, 416);
    expect(store.reads, 0);
  });

  test('answers 416 for a range that ends before it starts', () async {
    final answer = await relay.answer(ticket, 'bytes=500-100');
    expect(answer.status, 416);
    expect(store.reads, 0);
  });

  test('answers 404 for an unknown or released ticket', () async {
    expect((await relay.answer('nope', 'bytes=0-')).status, 404);
    relay.release(Uri.parse('https://app.test/sub/media-stream/ticket1'));
    expect((await relay.answer(ticket, 'bytes=0-')).status, 404);
  });

  test('answers 502 when the store read throws', () async {
    store.failReads = true;
    expect((await relay.answer(ticket, 'bytes=0-')).status, 502);
  });

  test('answers 502 when the store returns no bytes', () async {
    // An empty 206 would leave the worker asking for the same range again
    // and again.
    store.emptyReads = true;
    expect((await relay.answer(ticket, 'bytes=0-')).status, 502);
  });

  test('heads the store once per ticket', () async {
    await relay.answer(ticket, 'bytes=0-');
    await relay.answer(ticket, 'bytes=1000-');
    expect(store.heads, 1);
  });

  test('refuses a store that cannot read ranges', () {
    expect(
      () => relay.register(store: _NoRanges(), key: 'k', extension: 'mp4'),
      throwsArgumentError,
    );
  });

  test('tickets are 32 hex characters by default', () {
    final url = MediaStreamRelay(
      base: base,
    ).register(store: store, key: 'k', extension: 'mov');
    expect(url.pathSegments.last, matches(RegExp(r'^[0-9a-f]{32}$')));
  });
}

class _NoRanges implements MediaObjectStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
