import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_node.dart';
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
///   view, every status at once, the computed service-due list, or one
///   [EquipmentStatus]. Those are mutually exclusive because the list can
///   only read one source.
/// - Type narrows the result client-side, so status and category compose with
///   AND semantics.
/// - Attribute conditions (#1805) narrow the selected category by its choice
///   fields, client-side, ANDed. They belong to the category.
/// - Tags (issue #1942) narrow client-side too: an item matches when it
///   carries any selected tag. Tags are not on the entity, so [apply] takes
///   the list's batch map of tag ids per item.
/// Whose gear the list shows (issue #2046). Only offered with two or more
/// profiles.
enum EquipmentOwnerFilter { all, mine, sharedWithMe }

@immutable
class EquipmentFilterState {
  /// The status to show, or null for the default view. The default hides
  /// retired gear; the Retired status is the way to see it (#636).
  final EquipmentStatus? status;

  /// Show gear of every status, retired and sold included (issue #2590),
  /// instead of the default view. Mutually exclusive with [status] and
  /// [serviceDue].
  final bool allStatuses;

  /// Show only gear with a service clock due, optionally narrowed to one
  /// severity. Null means the status axis is not a service-due view; which
  /// statuses show is then [status] or [allStatuses]. Mutually exclusive
  /// with both.
  final ServiceDueFilter? serviceDue;

  /// Narrow to a single gear category, or null for every category.
  final EquipmentType? type;

  /// Choice conditions on [type]'s curated fields, ANDed. Changing or
  /// clearing the category through [copyWith] drops them.
  final List<EquipmentAttrCondition> attrConditions;

  /// Tag ids, any-of (issue #1942). Empty means no tag narrowing.
  final Set<String> tagIds;

  /// Current places by name, any-of and ignoring case (v268), so the panel
  /// and a typed query agree. Empty means no place narrowing.
  final Set<String> locationNames;

  /// Include gear with no current location, ORed with [locationNames].
  final bool noLocation;

  /// Whose gear to show (issue #2046). [EquipmentOwnerFilter.all] narrows
  /// nothing.
  final EquipmentOwnerFilter owner;

  /// The advanced part (#2365): a typed or built query, ANDed with every
  /// axis above by `EquipmentFilterQuery.toQuery`.
  final QueryNode? query;

  const EquipmentFilterState({
    this.status,
    this.allStatuses = false,
    this.serviceDue,
    this.type,
    this.attrConditions = const [],
    this.tagIds = const {},
    this.locationNames = const {},
    this.noLocation = false,
    this.owner = EquipmentOwnerFilter.all,
    this.query,
  }) : assert(
         !(serviceDue != null && status != null),
         'The status axis is a single choice: service due or a status, never '
         'both -- the list reads one provider.',
       ),
       assert(
         !(allStatuses && (status != null || serviceDue != null)),
         'The status axis is a single choice: every status, service due or '
         'one status, never two of them.',
       );

  /// Whether the panel is narrowing anything, i.e. whether the top-bar icon
  /// should carry its badge.
  bool get hasActiveFilters =>
      hasStatusFilter ||
      type != null ||
      attrConditions.isNotEmpty ||
      tagIds.isNotEmpty ||
      locationNames.isNotEmpty ||
      noLocation ||
      owner != EquipmentOwnerFilter.all ||
      query != null;

  /// Whether the status axis is anything other than the default view.
  bool get hasStatusFilter =>
      allStatuses || status != null || serviceDue != null;

  /// Copy with per-axis clearing. Clearing the status axis resets all of its
  /// values, since they are one choice to the diver; for the same reason a
  /// status or severity turns [allStatuses] off, and [allStatuses] turns
  /// them off. A new or cleared
  /// category drops the attribute conditions unless new ones are given,
  /// because they belong to the category.
  EquipmentFilterState copyWith({
    EquipmentStatus? status,
    bool? allStatuses,
    ServiceDueFilter? serviceDue,
    EquipmentType? type,
    List<EquipmentAttrCondition>? attrConditions,
    Set<String>? tagIds,
    Set<String>? locationNames,
    bool? noLocation,
    EquipmentOwnerFilter? owner,
    QueryNode? query,
    bool clearStatus = false,
    bool clearType = false,
    bool clearAttrConditions = false,
    bool clearTagIds = false,
    bool clearLocation = false,
    bool clearQuery = false,
  }) {
    final nextType = clearType ? null : (type ?? this.type);
    final categoryChanged = nextType != this.type;
    final nextAll =
        !clearStatus &&
        (allStatuses ??
            (status == null && serviceDue == null && this.allStatuses));
    return EquipmentFilterState(
      status: clearStatus || nextAll ? null : (status ?? this.status),
      allStatuses: nextAll,
      serviceDue: clearStatus || nextAll
          ? null
          : (serviceDue ?? this.serviceDue),
      type: nextType,
      attrConditions: clearAttrConditions
          ? const []
          : (attrConditions ??
                (categoryChanged ? const [] : this.attrConditions)),
      // Tags do not belong to the category, so a new one keeps them.
      tagIds: clearTagIds ? const {} : (tagIds ?? this.tagIds),
      locationNames: clearLocation
          ? const {}
          : (locationNames ?? this.locationNames),
      noLocation: !clearLocation && (noLocation ?? this.noLocation),
      owner: owner ?? this.owner,
      query: clearQuery ? null : (query ?? this.query),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EquipmentFilterState &&
          other.status == status &&
          other.allStatuses == allStatuses &&
          other.serviceDue == serviceDue &&
          other.type == type &&
          listEquals(other.attrConditions, attrConditions) &&
          setEquals(other.tagIds, tagIds) &&
          setEquals(other.locationNames, locationNames) &&
          other.noLocation == noLocation &&
          other.owner == owner &&
          other.query == query;

  @override
  int get hashCode => Object.hash(
    status,
    allStatuses,
    serviceDue,
    type,
    Object.hashAll(attrConditions),
    Object.hashAllUnordered(tagIds),
    Object.hashAllUnordered(locationNames),
    noLocation,
    owner,
    query,
  );

  @override
  String toString() =>
      'EquipmentFilterState(status: $status, allStatuses: $allStatuses, '
      'serviceDue: $serviceDue, '
      'type: $type, attrConditions: $attrConditions, tagIds: $tagIds, '
      'locationNames: $locationNames, noLocation: $noLocation, '
      'owner: $owner, query: $query)';
}
