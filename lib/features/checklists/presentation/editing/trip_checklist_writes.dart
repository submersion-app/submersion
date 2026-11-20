import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklists_repository.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

/// What the trip's checklist widgets change, and where it goes: straight to
/// the repositories ([RepositoryTripChecklistWrites]), or into a trip page's
/// editing sitting, to be written at Save (issue #4527, phase 3).
abstract interface class TripChecklistWrites {
  /// The trip the checklists are written for, as the changes see it: the
  /// stored trip, or a sitting's working one (dates moved in it count).
  Trip get trip;

  /// Adds an empty checklist named [name] at the end of the trip's.
  Future<TripChecklist> createChecklist(String name);

  /// Copies template [templateId]'s items into [checklistId]. Throws
  /// [StateError] when the template no longer exists.
  Future<({int added, int skipped})> applyTemplate({
    required String templateId,
    required String checklistId,
  });

  /// Swaps [checklistId]'s items and sections for template [templateId]'s.
  /// Throws [StateError] when the template no longer exists.
  Future<({int added, int skipped})> replaceWithTemplate({
    required String templateId,
    required String checklistId,
  });

  /// Whether [checklistId] has no items and no sections.
  Future<bool> isChecklistEmpty(String checklistId);

  Future<void> renameChecklist(String id, String name);

  /// [orderedIds] lists every checklist of the trip once, in its new order.
  Future<void> reorderChecklists(List<String> orderedIds);

  /// Deletes the checklist with its sections and items.
  Future<void> deleteChecklist(String id);

  /// Drops the checklist's items and keeps its sections.
  Future<void> clearItems(String checklistId);

  /// Adds [item] at the end of its checklist.
  Future<void> createItem(TripChecklistItem item);

  Future<void> updateItem(TripChecklistItem item);

  Future<void> deleteItem(String id);

  Future<void> toggleDone(String id, {required bool isDone});

  /// The section of [checklistId] titled [title] (case-insensitively), made
  /// when there is none; null for a blank title.
  Future<String?> findOrCreateSectionId(String checklistId, String? title);

  Future<void> createSection({
    required String checklistId,
    required String title,
  });

  Future<void> renameSection(String id, String title);

  Future<void> reorderSections(String checklistId, List<String> orderedIds);

  /// Deletes a section, moving its items to [moveItemsToSectionId] or
  /// deleting them with it.
  Future<void> deleteSection(String id, {String? moveItemsToSectionId});

  /// Moves [itemId] to [targetSectionId] (null for none) and lays the
  /// checklist's items out in [orderedIds]' order.
  Future<void> moveItem({
    required String checklistId,
    required String itemId,
    required String? targetSectionId,
    required List<String> orderedIds,
  });
}

/// Writes each change at once, through the checklist repositories, as the
/// trip's checklists always have.
class RepositoryTripChecklistWrites implements TripChecklistWrites {
  RepositoryTripChecklistWrites({
    required this.trip,
    required this.checklists,
    required this.items,
  });

  @override
  final Trip trip;
  final TripChecklistsRepository checklists;
  final TripChecklistRepository items;

  @override
  Future<TripChecklist> createChecklist(String name) =>
      checklists.createChecklist(tripId: trip.id, name: name);

  @override
  Future<({int added, int skipped})> applyTemplate({
    required String templateId,
    required String checklistId,
  }) => items.applyTemplate(
    templateId: templateId,
    checklistId: checklistId,
    trip: trip,
  );

  @override
  Future<({int added, int skipped})> replaceWithTemplate({
    required String templateId,
    required String checklistId,
  }) => items.replaceWithTemplate(
    templateId: templateId,
    checklistId: checklistId,
    trip: trip,
  );

  @override
  Future<bool> isChecklistEmpty(String checklistId) async =>
      (await items.getByChecklistId(checklistId)).isEmpty &&
      (await items.getSectionsForChecklist(checklistId)).isEmpty;

  @override
  Future<void> renameChecklist(String id, String name) =>
      checklists.renameChecklist(id, name);

  @override
  Future<void> reorderChecklists(List<String> orderedIds) =>
      checklists.reorderChecklists(trip.id, orderedIds);

  @override
  Future<void> deleteChecklist(String id) => checklists.deleteChecklist(id);

  @override
  Future<void> clearItems(String checklistId) => items.clearItems(checklistId);

  @override
  Future<void> createItem(TripChecklistItem item) => items.createItem(item);

  @override
  Future<void> updateItem(TripChecklistItem item) => items.updateItem(item);

  @override
  Future<void> deleteItem(String id) => items.deleteItem(id);

  @override
  Future<void> toggleDone(String id, {required bool isDone}) =>
      items.toggleDone(id, isDone: isDone);

  @override
  Future<String?> findOrCreateSectionId(String checklistId, String? title) =>
      items.findOrCreateSectionId(checklistId, title);

  @override
  Future<void> createSection({
    required String checklistId,
    required String title,
  }) => items.createSection(checklistId: checklistId, title: title);

  @override
  Future<void> renameSection(String id, String title) =>
      items.renameSection(id, title);

  @override
  Future<void> reorderSections(String checklistId, List<String> orderedIds) =>
      items.reorderSections(checklistId, orderedIds);

  @override
  Future<void> deleteSection(String id, {String? moveItemsToSectionId}) =>
      items.deleteSection(id, moveItemsToSectionId: moveItemsToSectionId);

  @override
  Future<void> moveItem({
    required String checklistId,
    required String itemId,
    required String? targetSectionId,
    required List<String> orderedIds,
  }) => items.moveItem(
    checklistId: checklistId,
    itemId: itemId,
    targetSectionId: targetSectionId,
    orderedIds: orderedIds,
  );
}
