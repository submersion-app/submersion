import 'dart:convert';
import 'dart:typed_data';

import 'package:ndef_record/ndef_record.dart';

import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/ndef_fit.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/gear_passports/domain/services/tag_link_codec.dart';

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

/// What a write puts on a tag, whatever kind of tag it is.
abstract interface class TagNdefPlan {
  NdefMessage get message;

  /// The link the identity record carries, after any drops.
  String get url;

  /// Keys the full payload had and the tag could not hold, in drop order.
  List<String> get droppedKeys;

  bool get includesAndroidRecord;

  /// Whether a cylinder's newest fill rode along (never for gear).
  bool get includesFill;
}

/// The fitting loop every tag kind shares (spec 6.4): the identity URI
/// record of [url] with keys dropped in [dropOrder] until it fits
/// [maxMessageBytes], then the Android Application Record when room
/// remains. Null when even the payload with every optional key dropped
/// does not fit.
({NdefMessage message, T payload, List<String> dropped, bool withAar})?
fitUriMessage<T>(
  T payload, {
  required String Function(T payload) url,
  required List<String> dropOrder,
  required T Function(T payload, String key) drop,
  required int maxMessageBytes,
}) {
  var current = payload;
  final dropped = <String>[];
  var i = 0;
  while (true) {
    final identity = uriRecord(url(current));
    if (identity.byteLength <= maxMessageBytes) {
      final aar = androidApplicationRecord();
      final withAar = identity.byteLength + aar.byteLength <= maxMessageBytes;
      return (
        message: NdefMessage(records: [identity, if (withAar) aar]),
        payload: current,
        dropped: List.unmodifiable(dropped),
        withAar: withAar,
      );
    }
    if (i >= dropOrder.length) return null;
    final key = dropOrder[i++];
    final next = drop(current, key);
    if (next != current) dropped.add(key);
    current = next;
  }
}

/// The first tag URI in [message], cylinder or gear, in record order. The Android
/// record, a fill record and another app's data are skipped (spec 6.4:
/// readers ignore records they do not know).
String? firstPassportUri(NdefMessage message) {
  for (final record in message.records) {
    final uri = uriOf(record);
    if (uri != null && TagLinkCodec.isTagLink(uri)) {
      return uri;
    }
  }
  return null;
}

/// What a cylinder passport write puts on a tag.
class PassportNdefPlan implements TagNdefPlan {
  const PassportNdefPlan({
    required this.message,
    required this.payload,
    required this.droppedKeys,
    required this.includesAndroidRecord,
  });

  @override
  final NdefMessage message;

  /// The payload the identity record carries, after any drops.
  final CylinderPassportPayload payload;

  @override
  final List<String> droppedKeys;

  @override
  final bool includesAndroidRecord;

  @override
  String get url => PassportPayloadCodec.httpsUrl(payload);

  @override
  bool get includesFill => payload.fill != null;
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
  final fitted = fitUriMessage<CylinderPassportPayload>(
    payload,
    url: PassportPayloadCodec.httpsUrl,
    dropOrder: NdefFit.dropOrder,
    drop: NdefFit.drop,
    maxMessageBytes: maxMessageBytes,
  );
  if (fitted == null) return null;
  return PassportNdefPlan(
    message: fitted.message,
    payload: fitted.payload,
    droppedKeys: fitted.dropped,
    includesAndroidRecord: fitted.withAar,
  );
}
