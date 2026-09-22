import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';

/// Which service clocks the list narrows to.
///
/// The severities exist so the home strip's two consolidated service chips
/// have an honest destination each: a chip that counted the overdue items
/// has to land on a list of exactly those, not on the combined due list.
/// [any] is the diver-facing Service Due filter that predates them.
enum ServiceDueFilter {
  /// Overdue or due soon: everything with a clock that is not ok.
  any,

  /// Items whose worst clock has lapsed.
  overdue,

  /// Items due for service soon, excluding anything already overdue.
  dueSoon,
}

/// Filter state for the equipment list, shared by the phone, master-detail and
/// table layouts and edited through the filter panel.
///
/// Four axes:
///
/// - Status decides which provider the list reads: the default active-gear
///   view, the computed service-due list, or one [EquipmentStatus]. Those are
///   mutually exclusive because the list can only read one source.
/// - Type narrows the result client-side, so status and category compose with
///   AND semantics.
/// - Attribute conditions (#1805) narrow the selected category by its choice
///   fields, client-side, ANDed. They belong to the category.
/// - Tags (issue #1942) narrow client-side too: an item matches when it
///   carries any selected tag. Tags are not on the entity, so [apply] takes
///   the list's batch map of tag ids per item.
@immutable
class EquipmentFilterState {
  /// The status to show, or null for the default view. The default hides
  /// retired gear; the Retired status is the way to see it (#636).
  final EquipmentStatus? status;

  /// Show only gear with a service clock due, optionally narrowed to one
  /// severity. Null shows every status. Mutually exclusive with [status].
  final ServiceDueFilter? serviceDue;

  /// Narrow to a single gear category, or null for every category.
  final EquipmentType? type;

  /// Choice conditions on [type]'s curated fields, ANDed. Changing or
  /// clearing the category through [copyWith] drops them.
  final List<EquipmentAttrCondition> attrConditions;

  /// Tag ids, any-of (issue #1942). Empty means no tag narrowing.
  final Set<String> tagIds;

  const EquipmentFilterState({
    this.status,
    this.serviceDue,
    this.type,
    this.attrConditions = const [],
    this.tagIds = const {},
  }) : assert(
         !(serviceDue != null && status != null),
         'The status axis is a single choice: service due or a status, never '
         'both -- the list reads one provider.',
       );

  /// Whether the panel is narrowing anything, i.e. whether the top-bar icon
  /// should carry its badge.
  bool get hasActiveFilters =>
      hasStatusFilter ||
      type != null ||
      attrConditions.isNotEmpty ||
      tagIds.isNotEmpty;

  /// Whether the status axis is anything other than the default view.
  bool get hasStatusFilter => status != null || serviceDue != null;

  /// Narrow [equipment] to the selected category, its conditions and the
  /// selected tags. [tagIdsByEquipment] is each item's tag ids, keyed by
  /// item id (an item with no entry has no tags).
  ///
  /// The status axis is applied upstream by provider selection, so this is the
  /// only filtering the list itself has to do.
  List<EquipmentItem> apply(
    List<EquipmentItem> equipment,
    Map<String, Iterable<String>> tagIdsByEquipment,
  ) {
    final selected = type;
    if (selected == null && attrConditions.isEmpty && tagIds.isEmpty) {
      return equipment;
    }
    return equipment
        .where(
          (e) =>
              (selected == null || e.type == selected) &&
              attrConditions.every((c) => c.matches(e)) &&
              (tagIds.isEmpty ||
                  (tagIdsByEquipment[e.id] ?? const <String>[]).any(
                    tagIds.contains,
                  )),
        )
        .toList();
  }

  /// Whether the tag selection is what emptied [equipment]: some item passes
  /// the category and its conditions, but none of those carries a selected
  /// tag. The empty state blames the axis that did the emptying.
  bool tagsEmptied(
    List<EquipmentItem> equipment,
    Map<String, Iterable<String>> tagIdsByEquipment,
  ) =>
      tagIds.isNotEmpty &&
      apply(equipment, tagIdsByEquipment).isEmpty &&
      copyWith(
        clearTagIds: true,
      ).apply(equipment, tagIdsByEquipment).isNotEmpty;

  /// Copy with per-axis clearing. Clearing the status axis resets both of its
  /// values, since they are one choice to the diver. A new or cleared
  /// category drops the attribute conditions unless new ones are given,
  /// because they belong to the category.
  EquipmentFilterState copyWith({
    EquipmentStatus? status,
    ServiceDueFilter? serviceDue,
    EquipmentType? type,
    List<EquipmentAttrCondition>? attrConditions,
    Set<String>? tagIds,
    bool clearStatus = false,
    bool clearType = false,
    bool clearAttrConditions = false,
    bool clearTagIds = false,
  }) {
    final nextType = clearType ? null : (type ?? this.type);
    final categoryChanged = nextType != this.type;
    return EquipmentFilterState(
      status: clearStatus ? null : (status ?? this.status),
      serviceDue: clearStatus ? null : (serviceDue ?? this.serviceDue),
      type: nextType,
      attrConditions: clearAttrConditions
          ? const []
          : (attrConditions ??
                (categoryChanged ? const [] : this.attrConditions)),
      // Tags do not belong to the category, so a new one keeps them.
      tagIds: clearTagIds ? const {} : (tagIds ?? this.tagIds),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EquipmentFilterState &&
          other.status == status &&
          other.serviceDue == serviceDue &&
          other.type == type &&
          listEquals(other.attrConditions, attrConditions) &&
          setEquals(other.tagIds, tagIds);

  @override
  int get hashCode => Object.hash(
    status,
    serviceDue,
    type,
    Object.hashAll(attrConditions),
    Object.hashAllUnordered(tagIds),
  );

  @override
  String toString() =>
      'EquipmentFilterState(status: $status, serviceDue: $serviceDue, '
      'type: $type, attrConditions: $attrConditions, tagIds: $tagIds)';
}
