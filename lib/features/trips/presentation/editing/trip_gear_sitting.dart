import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/checklists/domain/services/checklist_rows.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_equipment_repository.dart';
import 'package:submersion/features/trips/data/services/trip_fill_passport_copy.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_append.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

const _uuid = Uuid();

/// The gear packed for a trip, held in its sitting (issue #4527, phase 3):
/// read through [read] (the Gear tab's own read) and written through
/// [packs] at Save, packing the items the sitting added and unpacking the
/// ones it took off. Both are idempotent per trip and item, so a passport
/// sitting packing the same pair (phase 3 plan 7) never makes a second row.
SittingList<Trip, EquipmentItem> tripPackedGearList({
  required Future<List<EquipmentItem>> Function(String tripId) read,
  required TripEquipmentRepository packs,
}) => SittingList<Trip, EquipmentItem>(
  key: 'trip.packedGear',
  cardId: TripCardId.packedGear.name,
  read: (trip) => read(trip.id),
  write: (trip, loaded, current) async {
    final before = {for (final i in loaded) i.id};
    final after = {for (final i in current) i.id};
    final added = [
      for (final id in after)
        if (!before.contains(id)) id,
    ];
    if (added.isNotEmpty) await packs.pack(trip.id, added);
    for (final id in before) {
      if (!after.contains(id)) await packs.unpack(trip.id, id);
    }
    return added.isNotEmpty || before.difference(after).isNotEmpty;
  },
  same: (a, b) => sameIdSets(a, b, (i) => i.id),
);

/// What a fill's copy to its cylinder's passport needs besides the fill,
/// kept from the fill sheet until Save (see [TripFillPassportCopier]).
typedef TripFillCopyNote = ({
  String? diverId,
  String? stationName,
  bool stationResolved,
});

/// A trip's cylinder board as its sitting holds it: the slots in board
/// order, their ledger, and (read only) the logged dives' tanks on them,
/// which the board's state folds in. Every change returns a new value.
@immutable
class TripCylindersHeld {
  const TripCylindersHeld({
    this.slots = const [],
    this.events = const [],
    this.uses = const {},
    this.copies = const {},
  });

  /// In board order.
  final List<TripCylinder> slots;
  final List<TripCylinderEvent> events;

  /// The dive tanks linked to each slot, by slot id, as read.
  final Map<String, List<TripCylinderTankUse>> uses;

  /// What each fill logged or edited in the sitting copies to its
  /// passport with, by event id.
  final Map<String, TripFillCopyNote> copies;

  TripCylindersHeld copyWith({
    List<TripCylinder>? slots,
    List<TripCylinderEvent>? events,
    Map<String, TripFillCopyNote>? copies,
  }) => TripCylindersHeld(
    slots: slots ?? this.slots,
    events: events ?? this.events,
    uses: uses,
    copies: copies ?? this.copies,
  );

  /// Each slot with its state folded from the held ledger and the read
  /// tanks, in board order.
  List<TripCylinderState> get states => [
    for (final slot in slots)
      foldCylinderState(
        cylinder: slot,
        events: [
          for (final e in events)
            if (e.tripCylinderId == slot.id) e,
        ],
        uses: uses[slot.id] ?? const [],
      ),
  ];

  /// [drafts] after the last slot, less a tank already on the board (as
  /// `TripCylinderRepository.appendCylinders` has it), each with an id.
  /// Answers the slots added beside the new value.
  (TripCylindersHeld, List<TripCylinder>) withSlotsAppended(
    List<TripCylinder> drafts,
    String tripId,
  ) {
    final added = cylindersToAppend(
      [
        for (final s in slots)
          (equipmentId: s.equipmentId, sortOrder: s.sortOrder),
      ],
      drafts,
      tripId: tripId,
      newId: _uuid.v4,
    );
    return (copyWith(slots: [...slots, ...added]), added);
  }

  /// [created] (with their own orders, as the rental sheet numbers them)
  /// added after the last slot, each with an id.
  TripCylindersHeld withSlotsAdded(List<TripCylinder> created) => copyWith(
    slots: [
      ...slots,
      for (final c in created) c.id.isEmpty ? c.copyWith(id: _uuid.v4()) : c,
    ],
  );

  /// [edited] (a slot's label, size, pressure, preset or note) in place.
  TripCylindersHeld withSlotEdited(TripCylinder edited) =>
      copyWith(slots: [for (final s in slots) s.id == edited.id ? edited : s]);

  /// The slot gone, with its fills and adjustments.
  TripCylindersHeld withoutSlot(String id) => copyWith(
    slots: [
      for (final s in slots)
        if (s.id != id) s,
    ],
    events: [
      for (final e in events)
        if (e.tripCylinderId != id) e,
    ],
    copies: {
      for (final c in copies.entries)
        if (events.any((e) => e.id == c.key && e.tripCylinderId != id))
          c.key: c.value,
    },
  );

