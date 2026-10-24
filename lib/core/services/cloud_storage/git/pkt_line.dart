import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';

/// One unit of Git's pkt-line framing.
sealed class Pkt {
  const Pkt();
}

/// A data packet. [bytes] is the payload without the 4-byte length prefix.
final class PktData extends Pkt {
  const PktData(this.bytes);

  final Uint8List bytes;

  /// The payload as UTF-8 with one trailing newline removed.
  String get text {
    final s = utf8.decode(bytes, allowMalformed: true);
    return s.endsWith('\n') ? s.substring(0, s.length - 1) : s;
  }
}

/// `0000`: end of a message or section.
final class PktFlush extends Pkt {
  const PktFlush();
}

/// `0001`: separates sections in protocol v2.
final class PktDelim extends Pkt {
  const PktDelim();
}

/// `0002`: end of a stateless response in protocol v2.
final class PktResponseEnd extends Pkt {
  const PktResponseEnd();
}

/// The largest packet Git allows, length prefix included.
const int kPktMaxLength = 65520;

final Uint8List pktFlushBytes = Uint8List.fromList(ascii.encode('0000'));
final Uint8List pktDelimBytes = Uint8List.fromList(ascii.encode('0001'));

/// Frames [payload] as one data packet.
Uint8List pktData(List<int> payload) {
  final length = payload.length + 4;
  if (length > kPktMaxLength) {
    throw ArgumentError('pkt-line payload too long: ${payload.length}');
  }
  return Uint8List.fromList([
    ...ascii.encode(length.toRadixString(16).padLeft(4, '0')),
    ...payload,
  ]);
}

/// Frames [line] plus a newline as one data packet.
Uint8List pktText(String line) => pktData(utf8.encode('$line\n'));

GitException _malformed(String what) => GitException(
  'The server sent a malformed reply ($what).',
  code: GitErrorCode.unexpected,
);

/// Reads pkt-line packets from a byte stream delivered in any chunking.
final class PktLineReader {
  PktLineReader(Stream<List<int>> source) : _source = StreamIterator(source);

  final StreamIterator<List<int>> _source;
  Uint8List _buffer = Uint8List(0);
  int _offset = 0;
  bool _done = false;

  int get _available => _buffer.length - _offset;

  /// Buffers at least [n] bytes. False when the stream ends first.
  Future<bool> _fill(int n) async {
    while (_available < n) {
      if (_done || !await _source.moveNext()) {
        _done = true;
        return false;
      }
      _buffer =
          (BytesBuilder(copy: false)
                ..add(Uint8List.sublistView(_buffer, _offset))
                ..add(_source.current))
              .takeBytes();
      _offset = 0;
    }
    return true;
  }

  Uint8List _take(int n) {
    final out = Uint8List.sublistView(_buffer, _offset, _offset + n);
    _offset += n;
    return Uint8List.fromList(out);
  }

  /// The next packet, or null at a clean end of stream.
  Future<Pkt?> next() async {
    if (!await _fill(4)) {
      if (_available == 0) return null;
      throw _malformed('truncated length');
    }
    final length = int.tryParse(ascii.decode(_take(4)), radix: 16);
    if (length == null) throw _malformed('length is not hex');
    switch (length) {
      case 0:
        return const PktFlush();
      case 1:
        return const PktDelim();
      case 2:
        return const PktResponseEnd();
    }
    if (length < 4 || length > kPktMaxLength) {
      throw _malformed('length $length');
    }
    if (!await _fill(length - 4)) throw _malformed('truncated packet');
    return PktData(_take(length - 4));
  }

  /// Everything after the packets read so far, to the end of the stream.
  Future<Uint8List> readRemaining() async {
    final out = BytesBuilder(copy: false)..add(_take(_available));
    while (!_done && await _source.moveNext()) {
      out.add(_source.current);
    }
    _done = true;
    return out.takeBytes();
  }

  /// Stops reading, releasing the source (an HTTP body still open).
  Future<void> cancel() async {
    _done = true;
    await _source.cancel();
  }
}

/// Splits a side-band-64k response: band 1 is data (yielded in order), band
/// 2 is progress text, band 3 is a fatal error from the server. Stops at the
/// first flush or at end of stream.
Stream<Uint8List> demuxSideBand(
  PktLineReader reader, {
  void Function(String progress)? onProgress,
}) async* {
  while (true) {
    final pkt = await reader.next();
    if (pkt == null || pkt is PktFlush) return;
    if (pkt is! PktData || pkt.bytes.isEmpty) continue;
    final band = pkt.bytes[0];
    final payload = Uint8List.sublistView(pkt.bytes, 1);
    switch (band) {
      case 1:
        yield payload;
      case 2:
        onProgress?.call(utf8.decode(payload, allowMalformed: true).trim());
      case 3:
        final reason = utf8.decode(payload, allowMalformed: true).trim();
        throw GitException(
          'The Git server reported an error.',
          code: GitErrorCode.server,
          serverReason: reason,
        );
      default:
        throw _malformed('side-band $band');
    }
  }
}
