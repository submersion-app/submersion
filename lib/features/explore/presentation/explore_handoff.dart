import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_query_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_query_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_query_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// Writes [node] as [subject]'s list query and returns the list's route.
/// The list's other axes start clear, so its chips show exactly what the
/// sentence asked for (#2773; Explore's handoff, shared by Ask).
String writeSubjectHandoff(Ref ref, ParsedSubject subject, QueryNode node) {
  switch (subject) {
    case ParsedSubject.sites:
      ref.read(siteFilterProvider.notifier).state = SiteFilterState(
        query: node,
      );
      return '/sites';
    case ParsedSubject.equipment:
      ref.read(equipmentFilterProvider.notifier).state = exploreEquipmentFilter(
        node,
      );
      return '/equipment';
    case ParsedSubject.buddies:
      ref.read(buddyQueryProvider.notifier).state = node;
      return '/buddies';
    case ParsedSubject.species:
      ref.read(seenSpeciesQueryProvider.notifier).state = node;
      return '/species';
    case ParsedSubject.trips:
      ref.read(tripFilterProvider.notifier).state = TripFilterState(
        query: node,
      );
      return '/trips';
    case ParsedSubject.centers:
      ref.read(diveCenterQueryProvider.notifier).state = node;
      return '/dive-centers';
    case ParsedSubject.dives:
      throw StateError('a dive sentence replaces the dive query instead');
  }
}

/// The equipment list's filter for an Explore query. The list's unset
/// status hides retired and sold gear, so a status the sentence names
/// ("my retired regulators") becomes that axis, lifted out of the query,
/// rather than contradicting it. A negated status, or several, stays in the
/// query and reads every status (#2590), as does a query on the active flag:
/// under the default view "retired or sold gear" would find nothing.
EquipmentFilterState exploreEquipmentFilter(QueryNode? node) {
  EquipmentStatus? named(QueryNode n) {
    if (n is! ConditionNode || n.op != QueryOp.inList) return null;
    if (n.path != FieldPath(const ['status'])) return null;
    final v = n.value;
    if (v is! ListValue || v.items.length != 1) return null;
    final item = v.items.single;
    if (item is! EnumValue) return null;
    return EquipmentStatus.values.where((s) => s.name == item.name).firstOrNull;
  }

  final parts = switch (node) {
    null => const <QueryNode>[],
    AndNode(:final children) => children,
    _ => [node],
  };
  for (final part in parts) {
    final status = named(part);
    if (status == null) continue;
    final rest = [
      for (final p in parts)
        if (!identical(p, part)) p,
    ];
    return EquipmentFilterState(
      status: status,
      query: switch (rest) {
        [] => null,
        [final only] => only,
        _ => AndNode(rest),
      },
    );
  }
  return EquipmentFilterState(
    allStatuses: node != null && _namesStatus(node),
    query: node,
  );
}

/// Whether [node] tests the equipment's own status, or the legacy active
/// flag the default view also pins, anywhere. A scoped condition reads
/// another entity's fields, so it is not looked into.
bool _namesStatus(QueryNode node) => switch (node) {
  AndNode(:final children) ||
  OrNode(:final children) => children.any(_namesStatus),
  NotNode(:final child) => _namesStatus(child),
  ConditionNode(:final path) =>
    path == FieldPath(const ['status']) || path == FieldPath(const ['active']),
  ScopedNode() || TextNode() => false,
};