  /// The board laid out in [orderedIds]' order, the slots taking the sort
  /// orders they hold in that order ([reorderedSortOrders]), so a slot moved
  /// and moved back is no change.
  TripCylindersHeld withSlotsReordered(List<String> orderedIds) {
    final byId = {for (final s in slots) s.id: s};
    final listed = [for (final id in orderedIds) ?byId[id]];
    final orders = reorderedSortOrders([for (final s in listed) s.sortOrder]);
    return copyWith(
      slots: [
        for (var i = 0; i < listed.length; i++)
          listed[i].copyWith(sortOrder: orders[i]),
      ],
    );
  }

  /// [logged] in the ledger: one with no id is new and gets one, one with
  /// an id replaces the event it names. A fill's [note] is kept for its
  /// copy to the passport at Save.
  TripCylindersHeld withEvents(
    List<TripCylinderEvent> logged, {
    TripFillCopyNote? note,
  }) {
    final given = [
      for (final e in logged) e.id.isEmpty ? e.copyWith(id: _uuid.v4()) : e,
    ];
    final byId = {for (final e in given) e.id: e};
    return copyWith(
      events: [for (final e in events) byId.remove(e.id) ?? e, ...byId.values],
      copies: {
        ...copies,
        if (note != null)
          for (final e in given)
            if (e.kind == TripCylinderEventKind.fill) e.id: note,
      },
    );
  }

  /// The event gone from the ledger.
  TripCylindersHeld withoutEvent(String id) => copyWith(
    events: [
      for (final e in events)
        if (e.id != id) e,
    ],
    copies: {
      for (final c in copies.entries)
        if (c.key != id) c.key: c.value,
    },
  );

  @override
  bool operator ==(Object other) =>
      other is TripCylindersHeld &&
      listEquals(other.slots, slots) &&
      listEquals(other.events, events) &&
      identical(other.uses, uses) &&
      mapEquals(other.copies, copies);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(slots), Object.hashAll(events), uses);
}

/// A trip's cylinder board, held in its sitting as one value (a list of
/// one) shared by the Gear tab and the board, read from and written
/// through [cylinders], with fills copied to passports by [copier].
SittingList<Trip, TripCylindersHeld> tripCylindersList({
  required TripCylinderRepository cylinders,
  required TripFillPassportCopier copier,
}) => SittingList<Trip, TripCylindersHeld>(
  key: 'trip.cylinders',
  cardId: TripCardId.cylinders.name,
  read: (trip) async {
    final slots = await cylinders.getCylindersForTrip(trip.id);
    final events = slots.isEmpty
        ? const <String, List<TripCylinderEvent>>{}
        : await cylinders.getEventsForTrip(trip.id);
    final uses = slots.isEmpty
        ? const <String, List<TripCylinderTankUse>>{}
        : await cylinders.getTankUsesForTrip(trip.id);
    return [
      TripCylindersHeld(
        slots: slots,
        events: [for (final list in events.values) ...list],
        uses: uses,
      ),
    ];
  },
  write: (trip, loaded, current) => writeTripCylinders(
    loaded: loaded.single,
    current: current.single,
    cylinders: cylinders,
    copier: copier,
  ),
);

/// The board [session] holds through [list], or null before it is read.
TripCylindersHeld? heldCylindersOf(
  EditSession<Trip> session,
  SittingList<Trip, TripCylindersHeld> list,
) => list.current(session)?.singleOrNull;

