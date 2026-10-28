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
