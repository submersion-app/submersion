import 'dart:typed_data';

import 'package:ndef_record/ndef_record.dart';

/// [message] as NFC Forum NDEF bytes, for the Android phone that presents a
/// buddy card as a tag (issue #3728). The pinned `ndef_record` reads and
/// writes records through the NFC plugins but cannot serialise a message
/// itself.
Uint8List encodeNdef(NdefMessage message) {
  final out = BytesBuilder();
  final records = message.records;
  for (var i = 0; i < records.length; i++) {
    final r = records[i];
    final short = r.payload.length < 256;
    final hasId = r.identifier.isNotEmpty;
    out.addByte(
      (i == 0 ? 0x80 : 0) |
          (i == records.length - 1 ? 0x40 : 0) |
          (short ? 0x10 : 0) |
          (hasId ? 0x08 : 0) |
          r.typeNameFormat.index,
    );
    out.addByte(r.type.length);
    if (short) {
      out.addByte(r.payload.length);
    } else {
      final length = ByteData(4)..setUint32(0, r.payload.length);
      out.add(length.buffer.asUint8List());
    }
    if (hasId) out.addByte(r.identifier.length);
    out
      ..add(r.type)
      ..add(r.identifier)
      ..add(r.payload);
  }
  return out.toBytes();
}

/// The message in NDEF [bytes]; throws [FormatException] when they are cut
/// short or malformed. Chunked records are not supported.
NdefMessage decodeNdef(Uint8List bytes) {
  final records = <NdefRecord>[];
  var at = 0;
  int take(int n) {
    if (at + n > bytes.length) throw const FormatException('NDEF too short');
    final start = at;
    at += n;
    return start;
  }

  while (at < bytes.length) {
    final header = bytes[take(1)];
    if (header & 0x20 != 0) {
      throw const FormatException('Chunked NDEF records are not supported');
    }
    final short = header & 0x10 != 0;
    final hasId = header & 0x08 != 0;
    final tnf = header & 0x07;
    if (tnf >= TypeNameFormat.values.length) {
      throw const FormatException('Unknown NDEF type name format');
    }
    final typeLength = bytes[take(1)];
    final payloadLength = short
        ? bytes[take(1)]
        : ByteData.sublistView(bytes, take(4), at).getUint32(0);
    final idLength = hasId ? bytes[take(1)] : 0;
    final type = Uint8List.sublistView(bytes, take(typeLength), at);
    final id = Uint8List.sublistView(bytes, take(idLength), at);
    final payload = Uint8List.sublistView(bytes, take(payloadLength), at);
    records.add(
      NdefRecord(
        typeNameFormat: TypeNameFormat.values[tnf],
        type: Uint8List.fromList(type),
        identifier: Uint8List.fromList(id),
        payload: Uint8List.fromList(payload),
      ),
    );
    if (header & 0x40 != 0) break;
  }
  if (records.isEmpty) throw const FormatException('Empty NDEF message');
  return NdefMessage(records: records);
}
