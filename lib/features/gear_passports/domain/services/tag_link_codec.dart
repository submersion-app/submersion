import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_codec.dart';

sealed class TagLinkResult {
  const TagLinkResult();
}

/// A tag string that names an item: a cylinder (`/c`) or other gear (`/g`).
sealed class TagLinkDecoded extends TagLinkResult {
  const TagLinkDecoded();

  String get passportId;
  bool get newerFormat;
}

class CylinderTagLink extends TagLinkDecoded {
  const CylinderTagLink(this.payload, {this.newerFormat = false});

  final CylinderPassportPayload payload;
  @override
  final bool newerFormat;

  @override
  String get passportId => payload.passportId;
}

class GearTagLink extends TagLinkDecoded {
  const GearTagLink(this.payload, {this.newerFormat = false});

  final GearTagPayload payload;
  @override
  final bool newerFormat;

  @override
  String get passportId => payload.passportId;
}

class TagLinkRejected extends TagLinkResult {
  const TagLinkRejected();
}

/// Reads any Submersion tag string (gear tag spec 8.1): the path picks the
/// codec, and a bare query string is a cylinder payload, as it always was.
abstract final class TagLinkCodec {
  static TagLinkResult decode(String text) {
    if (GearTagCodec.extractQuery(text) != null) {
      return switch (GearTagCodec.decode(text)) {
        GearTagDecoded(:final payload, :final newerFormat) => GearTagLink(
          payload,
          newerFormat: newerFormat,
        ),
        GearTagRejected() => const TagLinkRejected(),
      };
    }
    return switch (PassportPayloadCodec.decode(text)) {
      PassportDecoded(:final payload, :final newerFormat) => CylinderTagLink(
        payload,
        newerFormat: newerFormat,
      ),
      PassportRejected() => const TagLinkRejected(),
    };
  }

  /// Whether [text] has the shape of a tag link of either kind, without
  /// judging its payload: incoming-link and NFC filters use this.
  static bool isTagLink(String text) =>
      GearTagCodec.extractQuery(text) != null ||
      PassportPayloadCodec.extractQuery(text) != null;

  /// The lower-case passport id [text] names, or null.
  static String? passportIdOf(String text) => switch (decode(text)) {
    TagLinkDecoded(:final passportId) => passportId.toLowerCase(),
    TagLinkRejected() => null,
  };
}
