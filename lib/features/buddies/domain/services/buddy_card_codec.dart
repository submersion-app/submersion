import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';

/// Why a scanned, tapped or opened payload is not a usable buddy card.
enum BuddyCardRejectReason { notACard, malformed, missingName, missingId }

sealed class BuddyCardDecodeResult {
  const BuddyCardDecodeResult();
}

class BuddyCardDecoded extends BuddyCardDecodeResult {
  final BuddyCard card;

  /// The card's format version is newer than this app knows; every known
  /// key was read.
  final bool newerFormat;

  /// The sender's app left details out to fit a QR code or sticker.
  final bool trimmed;

  const BuddyCardDecoded(
    this.card, {
    this.newerFormat = false,
    this.trimmed = false,
  });
}

class BuddyCardRejected extends BuddyCardDecodeResult {
  final BuddyCardRejectReason reason;
  const BuddyCardRejected(this.reason);
}

/// A card that cannot fit [maxBytes] even with every optional field gone.
class BuddyCardTooLarge implements Exception {
  final int maxBytes;
  const BuddyCardTooLarge(this.maxBytes);

  @override
  String toString() => 'BuddyCardTooLarge: does not fit $maxBytes bytes';
}

/// Reads and writes buddy cards (issue #3728).
///
/// Two encodings of one compact JSON shape with short keys:
/// - **full**: UTF-8 JSON with the photo, for nearby swaps and card files;
/// - **link**: `https://submersion.app/b#<base64url JSON>` without the
///   photo, for QR codes and NFC. The payload is in the fragment, which a
///   browser never sends to the server: a card describes a person.
abstract final class BuddyCardCodec {
  static const int currentVersion = 1;
  static const String linkPrefix = 'https://submersion.app/b#';
  static const String fileExtension = 'subbuddy';
  static const int maxPhotoBytes = 12 * 1024;

  /// The largest full card read; anything bigger is not a card.
  static const int maxFullBytes = 4 * 1024 * 1024;

  /// What [encodeLink] drops, in order, until the link fits.
  static const List<String> dropOrder = [
    'social',
    'last',
    'certNumbers',
    'lowerCerts',
    'since',
    'email',
  ];

  static bool isCardLink(String text) => text.trim().startsWith(linkPrefix);

  static bool isCardFileName(String fileName) =>
      fileName.toLowerCase().endsWith('.$fileExtension');

