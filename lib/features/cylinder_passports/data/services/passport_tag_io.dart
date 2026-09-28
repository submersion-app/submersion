import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_ndef.dart';

/// How a passport write ended.
sealed class PassportTagWrite {
  const PassportTagWrite();
}

/// Written and confirmed by reading it back.
class TagWritten extends PassportTagWrite {
  const TagWritten({
    required this.plan,
    required this.capacity,
    required this.typeLabel,
  });

  final PassportNdefPlan plan;
  final int capacity;
  final String? typeLabel;
}

/// The tag cannot hold NDEF at all.
class TagNotNdef extends PassportTagWrite {
  const TagNotNdef();
}

/// The tag is locked.
class TagReadOnly extends PassportTagWrite {
  const TagReadOnly();
}

/// Too small even for the identity.
class TagTooSmall extends PassportTagWrite {
  const TagTooSmall(this.capacity);

  final int capacity;
}

/// The tag took the write but reads back something else.
class TagReadBackMismatch extends PassportTagWrite {
  const TagReadBackMismatch();
}

/// The write or the read-back threw: usually the tag left the field.
class TagWriteFailed extends PassportTagWrite {
  const TagWriteFailed(this.error);

  final Object error;
}

/// Writes [payload] to [tag] (spec 13.3): fits it to the tag, writes the
/// whole message, and reads it back to confirm. Never throws. A partial
/// write is not resumed; the caller's Retry writes the whole message again.
Future<PassportTagWrite> writePassportTo(
  NdefTagHandle? tag,
  CylinderPassportPayload payload,
) async {
  if (tag == null) return const TagNotNdef();
  if (!tag.isWritable) return const TagReadOnly();
  final plan = planPassportMessage(
    payload,
    maxMessageBytes: tag.maxMessageBytes,
  );
  if (plan == null) return TagTooSmall(tag.maxMessageBytes);
  try {
    await tag.write(plan.message);
    final back = await tag.read();
    if (back != plan.message) return const TagReadBackMismatch();
    return TagWritten(
      plan: plan,
      capacity: tag.maxMessageBytes,
      typeLabel: tag.typeLabel,
    );
  } catch (e) {
    return TagWriteFailed(e);
  }
}

/// How a passport read ended.
sealed class PassportTagRead {
  const PassportTagRead();
}

class TagReadText extends PassportTagRead {
  const TagReadText(this.text);

  final String text;
}

/// No passport link on the tag (or no NDEF at all).
class TagHasNoPassport extends PassportTagRead {
  const TagHasNoPassport();
}

class TagReadFailed extends PassportTagRead {
  const TagReadFailed(this.error);

  final Object error;
}

/// The passport link on [tag], if it holds one. Never throws.
Future<PassportTagRead> readPassportFrom(NdefTagHandle? tag) async {
  if (tag == null) return const TagHasNoPassport();
  try {
    final message = await tag.read();
    final uri = message == null ? null : firstPassportUri(message);
    return uri == null ? const TagHasNoPassport() : TagReadText(uri);
  } catch (e) {
    return TagReadFailed(e);
  }
}

/// A readable name for a platform tag type (Android reports
/// `org.nfcforum.ndef.type2` and the like); other values pass through.
String? friendlyTagType(String? platformType) {
  if (platformType == null) return null;
  const forum = 'org.nfcforum.ndef.type';
  if (platformType.startsWith(forum)) {
    return 'NFC Forum Type ${platformType.substring(forum.length)}';
  }
  if (platformType == 'com.nxp.ndef.mifareclassic') return 'MIFARE Classic';
  return platformType;
}
