import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

String? _text(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}

String? _capped(String? s, int max) {
  final t = _text(s);
  return t == null ? null : PassportPayloadCodec.capCharacters(t, max);
}

/// The calendar date of the newest service record of any kind, or null.
DateTime? lastServiceDate(Iterable<ServiceRecord> records) {
  DateTime? newest;
  for (final r in records) {
    if (newest == null || r.serviceDate.isAfter(newest)) newest = r.serviceDate;
  }
  return newest == null ? null : _day(newest);
}

/// The tag [item] gets if one is written [now] (gear tag spec 6.2).
GearTagPayload gearPayloadForItem({
  required EquipmentItem item,
  required String passportId,
  required DateTime now,
  DateTime? lastService,
}) => GearTagPayload(
  passportId: passportId,
  typeCode: item.type.name,
  writtenOn: _day(now),
  name: _capped(item.name, GearTagPayload.maxNameLength),
  brand: _capped(item.brand, GearTagPayload.maxShortTextLength),
  model: _capped(item.model, GearTagPayload.maxShortTextLength),
  serial: _capped(item.serialNumber, GearTagPayload.maxShortTextLength),
  lastService: lastService == null ? null : _day(lastService),
);

/// Whether a scanned [tag] no longer describes [item] (gear tag spec 6.5):
/// a service recorded after the day it was written, another type, or a
/// name, brand, model or serial that differs from what the tag carries. A
/// field the tag left off (dropped to fit a small tag) is not a difference.
bool gearTagIsStale({
  required GearTagPayload tag,
  required EquipmentItem item,
  DateTime? lastService,
}) {
  final written = tag.writtenOn;
  if (written != null &&
      lastService != null &&
      _day(lastService).isAfter(written)) {
    return true;
  }
  if (tag.typeCode != item.type.name) return true;
  final current = gearPayloadForItem(
    item: item,
    passportId: tag.passportId,
    now: written ?? DateTime.now(),
  );
  bool differs(String? onTag, String? now) => onTag != null && onTag != now;
  return differs(tag.name, current.name) ||
      differs(tag.brand, current.brand) ||
      differs(tag.model, current.model) ||
      differs(tag.serial, current.serial);
}
