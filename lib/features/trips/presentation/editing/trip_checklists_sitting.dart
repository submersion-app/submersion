import 'package:flutter/foundation.dart';

import 'package:clock/clock.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklists_repository.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_section.dart';
import 'package:submersion/features/checklists/domain/services/checklist_rows.dart';
import 'package:submersion/features/checklists/presentation/editing/trip_checklist_writes.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

const _uuid = Uuid();

/// A trip's checklists with their sections and items, as one value: what
/// the Checklist tab shows and its sitting holds (issue #4527, phase 3).
/// Every change returns a new value; [checklists] are in the trip's order.
@immutable
class TripChecklistsHeld {
  const TripChecklistsHeld({
    this.checklists = const [],
    this.sections = const [],
    this.items = const [],
    this.itemsMovedOnDelete = const {},
  });

  final List<TripChecklist> checklists;
  final List<TripChecklistSection> sections;
  final List<TripChecklistItem> items;

  /// Where each section deleted in the sitting sent its items, by section
  /// id: what its delete at Save does with an item stored there meanwhile
  /// (another device's). Absent, they go with it.
  final Map<String, String> itemsMovedOnDelete;

  /// [checklistId]'s items, in their order.
  List<TripChecklistItem> itemsOf(String checklistId) => [
    for (final i in items)
      if (i.checklistId == checklistId) i,
  ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  /// [checklistId]'s sections, in their order.
  List<TripChecklistSection> sectionsOf(String checklistId) => [
    for (final s in sections)
      if (s.checklistId == checklistId) s,
  ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  TripChecklistsHeld copyWith({
    List<TripChecklist>? checklists,
    List<TripChecklistSection>? sections,
    List<TripChecklistItem>? items,
    Map<String, String>? itemsMovedOnDelete,
  }) => TripChecklistsHeld(
    checklists: checklists ?? this.checklists,
    sections: sections ?? this.sections,
    items: items ?? this.items,
    itemsMovedOnDelete: itemsMovedOnDelete ?? this.itemsMovedOnDelete,
  );

  /// [checklist] added at the end.
  TripChecklistsHeld withChecklist(TripChecklist checklist) => copyWith(
    checklists: [
      ...checklists,
      checklist.copyWith(
        sortOrder: nextSortOrder([for (final c in checklists) c.sortOrder]),
      ),
    ],
  );

  TripChecklistsHeld withChecklistRenamed(String id, String name) => copyWith(
    checklists: [
      for (final c in checklists) c.id == id ? c.copyWith(name: name) : c,
    ],
  );

  /// The checklists laid out in [orderedIds]' order, taking the sort
  /// orders they hold in that order ([reorderedSortOrders]).
  TripChecklistsHeld withChecklistsReordered(List<String> orderedIds) {
    final byId = {for (final c in checklists) c.id: c};
    final listed = [for (final id in orderedIds) ?byId[id]];
    final orders = reorderedSortOrders([for (final c in listed) c.sortOrder]);
    return copyWith(
      checklists: [
        for (var i = 0; i < listed.length; i++)
          listed[i].copyWith(sortOrder: orders[i]),
      ],
    );
  }

  /// The checklist gone, with its sections and items.
  TripChecklistsHeld withoutChecklist(String id) => TripChecklistsHeld(
    itemsMovedOnDelete: itemsMovedOnDelete,
    checklists: [
      for (final c in checklists)
        if (c.id != id) c,
    ],
    sections: [
      for (final s in sections)
        if (s.checklistId != id) s,
    ],
    items: [
      for (final i in items)
        if (i.checklistId != id) i,
    ],
  );

  /// The checklist's items gone, its sections kept.
  TripChecklistsHeld withItemsCleared(String checklistId) => copyWith(
    items: [
      for (final i in items)
        if (i.checklistId != checklistId) i,
    ],
  );

  /// The checklist's items and sections gone.
  TripChecklistsHeld withContentCleared(String checklistId) => copyWith(
    sections: [
      for (final s in sections)
        if (s.checklistId != checklistId) s,
    ],
    items: [
      for (final i in items)
        if (i.checklistId != checklistId) i,
    ],
  );

  /// [rows] (a template's) added.
  TripChecklistsHeld withRows(ChecklistTemplateRows rows) => copyWith(
    sections: [...sections, ...rows.sections],
    items: [...items, ...rows.items],
  );

  /// [item] in place of the item with its id, or added at the end of its
  /// checklist when there is none.
  TripChecklistsHeld withItem(TripChecklistItem item) {
    if (items.any((i) => i.id == item.id)) {
      return copyWith(
        items: [for (final i in items) i.id == item.id ? item : i],
      );
    }
    final next = nextSortOrder([
      for (final i in itemsOf(item.checklistId)) i.sortOrder,
    ]);
    return copyWith(
      items: [
        ...items,
        item.copyWith(sortOrder: next),
      ],
    );
  }

  TripChecklistsHeld withoutItem(String id) => copyWith(
    items: [
      for (final i in items)
        if (i.id != id) i,
    ],
  );

  /// The item ticked or not, stamped [at] when ticked, as the repository's
  /// toggle stamps it.
  TripChecklistsHeld withItemDone(
    String id, {
    required bool isDone,
    required DateTime at,
  }) => copyWith(
    items: [
      for (final i in items)
        i.id == id
            ? i.copyWith(isDone: isDone, completedAt: isDone ? at : null)
            : i,
    ],
  );

  /// [section] added at the end of its checklist.
  TripChecklistsHeld withSection(TripChecklistSection section) => copyWith(
    sections: [
      ...sections,
      section.copyWith(
        sortOrder: nextSortOrder([
          for (final s in sectionsOf(section.checklistId)) s.sortOrder,
        ]),
      ),
    ],
  );

  TripChecklistsHeld withSectionRenamed(String id, String title) => copyWith(
    sections: [
      for (final s in sections) s.id == id ? s.copyWith(title: title) : s,
    ],
  );

  /// The checklist's sections laid out in [orderedIds]' order, taking the
  /// sort orders they hold in that order ([reorderedSortOrders]).
  TripChecklistsHeld withSectionsReordered(
    String checklistId,
    List<String> orderedIds,
  ) {
    final position = _positions(orderedIds, {
      for (final s in sections)
        if (s.checklistId == checklistId) s.id: s.sortOrder,
    });
    return copyWith(
      sections: [
        for (final s in sections)
          if (s.checklistId == checklistId && position.containsKey(s.id))
            s.copyWith(sortOrder: position[s.id])
          else
            s,
      ],
    );
  }

  /// The section gone, its items moved to [moveItemsToSectionId] or gone
  /// with it.
  TripChecklistsHeld withoutSection(
    String id, {
    String? moveItemsToSectionId,
  }) => TripChecklistsHeld(
    checklists: checklists,
    itemsMovedOnDelete: {...itemsMovedOnDelete, id: ?moveItemsToSectionId},
    sections: [
      for (final s in sections)
        if (s.id != id) s,
    ],
    items: [
      for (final i in items)
        if (i.sectionId != id)
          i
        else if (moveItemsToSectionId != null)
          i.copyWith(sectionId: moveItemsToSectionId),
    ],
  );

  /// [itemId] moved to [targetSectionId], and the checklist's items laid
  /// out in [orderedIds]' order, taking the sort orders they hold in that
  /// order ([reorderedSortOrders]).
  TripChecklistsHeld withItemMoved({
    required String checklistId,
    required String itemId,
    required String? targetSectionId,
    required List<String> orderedIds,
  }) {
    final position = _positions(orderedIds, {
      for (final i in items)
        if (i.checklistId == checklistId) i.id: i.sortOrder,
    });
    return copyWith(
      items: [
        for (final i in items)
          if (i.checklistId != checklistId)
            i
          else
            i.copyWith(
              sectionId: i.id == itemId ? targetSectionId : i.sectionId,
              sortOrder: position[i.id] ?? i.sortOrder,
            ),
      ],
    );
  }

  /// The sort order each of [orderedIds] (of [held], ids to sort orders)
  /// takes, laid out in that order.
  static Map<String, int> _positions(
    List<String> orderedIds,
    Map<String, int> held,
  ) {
    final listed = [
      for (final id in orderedIds)
        if (held.containsKey(id)) id,
    ];
    final orders = reorderedSortOrders([for (final id in listed) held[id]!]);
    return {for (var i = 0; i < listed.length; i++) listed[i]: orders[i]};
  }

  @override
  bool operator ==(Object other) =>
      other is TripChecklistsHeld &&
      listEquals(other.checklists, checklists) &&
      listEquals(other.sections, sections) &&
      listEquals(other.items, items) &&
      mapEquals(other.itemsMovedOnDelete, itemsMovedOnDelete);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(checklists),
    Object.hashAll(sections),
    Object.hashAll(items),
  );
}

/// A trip's checklists, held in its sitting as one value (a list of one),
/// read from and written through the repositories given (the app's
/// providers where there are some, so a test can stand in for them). What
/// the list holds lives in the sitting under its key, so every list made by
/// this function is the same list.
SittingList<Trip, TripChecklistsHeld> tripChecklistsList({
  required TripChecklistsRepository checklists,
  required TripChecklistRepository items,
}) => SittingList<Trip, TripChecklistsHeld>(
  key: 'trip.checklists',
  cardId: TripCardId.checklists.name,
  read: (trip) async {
    final stored = await checklists.getChecklistsForTrip(trip.id);
    return [
      TripChecklistsHeld(
        checklists: stored,
        sections: stored.isEmpty
            ? const []
            : await items.getSectionsForTrip(trip.id),
        items: await items.getAllItemsForTrip(trip.id),
      ),
    ];
  },
  write: (trip, loaded, current) => writeTripChecklists(
    tripId: trip.id,
    loaded: loaded.single,
    current: current.single,
    checklists: checklists,
    items: items,
  ),
);

/// Writes what [current] changed of [loaded], by id: rows the sitting never
/// read (another device's) are not touched. Created, then changed, then
/// deleted, then reordered. Answers whether it wrote anything.
Future<bool> writeTripChecklists({
  required String tripId,
  required TripChecklistsHeld loaded,
  required TripChecklistsHeld current,
  required TripChecklistsRepository checklists,
  required TripChecklistRepository items,
}) async {
  var wrote = false;
  final wasChecklist = {for (final c in loaded.checklists) c.id: c};
  final isChecklist = {for (final c in current.checklists) c.id: c};
  final wasSection = {for (final s in loaded.sections) s.id: s};
  final isSection = {for (final s in current.sections) s.id: s};
  final wasItem = {for (final i in loaded.items) i.id: i};
  final isItem = {for (final i in current.items) i.id: i};

  for (final c in current.checklists) {
    final was = wasChecklist[c.id];
    if (was == null) {
      await checklists.createChecklist(tripId: tripId, name: c.name, id: c.id);
      wrote = true;
    } else if (was.name != c.name) {
      await checklists.renameChecklist(c.id, c.name);
      wrote = true;
    }
  }
  // Per checklist, in their held order: new sections are numbered as they
  // are made, so that order is the one they keep.
  for (final s in [
    for (final c in current.checklists) ...current.sectionsOf(c.id),
  ]) {
    final was = wasSection[s.id];
    if (was == null) {
      await items.createSection(
        checklistId: s.checklistId,
        title: s.title,
        id: s.id,
      );
      wrote = true;
    } else if (was.title != s.title) {
      await items.renameSection(s.id, s.title);
      wrote = true;
    }
  }
  for (final i in current.items) {
    final was = wasItem[i.id];
    if (was == null) {
      await items.createItem(i, keepSortOrder: true);
      wrote = true;
    } else if (was != i) {
      await items.updateItem(i);
      wrote = true;
    }
  }
  // Items of a checklist that goes are removed with it. Each other item
  // the sitting removed is deleted itself, before its section's delete:
  // that delete may move what is left in the section elsewhere.
  for (final i in loaded.items) {
    if (isItem.containsKey(i.id) || !isChecklist.containsKey(i.checklistId)) {
      continue;
    }
    await items.deleteItem(i.id);
    wrote = true;
  }
  for (final s in loaded.sections) {
    if (isSection.containsKey(s.id) ||
        !isChecklist.containsKey(s.checklistId)) {
      continue;
    }
    // As the diver chose: an item stored there meanwhile (another
    // device's) follows the section's items to where they went, or goes
    // with it; never into a section that is gone itself.
    final movedTo = current.itemsMovedOnDelete[s.id];
    await items.deleteSection(
      s.id,
      moveItemsToSectionId: isSection.containsKey(movedTo) ? movedTo : null,
    );
    wrote = true;
  }
  for (final c in loaded.checklists) {
    if (isChecklist.containsKey(c.id)) continue;
    await checklists.deleteChecklist(c.id);
    wrote = true;
  }
  // A new row was written at the end of what is stored; laying the list out
  // again puts each where the sitting has it. Only moved rows are written.
  if (_orderChanged(loaded.checklists, current.checklists, (c) => c.id)) {
    await checklists.reorderChecklists(tripId, [
      for (final c in current.checklists) c.id,
    ]);
    wrote = true;
  }
  for (final c in current.checklists) {
    final was = loaded.sectionsOf(c.id);
    final now = current.sectionsOf(c.id);
    if (_orderChanged(was, now, (s) => s.id)) {
      await items.reorderSections(c.id, [for (final s in now) s.id]);
      wrote = true;
    }
  }
  return wrote;
}

/// Whether [now] (by id) is laid out other than storage will have it once
/// the rows the sitting made are written: those of [was] still there, in
/// their order, then the new ones at the end, as the writers add them.
bool _orderChanged<E>(List<E> was, List<E> now, String Function(E row) id) {
  final kept = {for (final r in now) id(r)};
  final before = {for (final r in was) id(r)};
  final expected = [
    for (final r in was)
      if (kept.contains(id(r))) id(r),
    for (final r in now)
      if (!before.contains(id(r))) id(r),
  ];
  return !listEquals(expected, [for (final r in now) id(r)]);
}

/// The checklists [session] holds, or null before they are read.
TripChecklistsHeld? heldChecklistsOf(
  EditSession<Trip> session,
  SittingList<Trip, TripChecklistsHeld> list,
) => list.current(session)?.singleOrNull;

/// The trip's checklist changes held in [session] through [list], written
/// at Save. Template reads go to [templates] when a template is applied.
class HeldTripChecklistWrites implements TripChecklistWrites {
  HeldTripChecklistWrites({
    required this.session,
    required this.list,
    required this.templates,
  });

