import 'dart:typed_data';

import 'package:ndef_record/ndef_record.dart';

import 'package:submersion/features/buddies/data/services/card_emulation_service.dart';
import 'package:submersion/features/buddies/data/services/ndef_bytes.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';
import 'package:submersion/features/buddies/domain/services/buddy_card_codec.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_ndef.dart';

/// The sticker cannot hold even the shortest card (name and id).
class BuddyCardStickerTooSmall implements Exception {
  const BuddyCardStickerTooSmall();
}

/// The tag cannot be written: locked, or not an NDEF tag.
class BuddyCardStickerNotWritable implements Exception {
  const BuddyCardStickerNotWritable();
}

/// What the system NFC sheet says while reading or writing a card. iOS
/// shows these; without them it closes every session with a success tick,
/// which would contradict a failed read or write.
class BuddyCardNfcText {
  const BuddyCardNfcText({
    required this.readPrompt,
    required this.writePrompt,
    required this.notACard,
    required this.unreadable,
    required this.readFailed,
    required this.written,
    required this.tooSmall,
    required this.notWritable,
    required this.writeFailed,
  });

  final String readPrompt;
  final String writePrompt;
  final String notACard;
  final String unreadable;
  final String readFailed;
  final String written;
  final String tooSmall;
  final String notWritable;
  final String writeFailed;
}

enum _StickerOutcome { written, tooSmall, notWritable }

/// Buddy cards over NFC (issue #3728): reading a card from a sticker or
/// from an Android phone acting as one, writing a sticker, and (on
/// Android) acting as a tag that holds this diver's card.
class BuddyCardNfc {
  BuddyCardNfc({
    required NfcTagService tags,
    required CardEmulation emulation,
    void Function(String link)? onTagLink,
  }) : _tags = tags,
       _emulation = emulation,
       _onTagLink = onTagLink;

  final NfcTagService _tags;
  final CardEmulation _emulation;

  /// Told each card link read or written, while the session is still open:
  /// once it ends Android dispatches a tag still held as an incoming link,
  /// and the link dispatcher drops that repeat.
  final void Function(String link)? _onTagLink;
  BuddyCard? _sharing;

  /// The longest link this device presents as a tag: well under what the
  /// emulated tag allows, so a reader needs few reads.
  static const int sharedLinkMaxBytes = 1000;

  /// Waits for a tag and reads a card from it. An Android phone that is
  /// presenting its own card stops while it reads, since a phone cannot be
  /// a tag and read one at once, and starts again after.
  Future<BuddyCardDecodeResult> readCard(BuddyCardNfcText text) async {
    final sharing = _sharing;
    if (sharing != null) await _emulation.stop();
    try {
      return await _tags.withTag(
        promptIos: text.readPrompt,
        onTag: (tag) async {
          if (tag == null) {
            return const BuddyCardRejected(BuddyCardRejectReason.notACard);
          }
          final message = tag.discoveredMessage ?? await tag.read();
          for (final record in message?.records ?? const <NdefRecord>[]) {
            final uri = uriOf(record);
            if (uri != null && BuddyCardCodec.isCardLink(uri)) {
              _onTagLink?.call(uri);
              return BuddyCardCodec.decodeLink(uri);
            }
          }
          return const BuddyCardRejected(BuddyCardRejectReason.notACard);
        },
        iosEnd: (result) => switch (result) {
          BuddyCardDecoded() => const IosSheetEnd.success(),
          BuddyCardRejected(reason: BuddyCardRejectReason.notACard) =>
            IosSheetEnd.failure(text.notACard),
          BuddyCardRejected() => IosSheetEnd.failure(text.unreadable),
        },
        iosFailure: text.readFailed,
      );
    } finally {
      if (sharing != null && _sharing == sharing) {
        await _emulation.start(_message(sharing));
      }
    }
  }

  /// Writes [card] to a sticker as one URI record, trimmed to fit it.
  /// Throws [BuddyCardStickerNotWritable] or [BuddyCardStickerTooSmall].
  Future<void> writeSticker(BuddyCard card, BuddyCardNfcText text) async {
    final outcome = await _tags.withTag(
      promptIos: text.writePrompt,
      onTag: (tag) async {
        if (tag == null || !tag.isWritable) return _StickerOutcome.notWritable;
        final NdefMessage message;
        try {
          message = _fitted(card, tag.maxMessageBytes);
        } on BuddyCardStickerTooSmall {
          return _StickerOutcome.tooSmall;
        }
        await tag.write(message);
        final link = uriOf(message.records.single);
        if (link != null) _onTagLink?.call(link);
        return _StickerOutcome.written;
      },
      iosEnd: (outcome) => switch (outcome) {
        _StickerOutcome.written => IosSheetEnd.success(text.written),
        _StickerOutcome.tooSmall => IosSheetEnd.failure(text.tooSmall),
        _StickerOutcome.notWritable => IosSheetEnd.failure(text.notWritable),
      },
      iosFailure: text.writeFailed,
    );
    switch (outcome) {
      case _StickerOutcome.written:
        return;
      case _StickerOutcome.tooSmall:
        throw const BuddyCardStickerTooSmall();
      case _StickerOutcome.notWritable:
        throw const BuddyCardStickerNotWritable();
    }
  }

  /// The card as a single URI record no larger than [maxMessageBytes].
  static NdefMessage _fitted(BuddyCard card, int maxMessageBytes) {
    // The record drops `https://` (a one-byte prefix code) and adds a
    // header of 4 bytes, or 7 once the payload passes 255: start from the
    // short-record estimate and tighten until the record fits.
    var linkMax = maxMessageBytes + 3;
    while (linkMax > 0) {
      final String link;
      try {
        link = BuddyCardCodec.encodeLink(card, maxBytes: linkMax);
      } on BuddyCardTooLarge {
        throw const BuddyCardStickerTooSmall();
      }
      final message = NdefMessage(records: [uriRecord(link)]);
      if (message.byteLength <= maxMessageBytes) return message;
      linkMax -= 4;
    }
    throw const BuddyCardStickerTooSmall();
  }

  /// Presents [card] as a tag until [stopSharing] (Android only).
  Future<void> startSharing(BuddyCard card) async {
    _sharing = card;
    await _emulation.start(_message(card));
  }

  Future<void> stopSharing() async {
    if (_sharing == null) return;
    _sharing = null;
    await _emulation.stop();
  }

  static Uint8List _message(BuddyCard card) => encodeNdef(
    NdefMessage(
      records: [
        uriRecord(
          BuddyCardCodec.encodeLink(card, maxBytes: sharedLinkMaxBytes),
        ),
      ],
    ),
  );
}
