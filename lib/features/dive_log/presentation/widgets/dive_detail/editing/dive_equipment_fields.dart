import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/services/gear_expander.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/equipment/presentation/utils/usable_set_items.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _log = LoggerService('DiveEquipmentFields');

/// The Equipment card's id: its section's name.
final String diveEquipmentCardId = DiveDetailSectionId.equipment.name;

/// What a link says about the dive: which item, and how it came.
(String, String?, String?) _linkKey(GearLink link) =>
    (link.item.id, link.viaEquipmentId, link.viaSetId);

bool _sameGear(List<GearLink> a, List<GearLink> b) {
  if (a.length != b.length) return false;
  final keys = {for (final link in a) _linkKey(link)};
  return b.every((link) => keys.contains(_linkKey(link)));
}

/// The dive's gear, edited on the Equipment card (issue #4527).
///
/// Compared as a set of which item came how: the writer keys rows by item
/// and the card arranges them by the diver's own order, so the list's order
/// means nothing, and an item renamed elsewhere is not a change of the dive.
final diveGearField = EditField<Dive, List<GearLink>>(
  id: 'gear',
  cardId: diveEquipmentCardId,
  read: (dive) => dive.gear,
  write: (dive, gear) => dive.copyWith(gear: gear),
  equals: _sameGear,
);

/// The sitting's gear rows, with where each came from.
List<GearProvenance> sittingGearRows(EditSession<Dive> session) => [
  for (final link in session.valueOf(diveGearField)) link.provenance,
];

/// Keeps the gear [rows] name, with the provenance they give: what the gear
/// tree hands back when a part, a subtree or a set is taken off.
void keepGearRows(EditSession<Dive> session, List<GearProvenance> rows) {
  if (session.isFrozen || session.isDisposed) return;
  final items = {
    for (final link in session.valueOf(diveGearField)) link.item.id: link.item,
  };
  session.set(
    diveGearField,
    gearLinksFor([for (final row in rows) ?items[row.equipmentId]], rows),
  );
}

/// Takes set [setId] off the dive, with its gear, or keeping the gear as
/// the dive's own ([keepGear]) (issue #4500).
void removeSetFromSitting(
  EditSession<Dive> session,
  String setId, {
  required bool keepGear,
}) {
  final rows = sittingGearRows(session);
  keepGearRows(
    session,
    keepGear
        ? GearExpander.unlinkSet(rows, setId)
        : GearExpander.removeSet(rows, setId),
  );
}

void clearGear(EditSession<Dive> session) {
  if (session.isFrozen || session.isDisposed) return;
  session.set(diveGearField, const <GearLink>[]);
}

/// The latest gear add in a sitting: adds run one after another.
const _addKey = 'gearAdd';

/// Adds [items] as the old dive form did: for a set ([viaSetId]), only the
/// members the dive's diver may use (issue #2046); merged by id; assemblies
/// expanded with their parts (issue #1487). Providers are read through [read].
///
/// Adds run one at a time, in the order asked, each on the gear the one
/// before it left, and Save waits for them. An add drops its result when
/// the sitting has ended or is being saved, or [stillWanted] says no (a
/// site's location set, once the site changed again). It goes on after the
/// card that asked closes, so [read] must outlive that card's widget.
Future<void> addGearToSitting(
  ProviderRead read,
  EditSession<Dive> session,
  List<EquipmentItem> items, {
  String? viaSetId,
  bool Function()? stillWanted,
}) {
  final previous = session.recall<Future<void>>(_addKey);
  final run = () async {
    // The previous add's failure is its own caller's to report.
    if (previous != null) await previous.then((_) {}, onError: (_) {});
    await _addNow(read, session, items, viaSetId, stillWanted);
  }();
  session
    ..remember(_addKey, run)
    ..track(run);
  return run;
}

Future<void> _addNow(
  ProviderRead read,
  EditSession<Dive> session,
  List<EquipmentItem> items,
  String? viaSetId,
  bool Function()? stillWanted,
) async {
  bool alive() =>
      !session.isDisposed && !session.isFrozen && (stillWanted?.call() ?? true);
  if (items.isEmpty || !alive()) return;
  var toAdd = items;
  String? diverId = session.stored.diverId;
  if (diverId == null) {
    // An unreadable diver adds unscoped, as before sharing, rather than
    // failing the add.
    try {
      diverId = await read(validatedCurrentDiverIdProvider.future);
    } catch (_) {
      diverId = null;
    }
    if (!alive()) return;
  }
  if (viaSetId != null && diverId != null) {
    try {
      final usable = await EquipmentRepository().usableSetMemberIds([
        for (final item in items) item.id,
      ], diverId);
      toAdd = usableSetItems(items, usable.toSet());
    } catch (error, stackTrace) {
      _log.warning(
        'Reading which set members the diver may use failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!alive()) return;
  }
  if (toAdd.isEmpty) return;
  // The gear can change while the parts are read (a row removed, Clear
  // all): the add is then worked out again on what is there now, so it
  // never puts back what the diver took off. It is only ever written over
  // the gear it was worked out on; each try again waits on the diver
  // changing the gear once more, so the tries end.
  while (true) {
    final current = session.valueOf(diveGearField);
    final merged = [
      for (final link in current) link.item,
      for (final item in toAdd)
        if (!current.any((link) => link.item.id == item.id)) item,
    ];
    final expansion = await expandGear(
      read,
      additions: [
        for (final item in toAdd) (equipmentId: item.id, viaSetId: viaSetId),
      ],
      existing: [for (final link in current) link.provenance],
      existingItems: merged,
      diverId: diverId,
    );
    if (!alive()) return;
    if (!identical(session.valueOf(diveGearField), current)) continue;
    session.set(
      diveGearField,
      gearLinksFor([...merged, ...expansion.newItems], expansion.provenance),
    );
    return;
  }
}