  final EditSession<Trip> session;
  final SittingList<Trip, TripChecklistsHeld> list;
  final ChecklistTemplateRepository templates;

  @override
  Trip get trip => session.working;

  TripChecklistsHeld get _held =>
      heldChecklistsOf(session, list) ?? const TripChecklistsHeld();

  void _set(TripChecklistsHeld next) => list.set(session, [next]);

  @override
  Future<TripChecklist> createChecklist(String name) async {
    final now = clock.now();
    final checklist = TripChecklist(
      id: _uuid.v4(),
      tripId: session.stored.id,
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    _set(_held.withChecklist(checklist));
    return checklist;
  }

  /// The rows template [templateId] adds to [checklistId] as [held] has it,
  /// dated from the trip's working start (dates moved in the sitting
  /// count).
  Future<ChecklistTemplateRows> _rows(
    String templateId,
    String checklistId,
    TripChecklistsHeld held,
  ) async {
    final template = await templates.getTemplateById(templateId);
    if (template == null) {
      throw StateError('Checklist template $templateId no longer exists');
    }
    return checklistRowsFromTemplate(
      templateItems: await templates.getItemsForTemplate(templateId),
      templateSections: await templates.getSectionsForTemplate(templateId),
      checklistId: checklistId,
      tripStart: session.working.startDate,
      existingItems: held.itemsOf(checklistId),
      existingSections: held.sectionsOf(checklistId),
      newId: _uuid.v4,
      now: clock.now(),
    );
  }

  @override
  Future<({int added, int skipped})> applyTemplate({
    required String templateId,
    required String checklistId,
  }) async {
    final rows = await _rows(templateId, checklistId, _held);
    _set(_held.withRows(rows));
    return (added: rows.added, skipped: rows.skipped);
  }

  @override
  Future<({int added, int skipped})> replaceWithTemplate({
    required String templateId,
    required String checklistId,
  }) async {
    final emptied = _held.withContentCleared(checklistId);
    final rows = await _rows(templateId, checklistId, emptied);
    _set(_held.withContentCleared(checklistId).withRows(rows));
    return (added: rows.added, skipped: rows.skipped);
  }

  @override
  Future<bool> isChecklistEmpty(String checklistId) async =>
      _held.itemsOf(checklistId).isEmpty &&
      _held.sectionsOf(checklistId).isEmpty;

  @override
  Future<void> renameChecklist(String id, String name) async =>
      _set(_held.withChecklistRenamed(id, name));

  @override
  Future<void> reorderChecklists(List<String> orderedIds) async =>
      _set(_held.withChecklistsReordered(orderedIds));

  @override
  Future<void> deleteChecklist(String id) async =>
      _set(_held.withoutChecklist(id));

  @override
  Future<void> clearItems(String checklistId) async =>
      _set(_held.withItemsCleared(checklistId));

  @override
  Future<void> createItem(TripChecklistItem item) async => _set(
    _held.withItem(item.id.isEmpty ? item.copyWith(id: _uuid.v4()) : item),
  );

  @override
  Future<void> updateItem(TripChecklistItem item) async =>
      _set(_held.withItem(item));

  @override
  Future<void> deleteItem(String id) async => _set(_held.withoutItem(id));

  @override
  Future<void> toggleDone(String id, {required bool isDone}) async =>
      _set(_held.withItemDone(id, isDone: isDone, at: clock.now()));

  @override
  Future<String?> findOrCreateSectionId(
    String checklistId,
    String? title,
  ) async {
    final trimmed = title?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final held = _held;
    final matched = matchSectionByTitle(trimmed, held.sectionsOf(checklistId));
    if (matched != null) return matched;
    final section = _section(checklistId, trimmed);
    _set(held.withSection(section));
    return section.id;
  }

  TripChecklistSection _section(String checklistId, String title) {
    final now = clock.now();
    return TripChecklistSection(
      id: _uuid.v4(),
      checklistId: checklistId,
      title: title,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<void> createSection({
    required String checklistId,
    required String title,
  }) async => _set(_held.withSection(_section(checklistId, title)));

  @override
  Future<void> renameSection(String id, String title) async =>
      _set(_held.withSectionRenamed(id, title));

  @override
  Future<void> reorderSections(
    String checklistId,
    List<String> orderedIds,
  ) async => _set(_held.withSectionsReordered(checklistId, orderedIds));

  @override
  Future<void> deleteSection(String id, {String? moveItemsToSectionId}) async =>
      _set(
        _held.withoutSection(id, moveItemsToSectionId: moveItemsToSectionId),
      );

  @override
  Future<void> moveItem({
    required String checklistId,
    required String itemId,
    required String? targetSectionId,
    required List<String> orderedIds,
  }) async => _set(
    _held.withItemMoved(
      checklistId: checklistId,
      itemId: itemId,
      targetSectionId: targetSectionId,
      orderedIds: orderedIds,
    ),
  );
}
