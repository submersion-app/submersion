import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';

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
}
