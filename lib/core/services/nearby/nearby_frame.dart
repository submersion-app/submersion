import 'dart:async';
import 'dart:typed_data';

/// The message types of the nearby link protocol.
///
/// The [code] is what travels on the wire, so codes are never renumbered or
/// reused; a new type takes the next free code and bumps the protocol minor
/// version in the hello.
enum NearbyMessageType {
  hello(1),
  pairConfirm(2),
  pairReject(3),
  watermarks(4),
  changeset(5),
  basePart(6),
  applied(7),
  error(8),
  bye(9),
  baseOffer(10),
  baseRequest(11),
  helloReveal(12),
  keyCheck(13),
  identity(14),

  // Buddy card swap (issue #3728), protocol version 2.
  cardSummary(15),
  cardRequest(16),
  cardAccept(17),
  cardDecline(18),
  card(19);

  const NearbyMessageType(this.code);

  final int code;

  static NearbyMessageType? fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// One decoded frame: its type and its (possibly encrypted) body.
class NearbyMessage {
  const NearbyMessage(this.type, this.body);

  final NearbyMessageType type;
  final Uint8List body;
}

/// Why a frame could not be decoded. Delivered as a stream error by
/// [FrameDecoder.messages]; the link treats any of them as a protocol
/// violation and ends the session.
sealed class FrameError implements Exception {
  const FrameError();
}

/// A header declared more bytes than the decoder accepts. The decoder
/// never buffers toward the claimed size.
class FrameTooLarge extends FrameError {
  const FrameTooLarge(this.declaredBytes);

  final int declaredBytes;

  @override
  String toString() => 'FrameTooLarge($declaredBytes bytes)';
}

/// A header declared zero bytes, so the frame has no type byte.
class FrameMalformed extends FrameError {
  const FrameMalformed();

  @override
  String toString() => 'FrameMalformed';
}

/// A complete frame carried a type code this build does not know. It is
/// reported as an error rather than skipped, and the session ends: after
/// the handshake every frame is sealed under a per-direction counter, so a
/// frame dropped unopened would make every later one fail to open. A new
/// message type is therefore sent only to a peer whose hello announces a
/// protocol version that knows it.
class UnknownMessageType extends FrameError {
  const UnknownMessageType(this.code);

  final int code;

  @override
  String toString() => 'UnknownMessageType($code)';
}

/// Writes frames: a 4-byte big-endian length of (type byte + body), the type
/// code, then the body.
abstract final class FrameEncoder {
  static Uint8List encode(NearbyMessageType type, Uint8List body) {
    final frame = Uint8List(5 + body.length);
    ByteData.sublistView(frame).setUint32(0, 1 + body.length);
    frame[4] = type.code;
    frame.setRange(5, frame.length, body);
    return frame;
  }
}

/// Reassembles frames from chunks cut at arbitrary boundaries (a Bluetooth
/// write or notification is a chunk).
///
/// A declared length above [maxFrameBytes] or of zero drops everything
/// buffered: once a length is wrong the remaining bytes are no longer
/// framed, so decoding restarts at the next chunk.
class FrameDecoder {
  FrameDecoder({this.maxFrameBytes = 1 << 20});

  final int maxFrameBytes;

  final _controller = StreamController<NearbyMessage>();

  /// Bytes received and not yet decoded live in [_buffer] from [_start] to
  /// [_end]. The buffer grows by doubling and is compacted only when the
  /// unread part is less than half of it, so a frame arriving in many small
  /// chunks costs time linear in its size.
  Uint8List _buffer = Uint8List(1024);
  int _start = 0;
  int _end = 0;

  Stream<NearbyMessage> get messages => _controller.stream;

  void add(Uint8List chunk) {
    if (_controller.isClosed) return;
    _append(chunk);
    _drain();
  }

  Future<void> close() => _controller.close();

  void _append(Uint8List chunk) {
    final unread = _end - _start;
    if (_end + chunk.length > _buffer.length) {
      var capacity = _buffer.length;
      while (capacity < unread + chunk.length) {
        capacity *= 2;
      }
      final next = capacity == _buffer.length ? _buffer : Uint8List(capacity);
      next.setRange(0, unread, _buffer, _start);
      _buffer = next;
      _start = 0;
      _end = unread;
    }
    _buffer.setRange(_end, _end + chunk.length, chunk);
    _end += chunk.length;
  }

  void _reset() {
    _start = 0;
    _end = 0;
  }

  void _drain() {
    while (_end - _start >= 4) {
      final declared = ByteData.sublistView(_buffer, _start).getUint32(0);
      if (declared == 0) {
        _reset();
        _controller.addError(const FrameMalformed());
        return;
      }
      if (declared > maxFrameBytes) {
        _reset();
        _controller.addError(FrameTooLarge(declared));
        return;
      }
      if (_end - _start - 4 < declared) return;
      final code = _buffer[_start + 4];
      final body = Uint8List.fromList(
        Uint8List.sublistView(_buffer, _start + 5, _start + 4 + declared),
      );
      _start += 4 + declared;
      if (_start == _end) _reset();
      final type = NearbyMessageType.fromCode(code);
      if (type == null) {
        _controller.addError(UnknownMessageType(code));
      } else {
        _controller.add(NearbyMessage(type, body));
      }
    }
  }
}
