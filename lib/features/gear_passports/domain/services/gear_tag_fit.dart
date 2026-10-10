import 'package:submersion/features/cylinder_passports/domain/services/ndef_fit.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_codec.dart';

/// Fits a gear tag into a small NFC tag (gear tag spec 6.4): optional keys
/// are dropped first to last; `f`, `p`, `w` and `t` never are.
abstract final class GearTagFit {
  static const List<String> dropOrder = ['ls', 'mo', 'b', 'sn', 'n'];

  static GearTagPayload drop(GearTagPayload p, String key) => switch (key) {
    'ls' => p.copyWith(clearLastService: true),
    'mo' => p.copyWith(clearModel: true),
    'b' => p.copyWith(clearBrand: true),
    'sn' => p.copyWith(clearSerial: true),
    'n' => p.copyWith(clearName: true),
    _ => p,
  };

  /// [p] with optional keys dropped, in [dropOrder], until its link fits a
  /// printed label ([NdefFit.labelMaxUrlLength] characters), as cylinder
  /// labels are bounded. A typical payload is far shorter and prints whole;
  /// a long name in a script that percent-encodes to several characters per
  /// glyph is what goes first, and the label prints it as text anyway.
  static GearTagPayload fitForLabel(GearTagPayload p) {
    var current = p;
    for (final key in dropOrder) {
      if (GearTagCodec.httpsUrl(current).length <= NdefFit.labelMaxUrlLength) {
        return current;
      }
      current = drop(current, key);
    }
    return current;
  }
}