  /// Whether [bytes] read as a full card, for a file whose name was lost on
  /// the way (an Android content URI often carries none). A small JSON
  /// object with the card's version, id and name keys; no dive log format
  /// has that shape.
  static bool looksLikeFullCard(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxFullBytes || bytes.first != 0x7B) {
      return false;
    }
    try {
      final json = jsonDecode(utf8.decode(bytes));
      return json is Map<String, Object?> &&
          json['v'] is int &&
          json['i'] is String &&
          json['n'] is String;
    } on FormatException {
      return false;
    }
  }

  static Uint8List encodeFull(BuddyCard card) =>
      Uint8List.fromList(utf8.encode(jsonEncode(_toJson(card))));

  static BuddyCardDecodeResult decodeFull(Uint8List bytes) {
    if (bytes.length > maxFullBytes) {
      return const BuddyCardRejected(BuddyCardRejectReason.malformed);
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return const BuddyCardRejected(BuddyCardRejectReason.malformed);
    }
    return _fromJson(json);
  }

  /// [card] as a link no longer than [maxBytes] UTF-8 bytes, dropping the
  /// photo always and then fields in [dropOrder] until it fits. Throws
  /// [BuddyCardTooLarge] when even name, id and phone do not fit.
  static String encodeLink(BuddyCard card, {required int maxBytes}) {
    var current = card.copyWith(clearPhoto: true);
    var trimmed = false;
    String linkOf(BuddyCard c) => linkPrefix + _base64(_toJson(c, trimmed));
    bool fits(BuddyCard c) => utf8.encode(linkOf(c)).length <= maxBytes;

    for (final step in dropOrder) {
      if (fits(current)) return linkOf(current);
      trimmed = true;
      current = switch (step) {
        'social' => current.copyWith(clearSocial: true),
        'last' => current.copyWith(clearLast: true),
        'certNumbers' => current.copyWith(
          certs: [for (final c in current.certs) c.withoutCardDetails()],
        ),
        'lowerCerts' => _dropLowerCerts(current, fits),
        'since' => current.copyWith(clearSince: true),
        'email' => current.copyWith(clearEmail: true),
        _ => current,
      };
    }
    if (fits(current)) return linkOf(current);
    throw BuddyCardTooLarge(maxBytes);
  }

  /// Removes the lowest certification one at a time, keeping at least one,
  /// until [fits] or one remains.
  static BuddyCard _dropLowerCerts(
    BuddyCard card,
    bool Function(BuddyCard) fits,
  ) {
    var certs = card.certs;
    var current = card;
    while (certs.length > 1 && !fits(current)) {
      certs = certs.sublist(0, certs.length - 1);
      current = current.copyWith(certs: certs);
    }
    return current;
  }

  static BuddyCardDecodeResult decodeLink(String text) {
    final trimmedText = text.trim();
    if (!isCardLink(trimmedText)) {
      return const BuddyCardRejected(BuddyCardRejectReason.notACard);
    }
    final payload = trimmedText.substring(linkPrefix.length);
    final Object? json;
    try {
      final padded = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
      json = jsonDecode(utf8.decode(base64Url.decode(padded)));
    } on FormatException {
      return const BuddyCardRejected(BuddyCardRejectReason.malformed);
    }
    return _fromJson(json);
  }

  static String _base64(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

  static Map<String, Object?> _toJson(BuddyCard c, [bool trimmed = false]) => {
    'v': currentVersion,
    'i': c.id,
    'n': c.name,
    'p': ?c.phone,
    'e': ?c.email,
    's': ?c.social,
    if (c.certs.isNotEmpty)
      'c': [
        for (final cert in c.certs)
          _withoutTrailingNulls([
            cert.agency,
            cert.name,
            cert.level,
            cert.cardNumber,
            if (cert.issueDate != null) _date(cert.issueDate!) else null,
          ]),
      ],
    'd': ?c.dives,
    'f': ?c.since,
    if (c.last != null) 'l': _date(c.last!),
    if (c.photo != null) 'ph': base64.encode(c.photo!),
    if (trimmed) 't': 1,
  };

  /// [values] without the empty fields at its end: every byte counts on a
  /// QR code or sticker, and the reader takes a shorter array as missing.
  static List<Object?> _withoutTrailingNulls(List<Object?> values) {
    var end = values.length;
    while (end > 0 && values[end - 1] == null) {
      end--;
    }
    return values.sublist(0, end);
  }

  static BuddyCardDecodeResult _fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return const BuddyCardRejected(BuddyCardRejectReason.malformed);
    }
    final id = json['i'];
    final name = json['n'];
    if (id != null && id is! String || name != null && name is! String) {
      return const BuddyCardRejected(BuddyCardRejectReason.malformed);
    }
    if (id == null || (id as String).trim().isEmpty || id.length > 128) {
      return const BuddyCardRejected(BuddyCardRejectReason.missingId);
    }
    if (name == null || (name as String).trim().isEmpty) {
      return const BuddyCardRejected(BuddyCardRejectReason.missingName);
    }
    final version = json['v'] is int ? json['v'] as int : currentVersion;
    final card = BuddyCard(
      version: version,
      id: id,
      name: name.trim(),
      phone: _string(json['p']),
      email: _string(json['e']),
      social: _string(json['s']),
      certs: _certs(json['c']),
      dives: json['d'] is int && (json['d'] as int) >= 0
          ? json['d'] as int
          : null,
      since: json['f'] is int && (json['f'] as int) >= 1900
          ? json['f'] as int
          : null,
      last: _parseDate(json['l']),
      photo: _photo(json['ph']),
    );
    return BuddyCardDecoded(
      card,
      newerFormat: version > currentVersion,
      trimmed: json['t'] == 1,
    );
  }

  static String? _string(Object? value) {
    if (value is! String) return null;
    final t = value.trim();
    return t.isEmpty || t.length > 500 ? null : t;
  }

  static List<BuddyCardCert> _certs(Object? value) {
    if (value is! List) return const [];
    final out = <BuddyCardCert>[];
    for (final entry in value.take(50)) {
      if (entry is! List || entry.length < 2) continue;
      final agency = _string(entry[0]);
      final name = _string(entry[1]);
      if (agency == null || name == null) continue;
      out.add(
        BuddyCardCert(
          agency: agency,
          name: name,
          level: entry.length > 2 ? _string(entry[2]) : null,
          cardNumber: entry.length > 3 ? _string(entry[3]) : null,
          issueDate: entry.length > 4 ? _parseDate(entry[4]) : null,
        ),
      );
    }
    return out;
  }

  static Uint8List? _photo(Object? value) {
    if (value is! String) return null;
    // Base64 is 4 characters per 3 bytes: refuse before decoding a giant.
    if (value.length > (maxPhotoBytes * 4 / 3).ceil() + 4) return null;
    try {
      final bytes = base64.decode(value);
      return bytes.length > maxPhotoBytes ? null : bytes;
    } on FormatException {
      return null;
    }
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(Object? value) {
    if (value is! String) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }
}
