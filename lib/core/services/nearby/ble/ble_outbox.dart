import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:submersion/core/services/nearby/nearby_carrier.dart';

/// What a peripheral has to send one central, served to that central's
/// reads.
///
/// Notifications have no flow control a Flutter peripheral can see (Apple
/// rejects them once its queue is full, Android drops them), so bulk data
/// goes the other way round: the central reads the outbox characteristic
/// and each read is answered from here. A read is a request and a
/// response, so the link paces itself on every platform.
class BleOutbox {
  BleOutbox({this.highWater = 64 * 1024});

  /// [enqueue] waits while more than this many bytes are waiting.
  final int highWater;

  final _chunks = Queue<Uint8List>();
  int _headOffset = 0;
  int _queued = 0;
  Uint8List _current = Uint8List(0);
  final _waiters = <Completer<void>>[];
  final _drainWaiters = <Completer<void>>[];
  bool _closed = false;

  bool get isEmpty => _queued == 0;

  /// Completes once every queued byte has been read, or the outbox closed.
  /// A peripheral cannot hang up on a central, so a closing one waits on
  /// this: its last frames (a refusal, a bye) are how the central learns
  /// the session is over.
  Future<void> get drained {
    if (_closed || isEmpty) return Future.value();
    final waiter = Completer<void>();
    _drainWaiters.add(waiter);
    return waiter.future;
  }

  /// Queues [bytes]; completes once at most [highWater] bytes are waiting.
  /// Throws [NearbyLinkClosed] once the outbox is closed.
  Future<void> enqueue(Uint8List bytes) async {
    if (_closed) throw const NearbyLinkClosed();
    if (bytes.isNotEmpty) {
      _chunks.add(bytes);
      _queued += bytes.length;
    }
    while (_queued > highWater) {
      final room = Completer<void>();
      _waiters.add(room);
      await room.future;
    }
  }

  /// The answer to a read at [offset]. At offset 0 the next chunk of up to
  /// [maxLength] bytes is taken from the queue (empty when nothing waits).
  /// A read past 0 continues the chunk last taken: [platformSlices] says
  /// whether the platform cuts the value at the offset itself (Apple) or
  /// sends exactly what it is given (Android).
  Uint8List read({
    required int offset,
    required int maxLength,
    required bool platformSlices,
  }) {
    if (offset > 0) {
      if (platformSlices || offset >= _current.length) return _current;
      return Uint8List.sublistView(_current, offset);
    }
    final out = BytesBuilder(copy: false);
    while (out.length < maxLength && _chunks.isNotEmpty) {
      final head = _chunks.first;
      final take = (head.length - _headOffset).clamp(0, maxLength - out.length);
      out.add(Uint8List.sublistView(head, _headOffset, _headOffset + take));
      _headOffset += take;
      if (_headOffset == head.length) {
        _chunks.removeFirst();
        _headOffset = 0;
      }
    }
    _current = out.takeBytes();
    _queued -= _current.length;
    if (_queued <= highWater) _wake();
    if (_queued == 0) _wakeDrained();
    return _current;
  }

  void _wake() {
    for (final waiter in _waiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _waiters.clear();
  }

  void _wakeDrained() {
    for (final waiter in _drainWaiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _drainWaiters.clear();
  }

  void close() {
    _closed = true;
    _chunks.clear();
    _queued = 0;
    for (final waiter in _waiters) {
      if (!waiter.isCompleted) waiter.completeError(const NearbyLinkClosed());
    }
    _waiters.clear();
    _wakeDrained();
  }
}
