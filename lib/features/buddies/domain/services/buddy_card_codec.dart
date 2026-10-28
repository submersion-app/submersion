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

  /// The longest name a received card keeps.
  static const int maxNameLength = 200;

  static String _capped(String text, int max) =>
      text.length <= max ? text : text.substring(0, max);

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
    'lastCert',
  ];

  /// The most dives a card may claim; more is not a real logbook.
  static const int maxDives = 100000;

  static bool isCardLink(String text) => text.trim().startsWith(linkPrefix);

  static bool isCardFileName(String fileName) =>
      fileName.toLowerCase().endsWith('.$fileExtension');

  static final _windowsReserved = RegExp(
    r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$',
    caseSensitive: false,
  );

  /// A file name for [name]'s card that every platform accepts: path and
  /// reserved characters become `_`, and the name is kept short.
  static String fileNameFor(String name) {
    var base = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_');
    if (base.length > 100) base = base.substring(0, 100);
    if (base.isEmpty) base = 'buddy';
    // Windows reserves these device names, with any extension.
    if (_windowsReserved.hasMatch(base)) base = '_$base';
    return '$base.$fileExtension';
  }

  /// How every full card this app writes begins: its version key first.
  static final List<int> _fullCardStart = utf8.encode('{"v":');

  /// Whether [bytes] read as a full card, for a file whose name was lost on
  /// the way (an Android content URI often carries none). A JSON object
  /// that starts as this app writes a card, with the card's version, id and
  /// name keys; no dive log format has that shape. The start is checked
  /// first, so other JSON (a large dive log export) is never parsed here.
  static bool looksLikeFullCard(Uint8List bytes) {
    if (bytes.length < _fullCardStart.length || bytes.length > maxFullBytes) {
      return false;
    }
    for (var i = 0; i < _fullCardStart.length; i++) {
      if (bytes[i] != _fullCardStart[i]) return false;
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
  /// photo always and then fields in [dropOrder] until it fits (the last
  /// certification goes only after the email). Throws [BuddyCardTooLarge]
  /// when even name, id and phone do not fit.
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
        'lastCert' => current.copyWith(certs: const []),
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
      name: _capped(name.trim(), maxNameLength),
      phone: _string(json['p']),
      email: _string(json['e']),
      social: _string(json['s']),
      certs: _certs(json['c']),
      dives: switch (json['d']) {
        final int d when d >= 0 && d <= maxDives => d,
        _ => null,
      },
      since: _year(json['f']),
      last: _parseDate(json['l']),
      photo: _photo(json['ph']),
    );
    return BuddyCardDecoded(
      card,
      newerFormat: version > currentVersion,
      trimmed: json['t'] == 1,
    );
  }

  /// A diving-since year from 1900 to next year (a clock a day ahead of
  /// the sender's); anything else is not a year a diver started.
  static int? _year(Object? value) {
    if (value is! int) return null;
    return value >= 1900 && value <= DateTime.now().year + 1 ? value : null;
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
    final date = DateTime(year, month, day);
    // DateTime rolls 2026-02-31 over to 3 March; a date that does not
    // come back as written is not a date.
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }
}
