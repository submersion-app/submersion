import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:submersion/features/buddies/data/services/buddy_card_nfc.dart';
import 'package:submersion/features/buddies/data/services/card_emulation_service.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';
import 'package:submersion/features/buddies/domain/services/buddy_card_codec.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_ndef.dart';

import '../../../support/ndef_decode.dart';

import '../../../helpers/fake_nfc.dart';

class _FakeEmulation implements CardEmulation {
  final log = <String>[];
  Uint8List? presenting;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> start(Uint8List ndefMessage) async {
    log.add('start');
    presenting = ndefMessage;
  }

  @override
  Future<void> stop() async {
    log.add('stop');
    presenting = null;
  }
}

const _text = BuddyCardNfcText(
  readPrompt: 'Hold near',
  writePrompt: 'Hold near a sticker',
  notACard: 'Not a card',
  unreadable: 'Unreadable',
  readFailed: 'Read failed',
  written: 'Written',
  tooSmall: 'Too small',
  notWritable: 'Not writable',
  writeFailed: 'Write failed',
);

const _sam = BuddyCard(
  id: 'diver-sam',
  name: 'Sam Rivera',
  phone: '+1 555 0134',
  certs: [BuddyCardCert(agency: 'PADI', name: 'Rescue Diver')],
);

void main() {
  late _FakeEmulation emulation;
  setUp(() => emulation = _FakeEmulation());

  BuddyCardNfc nfc(FakeNfcTagService tags) =>
      BuddyCardNfc(tags: tags, emulation: emulation);

  NdefMessage cardMessage(BuddyCard card) => NdefMessage(
    records: [uriRecord(BuddyCardCodec.encodeLink(card, maxBytes: 400))],
  );

  test('readCard returns the card from the first card URI record', () async {
    final tags = FakeNfcTagService(
      tag: FakeTagHandle(stored: cardMessage(_sam)),
    );
    final result = await nfc(tags).readCard(_text);
    expect((result as BuddyCardDecoded).card.name, 'Sam Rivera');
  });

  test('a passport tag is not a card', () async {
    final tags = FakeNfcTagService(
      tag: FakeTagHandle(
        stored: NdefMessage(records: [uriRecord('https://submersion.app/c?x')]),
      ),
    );
    final result = await nfc(tags).readCard(_text);
    expect(
      (result as BuddyCardRejected).reason,
      BuddyCardRejectReason.notACard,
    );
  });

  test('writeSticker trims a full card to one URI record that fits', () async {
    final full = _sam.copyWith(
      email: 'sam.rivera@example.com',
      social: '@sam_rivera_dives',
      since: 2016,
      last: DateTime(2026, 10, 3),
    );
    expect(
      BuddyCardCodec.encodeLink(full, maxBytes: 2000).length,
      greaterThan(180),
    );
    final tag = FakeTagHandle(maxMessageBytes: 180);
    await nfc(FakeNfcTagService(tag: tag)).writeSticker(full, _text);
    final records = tag.stored!.records;
    expect(records, hasLength(1));
    expect(tag.stored!.byteLength, lessThanOrEqualTo(180));
    final decoded =
        BuddyCardCodec.decodeLink(uriOf(records.single)!) as BuddyCardDecoded;
    expect(decoded.card.name, 'Sam Rivera');
    expect(decoded.card.phone, '+1 555 0134');
    expect(decoded.trimmed, isTrue);
  });

  test('writeSticker on a tag too small even for the name throws', () async {
    final tag = FakeTagHandle(maxMessageBytes: 48);
    await expectLater(
      nfc(
        FakeNfcTagService(tag: tag),
      ).writeSticker(_sam.copyWith(name: 'A very long name ' * 4), _text),
      throwsA(isA<BuddyCardStickerTooSmall>()),
    );
    expect(tag.writes, 0);
  });

  test('writeSticker on a read-only tag throws', () async {
    await expectLater(
      nfc(
        FakeNfcTagService(tag: FakeTagHandle(isWritable: false)),
      ).writeSticker(_sam, _text),
      throwsA(isA<BuddyCardStickerNotWritable>()),
    );
  });

  test('startSharing hands emulation an NDEF message with the link', () async {
    await nfc(FakeNfcTagService()).startSharing(_sam);
    final message = decodeNdef(emulation.presenting!);
    final link = uriOf(message.records.single)!;
    expect(BuddyCardCodec.isCardLink(link), isTrue);
  });

  test('reading stops sharing first and resumes after', () async {
    final tags = FakeNfcTagService(
      tag: FakeTagHandle(stored: cardMessage(_sam)),
    );
    final cards = nfc(tags);
    await cards.startSharing(_sam);
    await cards.readCard(_text);
    expect(emulation.log, ['start', 'stop', 'start']);
    expect(emulation.presenting, isNotNull);
  });

  group('the iOS sheet closes as the result says', () {
    test('a card read closes as a success', () async {
      final tags = FakeNfcTagService(
        tag: FakeTagHandle(stored: cardMessage(_sam)),
      );
      await nfc(tags).readCard(_text);
      expect(tags.lastIosEnd?.error, isNull);
      expect(tags.lastIosEnd, isNotNull);
    });

    test('a tag that is not a card closes as a failure', () async {
      final tags = FakeNfcTagService(
        tag: FakeTagHandle(
          stored: NdefMessage(records: [uriRecord('https://example.com/x')]),
        ),
      );
      await nfc(tags).readCard(_text);
      expect(tags.lastIosEnd?.error, 'Not a card');
    });

    test('a sticker too small closes as a failure saying so', () async {
      final tags = FakeNfcTagService(tag: FakeTagHandle(maxMessageBytes: 48));
      await expectLater(
        nfc(tags).writeSticker(_sam.copyWith(name: 'A long name ' * 6), _text),
        throwsA(isA<BuddyCardStickerTooSmall>()),
      );
      expect(tags.lastIosEnd?.error, 'Too small');
    });

    test('a written sticker closes with the written message', () async {
      final tags = FakeNfcTagService(tag: FakeTagHandle());
      await nfc(tags).writeSticker(_sam, _text);
      expect(tags.lastIosEnd?.alert, 'Written');
    });
  });

  group('the link read or written is noted for the link dispatcher', () {
    test('a card read notes its link while the session is open', () async {
      final noted = <String>[];
      final tags = FakeNfcTagService(
        tag: FakeTagHandle(stored: cardMessage(_sam)),
      );
      final seenAtEnd = <int>[];
      tags.beforeEnd = () => seenAtEnd.add(noted.length);
      await BuddyCardNfc(
        tags: tags,
        emulation: emulation,
        onTagLink: noted.add,
      ).readCard(_text);
      expect(noted.single, uriOf(cardMessage(_sam).records.single));
      expect(seenAtEnd, [1]);
    });

    test('a written sticker notes the link it holds', () async {
      final noted = <String>[];
      final tag = FakeTagHandle();
      await BuddyCardNfc(
        tags: FakeNfcTagService(tag: tag),
        emulation: emulation,
        onTagLink: noted.add,
      ).writeSticker(_sam, _text);
      expect(noted.single, BuddyCardCodec.encodeLink(_sam, maxBytes: 1000));
    });
  });
}
