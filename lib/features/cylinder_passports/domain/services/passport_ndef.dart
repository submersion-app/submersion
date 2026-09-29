import 'dart:convert';
import 'dart:typed_data';

import 'package:ndef_record/ndef_record.dart';

import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/ndef_fit.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';

/// The package an Android Application Record names, so a tap opens
/// Submersion rather than asking which app should (spec 6.4).
const String passportAndroidPackage = 'app.submersion';

/// URI identifier codes from the NFC Forum URI record type definition; the
/// index is the code.
const List<String> _uriPrefixes = [
  '',
  'http://www.',
  'https://www.',
  'http://',
  'https://',
  'tel:',
  'mailto:',
  'ftp://anonymous:anonymous@',
  'ftp://ftp.',
  'ftps://',
  'sftp://',
  'smb://',
  'nfs://',
  'ftp://',
  'dav://',
  'news:',
  'telnet://',
  'imap:',
  'rtsp://',
  'urn:',
  'pop:',
  'sip:',
  'sips:',
  'tftp:',
  'btspp://',
  'btl2cap://',
  'btgoep://',
  'tcpobex://',
  'irdaobex://',
  'file://',
  'urn:epc:id:',
  'urn:epc:tag:',
  'urn:epc:pat:',
  'urn:epc:raw:',
  'urn:epc:',
  'urn:nfc:',
];

/// A well-known URI record for [url], abbreviated by the longest matching
/// prefix code (`https://` is code 4, the size [NdefFit] assumes).
NdefRecord uriRecord(String url) {
  var code = 0;
  for (var i = 1; i < _uriPrefixes.length; i++) {
    final prefix = _uriPrefixes[i];
    if (url.startsWith(prefix) && prefix.length > _uriPrefixes[code].length) {
      code = i;
    }
  }
  final rest = url.substring(_uriPrefixes[code].length);
  return NdefRecord(
    typeNameFormat: TypeNameFormat.wellKnown,
    type: Uint8List.fromList(const [0x55]),
    identifier: Uint8List(0),
    payload: Uint8List.fromList([code, ...utf8.encode(rest)]),
  );
}

/// The URI a well-known URI record carries; null for any other record, an
/// unknown prefix code, or text that is not UTF-8.
String? uriOf(NdefRecord record) {
  if (record.typeNameFormat != TypeNameFormat.wellKnown) return null;
  if (record.type.length != 1 || record.type[0] != 0x55) return null;
  if (record.payload.isEmpty) return null;
  final code = record.payload[0];
  if (code >= _uriPrefixes.length) return null;
  try {
    return _uriPrefixes[code] + utf8.decode(record.payload.sublist(1));
  } on FormatException {
    return null;
  }
}

/// An Android Application Record naming [passportAndroidPackage].
NdefRecord androidApplicationRecord() => NdefRecord(
  typeNameFormat: TypeNameFormat.external,
  type: Uint8List.fromList(utf8.encode('android.com:pkg')),
  identifier: Uint8List(0),
  payload: Uint8List.fromList(utf8.encode(passportAndroidPackage)),
);

/// The first passport tag URI in [message], in record order. The Android
/// record, a fill record and another app's data are skipped (spec 6.4:
/// readers ignore records they do not know).
String? firstPassportUri(NdefMessage message) {
  for (final record in message.records) {
    final uri = uriOf(record);
    if (uri != null && PassportPayloadCodec.extractQuery(uri) != null) {
      return uri;
    }
  }
  return null;
}

/// What a write puts on a tag.
class PassportNdefPlan {
  const PassportNdefPlan({
    required this.message,
    required this.payload,
    required this.droppedKeys,
    required this.includesAndroidRecord,
  });

  final NdefMessage message;

  /// The payload the identity record carries, after any drops.
  final CylinderPassportPayload payload;

  /// Keys the full payload had and the tag could not hold, in drop order.
  final List<String> droppedKeys;

  final bool includesAndroidRecord;
}

/// The message for [payload] on a tag whose NDEF message may take
/// [maxMessageBytes], as the phone reports it: the identity URI record with
/// optional keys dropped in [NdefFit.dropOrder] until it fits, then the
/// Android Application Record when room remains. Null when even the
/// identity (`f`, `p`, `w`) does not fit.
PassportNdefPlan? planPassportMessage(
  CylinderPassportPayload payload, {
  required int maxMessageBytes,
}) {
  var current = payload;
  final dropped = <String>[];
  var i = 0;
  while (true) {
    final identity = uriRecord(PassportPayloadCodec.httpsUrl(current));
    if (identity.byteLength <= maxMessageBytes) {
      final aar = androidApplicationRecord();
      final withAar = identity.byteLength + aar.byteLength <= maxMessageBytes;
      return PassportNdefPlan(
        message: NdefMessage(records: [identity, if (withAar) aar]),
        payload: current,
        droppedKeys: List.unmodifiable(dropped),
        includesAndroidRecord: withAar,
      );
    }
    if (i >= NdefFit.dropOrder.length) return null;
    final key = NdefFit.dropOrder[i++];
    final next = NdefFit.drop(current, key);
    if (next != current) dropped.add(key);
    current = next;
  }
}
