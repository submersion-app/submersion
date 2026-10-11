import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_codec.dart';

String gearPassportLocation(String equipmentId) =>
    '/equipment/$equipmentId/gear-passport';

/// Where a gear tag the diver does not hold opens. The tag rides in the
/// query so the page survives a restart; its payload is public by design.
String foreignGearLocation(GearTagPayload tag) => Uri(
  path: '/equipment/gear-tag',
  queryParameters: {'t': GearTagCodec.httpsUrl(tag)},
).toString();

/// The scanned gear tag a route carried, or null for any other extra.
GearTagPayload? scannedGearTagFrom(Object? extra) =>
    extra is GearTagPayload ? extra : null;
