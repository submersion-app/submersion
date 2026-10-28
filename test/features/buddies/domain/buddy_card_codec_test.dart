import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';
import 'package:submersion/features/buddies/domain/services/buddy_card_codec.dart';

BuddyCard _sam({
  String name = 'Sam Rivera',
  List<BuddyCardCert>? certs,
  Uint8List? photo,
  String? social = '@samdives',
}) => BuddyCard(
  id: 'diver-sam',
  name: name,
  phone: '+1 555 0134',
  email: 'sam@example.com',
  social: social,
  certs:
      certs ??
      [
        BuddyCardCert(
          agency: 'PADI',
          name: 'Rescue Diver',
          level: 'Rescue Diver',
          cardNumber: '12345',
          issueDate: DateTime(2020, 5, 1),
        ),
        const BuddyCardCert(agency: 'PADI', name: 'Enriched Air Diver'),
      ],
  dives: 118,
  since: 2016,
  last: DateTime(2026, 10, 3),
  photo: photo,
);

BuddyCard _decoded(BuddyCardDecodeResult r) => (r as BuddyCardDecoded).card;

void main() {
  test('full round trip keeps every field including photo', () {
    final card = _sam(photo: Uint8List.fromList(List.generate(200, (i) => i)));
    final out = _decoded(
      BuddyCardCodec.decodeFull(BuddyCardCodec.encodeFull(card)),
    );
    expect(out, card);
  });

  test('link round trip drops photo and keeps the rest', () {
    final card = _sam(photo: Uint8List.fromList([1, 2, 3]));
    final link = BuddyCardCodec.encodeLink(card, maxBytes: 2000);
    final result = BuddyCardCodec.decodeLink(link) as BuddyCardDecoded;
    expect(result.card.photo, isNull);
    expect(result.card, card.copyWith(clearPhoto: true));
    expect(result.trimmed, isFalse);
  });

  test('link payload is in the fragment', () {
    final link = BuddyCardCodec.encodeLink(_sam(), maxBytes: 2000);
    expect(link.startsWith('https://submersion.app/b#'), isTrue);
    expect(Uri.parse(link).query, isEmpty);
    expect(Uri.parse(link).fragment, isNotEmpty);
  });

  test('link fits 504 bytes for 12 certs and long emoji and Arabic names', () {
    final card = _sam(
      name: 'سامي ريفيرا الغواص من البحر الأحمر \u{1F420}\u{1F93F}\u{1F30A}',
      social: '@a_very_long_social_handle_for_testing',
      certs: [
        for (var i = 0; i < 12; i++)
          BuddyCardCert(
            agency: 'SSI',
            name: 'Specialty course number $i \u{1F419}',
            level: 'Level $i',
            cardNumber: 'SSI-000$i-XYZ',
            issueDate: DateTime(2015 + i),
          ),
      ],
    );
    final link = BuddyCardCodec.encodeLink(card, maxBytes: 504);
    expect(utf8.encode(link).length, lessThanOrEqualTo(504));
    final result = BuddyCardCodec.decodeLink(link) as BuddyCardDecoded;
    expect(result.trimmed, isTrue);
    expect(result.card.name, card.name);
    expect(result.card.certs, isNotEmpty);
  });

  test('fitting drops social before last dive', () {
    final card = _sam();
    final full = BuddyCardCodec.encodeLink(card, maxBytes: 2000);
    final withoutSocial = BuddyCardCodec.encodeLink(
      card.copyWith(clearSocial: true),
      maxBytes: 2000,
    );
    // Room for the trimmed marker the fitted link carries.
    final link = BuddyCardCodec.encodeLink(
      card,
      maxBytes: utf8.encode(withoutSocial).length + 12,
    );
    expect(utf8.encode(full).length, greaterThan(utf8.encode(link).length));
    final out = (BuddyCardCodec.decodeLink(link) as BuddyCardDecoded).card;
    expect(out.social, isNull);
    expect(out.last, card.last);
  });

  test('certifications carry no trailing empty fields', () {
    final link = BuddyCardCodec.encodeLink(
      const BuddyCard(
        id: 'x',
        name: 'Sam',
        certs: [BuddyCardCert(agency: 'PADI', name: 'Rescue Diver')],
      ),
      maxBytes: 2000,
    );
    final payload = link.substring(BuddyCardCodec.linkPrefix.length);
    final json = utf8.decode(
      base64Url.decode(payload.padRight((payload.length + 3) ~/ 4 * 4, '=')),
    );
    expect(json, contains('["PADI","Rescue Diver"]'));
    expect(json, isNot(contains('null')));
  });

  test('a card too large even after every drop throws', () {
    expect(
      () => BuddyCardCodec.encodeLink(_sam(name: 'x' * 600), maxBytes: 200),
      throwsA(isA<BuddyCardTooLarge>()),
    );
  });

  group('newer and broken input', () {
    String linkOf(Object json) =>
        BuddyCardCodec.linkPrefix +
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

    test('newer version reads known keys', () {
      final result =
          BuddyCardCodec.decodeLink(
                linkOf({'v': 99, 'i': 'x', 'n': 'Sam', 'future': true}),
              )
              as BuddyCardDecoded;
      expect(result.newerFormat, isTrue);
      expect(result.card.name, 'Sam');
    });

    BuddyCardRejectReason reasonOf(String text) =>
        (BuddyCardCodec.decodeLink(text) as BuddyCardRejected).reason;

    test('rejects malformed base64', () {
      expect(
        reasonOf('${BuddyCardCodec.linkPrefix}%%%not-base64%%%'),
        BuddyCardRejectReason.malformed,
      );
    });
    test('rejects non-map JSON', () {
      expect(reasonOf(linkOf([1, 2])), BuddyCardRejectReason.malformed);
    });
    test('rejects a wrong type for a required field', () {
      expect(
        reasonOf(linkOf({'v': 1, 'i': 'x', 'n': 42})),
        BuddyCardRejectReason.malformed,
      );
    });
    test('rejects a missing name', () {
      expect(
        reasonOf(linkOf({'v': 1, 'i': 'x', 'n': '  '})),
        BuddyCardRejectReason.missingName,
      );
    });
    test('rejects a missing id', () {
      expect(
        reasonOf(linkOf({'v': 1, 'n': 'Sam'})),
        BuddyCardRejectReason.missingId,
      );
    });
    test('ignores a wrong type for an optional field', () {
      final card = _decoded(
        BuddyCardCodec.decodeLink(
          linkOf({'v': 1, 'i': 'x', 'n': 'Sam', 'p': 5, 'd': 'many'}),
        ),
      );
      expect(card.phone, isNull);
      expect(card.dives, isNull);
    });
    test('a passport link is not a card', () {
      expect(
        reasonOf('https://submersion.app/c?abc'),
        BuddyCardRejectReason.notACard,
      );
    });
  });

  test('photo over maxPhotoBytes is discarded, card still decodes', () {
    final big = Uint8List(BuddyCardCodec.maxPhotoBytes + 1);
    final out = _decoded(
      BuddyCardCodec.decodeFull(BuddyCardCodec.encodeFull(_sam(photo: big))),
    );
    expect(out.photo, isNull);
    expect(out.name, 'Sam Rivera');
  });

  test('a 2 MB photo in a file is discarded, card still decodes', () {
    final huge = Uint8List(2 * 1024 * 1024);
    final out = _decoded(
      BuddyCardCodec.decodeFull(BuddyCardCodec.encodeFull(_sam(photo: huge))),
    );
    expect(out.photo, isNull);
  });

  test('isCardLink accepts the b fragment link and rejects others', () {
    expect(BuddyCardCodec.isCardLink('https://submersion.app/b#abc'), isTrue);
    expect(BuddyCardCodec.isCardLink('https://submersion.app/c?abc'), isFalse);
    expect(BuddyCardCodec.isCardLink('https://submersion.app/g?abc'), isFalse);
    expect(BuddyCardCodec.isCardLink('https://example.com/b#abc'), isFalse);
  });

  test('isCardFileName matches .subbuddy case-insensitively', () {
    expect(BuddyCardCodec.isCardFileName('Sam Rivera.subbuddy'), isTrue);
    expect(BuddyCardCodec.isCardFileName('SAM.SUBBUDDY'), isTrue);
    expect(BuddyCardCodec.isCardFileName('dives.uddf'), isFalse);
  });

  test('fileNameFor makes a safe file name from a diver name', () {
    expect(BuddyCardCodec.fileNameFor('Sam Rivera'), 'Sam Rivera.subbuddy');
    expect(
      BuddyCardCodec.fileNameFor('a/b\\c:d*e?"f<g>h|i'),
      'a_b_c_d_e__f_g_h_i.subbuddy',
    );
    expect(BuddyCardCodec.fileNameFor('  '), 'buddy.subbuddy');
    expect(
      BuddyCardCodec.fileNameFor('x' * 300).length,
      lessThanOrEqualTo(110),
    );
  });

  test('a name over 200 characters is cut to 200', () {
    final out = BuddyCardCodec.decodeFull(
      BuddyCardCodec.encodeFull(BuddyCard(id: 'x', name: 'n' * 5000)),
    );
    expect((out as BuddyCardDecoded).card.name.length, 200);
  });

  test('an impossible date is dropped, not rolled over', () {
    String linkOf(Object json) =>
        BuddyCardCodec.linkPrefix +
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    final card = _decoded(
      BuddyCardCodec.decodeLink(
        linkOf({'v': 1, 'i': 'x', 'n': 'Sam', 'l': '2026-02-31'}),
      ),
    );
    expect(card.last, isNull);
  });

  test('a long last certification goes when only it stands in the way', () {
    final card = BuddyCard(
      id: 'diver-sam',
      name: 'Sam Rivera',
      phone: '+1 555 0134',
      certs: [BuddyCardCert(agency: 'PADI', name: 'x' * 200)],
    );
    final bare = BuddyCardCodec.encodeLink(
      card.copyWith(certs: const []),
      maxBytes: 1000,
    );
    final link = BuddyCardCodec.encodeLink(card, maxBytes: bare.length + 8);
    final decoded = BuddyCardCodec.decodeLink(link) as BuddyCardDecoded;
    expect(decoded.card.certs, isEmpty);
    expect(decoded.card.phone, '+1 555 0134');
    expect(decoded.trimmed, isTrue);
  });

  test('a diving-since year in the future and an absurd dive count are '
      'dropped', () {
    final json = jsonEncode({
      'v': 1,
      'i': 'x',
      'n': 'Xan',
      'f': DateTime.now().year + 2,
      'd': 1000000,
    });
    final decoded =
        BuddyCardCodec.decodeFull(Uint8List.fromList(utf8.encode(json)))
            as BuddyCardDecoded;
    expect(decoded.card.since, isNull);
    expect(decoded.card.dives, isNull);
  });

  test('a file is sniffed as a card only when it starts as this app writes '
      'one, so other JSON is never parsed for it', () {
    Uint8List bytesOf(String text) => Uint8List.fromList(utf8.encode(text));
    expect(
      BuddyCardCodec.looksLikeFullCard(
        BuddyCardCodec.encodeFull(const BuddyCard(id: 'x', name: 'Sam')),
      ),
      isTrue,
    );
    // A dive log export: JSON, but not shaped like a card from its first
    // byte, however its keys happen to read.
    expect(
      BuddyCardCodec.looksLikeFullCard(
        bytesOf('{"i":"x","n":"Sam","v":1,"samples":[]}'),
      ),
      isFalse,
    );
  });

  test('a name Windows reserves for a device gets a usable file name', () {
    for (final name in ['CON', 'nul', 'Com1', 'LPT9', 'aux', 'PRN']) {
      expect(BuddyCardCodec.fileNameFor(name), '_$name.subbuddy');
    }
    expect(BuddyCardCodec.fileNameFor('Connor'), 'Connor.subbuddy');
  });
}
