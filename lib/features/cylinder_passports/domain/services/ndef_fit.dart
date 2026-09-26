import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';

/// Fits a tag payload into an NFC tag's user memory (spec section 6.4).
///
/// Size model for a Type 2 tag (NTAG21x): the NDEF message sits in a TLV
/// block, 2 bytes of header under 255 bytes of message and 4 above, plus a
/// 1-byte terminator. One short URI record costs 4 bytes of header when its
/// payload is at most 255 bytes and 7 above, plus the payload: one prefix
/// byte standing for `https://` and the rest of the URL as UTF-8.
abstract final class NdefFit {
  static const int ntag213Bytes = 144;
  static const int ntag215Bytes = 504;
  static const int ntag216Bytes = 888;

  /// Optional keys, dropped first to last until the record fits. `f`, `p`
  /// and `w` are never dropped.
  static const List<String> dropOrder = [
    'n',
    'sn',
    'vi',
    'h',
    'oc',
    'vt',
    'm',
    'wp',
    'v',
  ];

  static const String _httpsPrefix = 'https://';

  /// Bytes an NDEF message holding one URI record of [url] takes on the tag.
  static int uriRecordMessageBytes(String url) {
    final body = url.startsWith(_httpsPrefix)
        ? url.substring(_httpsPrefix.length)
        : url;
    final payload = 1 + body.codeUnits.length;
    final record = (payload <= 255 ? 4 : 7) + payload;
    final tlv = record < 255 ? 2 : 4;
    return tlv + record + 1;
  }

  static CylinderPassportPayload drop(CylinderPassportPayload p, String key) =>
      switch (key) {
        'n' => p.copyWith(clearName: true),
        'sn' => p.copyWith(clearSerial: true),
        'vi' => p.copyWith(clearLastVip: true),
        'h' => p.copyWith(clearLastHydro: true),
        'oc' => p.copyWith(o2Clean: false),
        'vt' => p.copyWith(clearValve: true),
        'm' => p.copyWith(clearMaterial: true),
        'wp' => p.copyWith(clearWorkingPressureBar: true),
        'v' => p.copyWith(clearVolumeL: true),
        _ => p,
      };

  /// Longest tag URL a printed label carries: a version 9 QR at error
  /// correction M, about half a millimetre per module on a 26 mm label.
  static const int labelMaxUrlLength = 160;

  /// [p] with optional keys dropped, in [dropOrder], until its https URL is
  /// at most [labelMaxUrlLength] characters. The identity alone is far
  /// shorter, so this always returns a payload. A long name in a
  /// multi-byte script, which percent-encodes to several characters per
  /// glyph, is what usually goes first; the label prints it as text anyway.
  static CylinderPassportPayload fitForLabel(CylinderPassportPayload p) {
    var current = p;
    for (final key in dropOrder) {
      if (PassportPayloadCodec.httpsUrl(current).length <= labelMaxUrlLength) {
        return current;
      }
      current = drop(current, key);
    }
    return current;
  }

  /// The largest payload, in drop order, whose https URL fits
  /// [capacityBytes]; null when the identity alone does not.
  static CylinderPassportPayload? fit(
    CylinderPassportPayload p,
    int capacityBytes,
  ) {
    var current = p;
    var i = 0;
    while (true) {
      final bytes = uriRecordMessageBytes(
        PassportPayloadCodec.httpsUrl(current),
      );
      if (bytes <= capacityBytes) return current;
      if (i >= dropOrder.length) return null;
      current = drop(current, dropOrder[i]);
      i++;
    }
  }
}