/// Writes what [current] changed of [loaded], by id, so a slot or a fill
/// another device added meanwhile is never touched: slots made and edited,
/// fills made and edited with their passport copies, then fills and slots
/// deleted, then the board's order. Answers whether it wrote anything.
Future<bool> writeTripCylinders({
  required TripCylindersHeld loaded,
  required TripCylindersHeld current,
  required TripCylinderRepository cylinders,
  required TripFillPassportCopier copier,
}) async {
  var wrote = false;
  final wasSlot = {for (final s in loaded.slots) s.id: s};
  final isSlot = {for (final s in current.slots) s.id: s};
  final wasEvent = {for (final e in loaded.events) e.id: e};
  final isEvent = {for (final e in current.events) e.id: e};

  final created = [
    for (final s in current.slots)
      if (!wasSlot.containsKey(s.id)) s,
  ];
  if (created.isNotEmpty) {
    await cylinders.createCylinders(created);
    wrote = true;
  }
  for (final s in current.slots) {
    final was = wasSlot[s.id];
    if (was != null && was != s.copyWith(sortOrder: was.sortOrder)) {
      await cylinders.updateCylinder(s);
      wrote = true;
    }
  }

  final newEvents = [
    for (final e in current.events)
      if (!wasEvent.containsKey(e.id)) e,
  ];
  if (newEvents.isNotEmpty) {
    await cylinders.createEvents(newEvents);
    wrote = true;
  }
  final changed = [
    for (final e in current.events)
      if (wasEvent[e.id] case final was? when was != e) e,
  ];
  for (final e in changed) {
    try {
      await cylinders.updateEvent(e);
    } on TripCylinderEventMissing {
      // Deleted since it was read (by a sync, say): the diver still wants
      // it as the sitting has it.
      await cylinders.createEvents([e]);
    }
    wrote = true;
  }
  for (final e in [...newEvents, ...changed]) {
    final slot = isSlot[e.tripCylinderId];
    if (slot == null || e.kind != TripCylinderEventKind.fill) continue;
    final note = current.copies[e.id];
    await copier.afterSave(
      e,
      slot,
      diverId: note?.diverId,
      stationName: note?.stationName,
      stationResolved: note?.stationResolved ?? false,
    );
  }

  for (final e in loaded.events) {
    if (isEvent.containsKey(e.id) || !isSlot.containsKey(e.tripCylinderId)) {
      continue;
    }
    await cylinders.deleteEvent(
      e.id,
      alongside: () => copier.afterDelete(e.id),
    );
    wrote = true;
  }
  for (final s in loaded.slots) {
    if (isSlot.containsKey(s.id)) continue;
    // Its fills, its dive tanks' links and the slot go; the passport copies
    // stay, as a slot's delete has always kept them.
    await cylinders.deleteCylinder(s.id);
    wrote = true;
  }

  final kept = [
    for (final s in current.slots)
      if (wasSlot[s.id] case final was? when was.sortOrder != s.sortOrder) s,
  ];
  if (kept.isNotEmpty) {
    await cylinders.reorderCylinders([
      for (final s in [
        ...current.slots,
      ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
        s.id,
    ]);
    wrote = true;
  }
  return wrote;
}

/// What the Gear tab's Add and its rows change: held in the trip page's
/// sitting (issue #4527, [HeldTripGearWrites]).
abstract interface class TripGearWrites {
  /// Packs [items]; answers how many were not packed already.
  Future<int> pack(List<EquipmentItem> items);

  Future<void> unpack(String equipmentId);

  /// Appends [drafts] after the board's last slot, leaving out a tank
  /// already on it; answers the slots added.
  Future<List<TripCylinder>> appendCylinders(List<TripCylinder> drafts);

  /// Adds [drafts] with the orders they carry (rental slots).
  Future<void> createCylinders(List<TripCylinder> drafts);

  /// The board's slots now.
  Future<List<TripCylinder>> slots();
}

/// Holds each change in [session] until Save: packed gear in [packed], the
/// board in [board].
class HeldTripGearWrites implements TripGearWrites {
  HeldTripGearWrites({
    required this.session,
    required this.packed,
    required this.board,
  });

  final EditSession<Trip> session;
  final SittingList<Trip, EquipmentItem> packed;
  final SittingList<Trip, TripCylindersHeld> board;

  TripCylindersHeld get _board =>
      heldCylindersOf(session, board) ?? const TripCylindersHeld();

  @override
  Future<int> pack(List<EquipmentItem> items) async {
    final current = packed.current(session);
    // Before the packed gear is read nothing can be held.
    if (current == null) return 0;
    final have = {for (final i in current) i.id};
    final added = [
      for (final i in items)
        if (have.add(i.id)) i,
    ];
    if (added.isNotEmpty) {
      packed.set(
        session,
        [...current, ...added]
          ..sort((a, b) => compareTextForSort(a.name, b.name)),
      );
    }
    return added.length;
  }

  @override
  Future<void> unpack(String equipmentId) async => packed.set(session, [
    for (final i in packed.current(session) ?? const <EquipmentItem>[])
      if (i.id != equipmentId) i,
  ]);

  @override
  Future<List<TripCylinder>> appendCylinders(List<TripCylinder> drafts) async {
    // Before the board is read nothing can be held.
    if (heldCylindersOf(session, board) == null) return const [];
    final (next, added) = _board.withSlotsAppended(drafts, session.stored.id);
    if (added.isNotEmpty) board.set(session, [next]);
    return added;
  }

  @override
  Future<void> createCylinders(List<TripCylinder> drafts) async =>
      board.set(session, [_board.withSlotsAdded(drafts)]);

  @override
  Future<List<TripCylinder>> slots() async => _board.slots;
}
