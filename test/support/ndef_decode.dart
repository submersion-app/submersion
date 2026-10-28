import 'dart:typed_data';

import 'package:ndef_record/ndef_record.dart';

/// The message in NDEF [bytes], for checking what `encodeNdef` wrote
/// (issue #3728); throws [FormatException] when they are cut
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
