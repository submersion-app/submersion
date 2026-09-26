import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';

/// What a scanned, pasted or opened tag string turns out to be (spec 7.2).
sealed class PassportResolution {
  const PassportResolution();
}

/// A tag for one of the diver's own cylinders.
class OwnCylinder extends PassportResolution {
  const OwnCylinder({
    required this.equipmentId,
    required this.tag,
    this.newerFormat = false,
  });

  final String equipmentId;
  final CylinderPassportPayload tag;
  final bool newerFormat;
}

/// A tag for a cylinder the diver does not hold: a rental, a club tank.
class ForeignCylinder extends PassportResolution {
  const ForeignCylinder({required this.tag, this.newerFormat = false});

  final CylinderPassportPayload tag;
  final bool newerFormat;
}

/// Text that is not a cylinder tag.
class NotACylinderTag extends PassportResolution {
  const NotACylinderTag(this.reason);

  final PassportRejectReason reason;
}

/// Decodes a tag string and looks its passport id up among the diver's
/// cylinders. The lookup is injected so the domain stays free of the
/// database; callers pass the passport repository scoped to the diver.
class PassportResolver {
  const PassportResolver({required this.findEquipmentId});

  final Future<String?> Function(String passportId) findEquipmentId;

  Future<PassportResolution> resolve(String text) async {
    final decoded = PassportPayloadCodec.decode(text);
    switch (decoded) {
      case PassportRejected(:final reason):
        return NotACylinderTag(reason);
      case PassportDecoded(:final payload, :final newerFormat):
        final equipmentId = await findEquipmentId(payload.passportId);
        return equipmentId == null
            ? ForeignCylinder(tag: payload, newerFormat: newerFormat)
            : OwnCylinder(
                equipmentId: equipmentId,
                tag: payload,
                newerFormat: newerFormat,
              );
    }
  }
}
