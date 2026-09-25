import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/canvas/decoded_photo_cache.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);
Uint8List _bytes(int v) => Uint8List.fromList([v]);

void main() {
  test('a superseded decode is disposed and never stored', () async {
    final disposed = <String>[];
    final cache = DecodedPhotoCache<String>(dispose: disposed.add);
    final pending = <String, Completer<String>>{};
    Future<String> decode(Uint8List bytes) {
      final key = 'img${bytes.first}';
      return (pending[key] = Completer<String>()).future;
    }

    final first = cache.sync({_b('a'): _bytes(1), _b('b'): _bytes(2)}, decode);
    final second = cache.sync({_b('b'): _bytes(2), _b('c'): _bytes(3)}, decode);
    // The first loop is parked on its first decode (a); the second loop
    // starts b and c. Complete everything out of order.
    var i = 0;
    for (final c in pending.values.toList()) {
      if (!c.isCompleted) {
        c.complete('v${i++}');
      }
    }
    await Future<void>.delayed(Duration.zero);
    // The first loop resumes and tries b: complete it too.
    for (final c in pending.values.toList()) {
      if (!c.isCompleted) {
        c.complete('late');
      }
    }
    await Future.wait([first, second]);

    expect(cache.images.keys.toSet(), {_b('b'), _b('c')});
    final kept = cache.images.values.toSet();
    for (final d in disposed) {
      expect(kept, isNot(contains(d)), reason: 'a kept image was disposed');
    }
    expect(
      disposed,
      isNotEmpty,
      reason: 'the stale decode of a must be disposed',
    );
  });

  test('sync removes unwanted images and disposes them', () async {
    final disposed = <String>[];
    final cache = DecodedPhotoCache<String>(dispose: disposed.add);
    await cache.sync({_b('a'): _bytes(1)}, (b) async => 'A');
    expect(cache.images, {_b('a'): 'A'});
    await cache.sync({}, (b) async => 'never');
    expect(cache.images, isEmpty);
    expect(disposed, ['A']);
  });

  test('a decode failure leaves the node without a photo', () async {
    final cache = DecodedPhotoCache<String>(dispose: (_) {});
    await cache.sync({
      _b('a'): _bytes(1),
    }, (b) async => throw StateError('corrupt'));
    expect(cache.images, isEmpty);
  });

  test('disposeAll clears and disposes everything', () async {
    final disposed = <String>[];
    final cache = DecodedPhotoCache<String>(dispose: disposed.add);
    await cache.sync({
      _b('a'): _bytes(1),
      _b('b'): _bytes(2),
    }, (b) async => 'v${b.first}');
    cache.disposeAll();
    expect(cache.images, isEmpty);
    expect(disposed.toSet(), {'v1', 'v2'});
  });
}
