import 'package:ndef_record/ndef_record.dart';

import 'package:submersion/features/cylinder_passports/domain/services/passport_ndef.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_codec.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_fit.dart';

/// What a gear tag write puts on the tag.
class GearNdefPlan implements TagNdefPlan {
  const GearNdefPlan({
    required this.message,
    required this.payload,
    required this.droppedKeys,
    required this.includesAndroidRecord,
  });

  @override
  final NdefMessage message;

  /// The payload the identity record carries, after any drops.
  final GearTagPayload payload;

  @override
  final List<String> droppedKeys;

  @override
  final bool includesAndroidRecord;

  @override
  String get url => GearTagCodec.httpsUrl(payload);

  @override
  bool get includesFill => false;
}

/// The message for [payload] on a tag whose NDEF message may take
/// [maxMessageBytes]; null when even the identity and type do not fit.
GearNdefPlan? planGearMessage(
  GearTagPayload payload, {
  required int maxMessageBytes,
}) {
  final fitted = fitUriMessage<GearTagPayload>(
    payload,
    url: GearTagCodec.httpsUrl,
    dropOrder: GearTagFit.dropOrder,
    drop: GearTagFit.drop,
    maxMessageBytes: maxMessageBytes,
  );
  if (fitted == null) return null;
  return GearNdefPlan(
    message: fitted.message,
    payload: fitted.payload,
    droppedKeys: fitted.dropped,
    includesAndroidRecord: fitted.withAar,
  );
}
