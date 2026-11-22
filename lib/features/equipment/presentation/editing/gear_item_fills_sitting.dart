import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/data/services/twin_fill_service.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/services/pairing_rules.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/log_fill_sheet.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_twin_set_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

const String _twinsKey = 'equipment.fills.twins';
const String _toTiedKey = 'equipment.fills.toTied';
const String _tiedTooKey = 'equipment.fills.tiedToo';

const _uuid = Uuid();

/// A cylinder's fills as its gear item's sitting has them (issue #4527,
/// phase 3), newest first: logged, edited and deleted on the cylinder
/// passport, written at Save. A twin set fill also writes its partner's
/// fill then, in the same transaction.
final gearItemFillsList = SittingList<EquipmentItem, CylinderFill>.withSession(
  key: 'equipment.fills',
  cardId: GearItemCardId.passportFills.name,
  read: (item) async => CylinderFillRepository().getForCylinder(
    passportId: await CylinderPassportRepository().getPassportId(item.id),
    equipmentId: item.id,
  ),
  writeIn: (session, loaded, current) => _write(session, loaded, current),
);

/// Reads the fills for a cylinder; other gear has none.
void loadGearItemFills(EditSession<EquipmentItem> session) {
  if (session.stored.type == EquipmentType.tank) {
    gearItemFillsList.load(session);
  } else {
    gearItemFillsList.loadNone(session);
  }
}

Map<String, String> _twins(EditSession<EquipmentItem> session) =>
    session.recall<Map<String, String>>(_twinsKey) ?? const {};

Set<String> _ids(EditSession<EquipmentItem> session, String key) =>
    session.recall<Set<String>>(key) ?? const {};

/// The fills, newest first.
List<CylinderFill> _sorted(Iterable<CylinderFill> fills) =>
    [...fills]..sort((a, b) => b.filledAt.compareTo(a.filledAt));

/// Logs [fill] in the sitting under an id of its own, and returns it. With
/// [twinPartnerId] it is a twin set fill: the partner's fill is written
/// with it at Save. Does nothing before the fills are read.
CylinderFill? holdLoggedFill(
  EditSession<EquipmentItem> session,
  CylinderFill fill, {
  String? twinPartnerId,
}) {
  final fills = gearItemFillsList.current(session);
  if (fills == null) return null;
  final held = fill.copyWith(id: _uuid.v4());
  if (twinPartnerId != null) {
    session.remember(_twinsKey, {..._twins(session), held.id: twinPartnerId});
  }
  gearItemFillsList.set(session, _sorted([...fills, held]));
  return held;
}

/// Puts [edited] in the place of the fill it edits. With [toTied] the edit
/// reaches the other fill of its twin set fill too, at Save.
void holdEditedFill(
  EditSession<EquipmentItem> session,
  CylinderFill edited, {
  bool toTied = false,
}) {
  final fills = gearItemFillsList.current(session);
  if (fills == null) return;
  final tied = {..._ids(session, _toTiedKey)};
  toTied ? tied.add(edited.id) : tied.remove(edited.id);
  session.remember(_toTiedKey, tied);
  gearItemFillsList.set(
    session,
    _sorted([for (final f in fills) f.id == edited.id ? edited : f]),
  );
}

/// Takes [fill] out of the sitting's fills. With [tiedToo] the other fill
/// of its twin set fill goes too, at Save.
void holdDeletedFill(
  EditSession<EquipmentItem> session,
  CylinderFill fill, {
  bool tiedToo = false,
}) {
  final fills = gearItemFillsList.current(session);
  if (fills == null) return;
  if (tiedToo) {
    session.remember(_tiedTooKey, {..._ids(session, _tiedTooKey), fill.id});
  }
  gearItemFillsList.set(session, [
    for (final f in fills)
      if (f.id != fill.id) f,
  ]);
}

/// The fills the sitting logs, newest first: what the tag write offered
/// after Save carries.
List<CylinderFill> newFillsOf(EditSession<EquipmentItem> session) {
  final loaded = {
    for (final f in gearItemFillsList.loaded(session) ?? const []) f.id,
  };
  return [
    for (final f in gearItemFillsList.current(session) ?? const [])
      if (!loaded.contains(f.id)) f,
  ];
}

/// The fill [fillId] as a Save stored it, with the partner's fill of its
/// twin set fill, for the tag write offered after Save; null when it is
/// not stored.
Future<LoggedFill?> savedLoggedFill(
  CylinderFillRepository fills,
  String fillId,
) async {
  final saved = await fills.getById(fillId);
  if (saved == null) return null;
  return LoggedFill(fill: saved, partnerFill: await fills.tiedFillOf(saved));
}

/// Whether [fill] is the sitting's: logged or edited in it.
bool isHeldFill(EditSession<EquipmentItem> session, CylinderFill fill) =>
    !(gearItemFillsList.loaded(session) ?? const []).contains(fill);

/// The pairing a fill dated [day] uses, as the sitting has the pairings: a
/// twin set made in the sitting is offered for a fill logged after it.
/// The log fill sheet hands it every pairing as stored, once they are read.
SittingPairingOn sittingPairingOn(EditSession<EquipmentItem> session) =>
    (stored, day) => pairingOn(
      pairingsInSitting(stored, heldPairingSteps(session)),
      session.stored.id,
      day,
    );

/// Writes the fills at Save, through the twin fill service, so a twin set
/// fill writes both fills (minting the partner's passport id when needed),
/// an edit reaches its tied fill when asked, and a delete takes its tied
/// fill when asked.
Future<Object?> _write(
  EditSession<EquipmentItem> session,
  List<CylinderFill> loaded,
  List<CylinderFill> current,
) async {
  final twins = TwinFillService();
  final fills = CylinderFillRepository();
  final before = {for (final f in loaded) f.id: f};
  final kept = {for (final f in current) f.id};
  final twinPartners = _twins(session);
  final toTied = _ids(session, _toTiedKey);
  final tiedToo = _ids(session, _tiedTooKey);
  // A new fill goes under the passport id the cylinder holds as it is
  // written, whatever the sitting showed when it was logged: a tag linked
  // in the sitting re-keys it with the others, whether it is written before
  // or after the link, and a link set back leaves it on the cylinder's own.
  final holds = await CylinderPassportRepository().getPassportId(
    session.stored.id,
  );
  for (final logged in current) {
    final old = before[logged.id];
    final fill = old == null && holds != null
        ? logged.copyWith(passportId: holds)
        : logged;
    if (old == null) {
      final partner = twinPartners[fill.id];
      if (partner == null) {
        await fills.create(fill);
      } else {
        await twins.recordTwinFill(fill, partnerEquipmentId: partner);
      }
    } else if (old != fill) {
      // An edit keeps the passport its row has by now: a tag linked in the
      // sitting may have re-keyed it already, and writing the id the edit
      // was made under would take that back.
      final row = await fills.getById(fill.id);
      await twins.applyEdit(
        row == null ? fill : fill.copyWith(passportId: row.passportId),
        toTied: toTied.contains(fill.id),
      );
    }
  }
  for (final old in loaded) {
    if (!kept.contains(old.id)) {
      await twins.delete(old, tiedToo: tiedToo.contains(old.id));
    }
  }
  return null;
}
