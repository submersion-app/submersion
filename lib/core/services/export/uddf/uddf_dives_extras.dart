import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';

/// What a dives only UDDF export needs beyond the dives themselves.
///
/// The dives already carry their gear; participants, assembly rows and role
/// definitions are not hydrated on them, so they travel here.
class UddfDivesExtras {
  /// Each exported dive's participants with their roles, by dive id.
  final Map<String, List<BuddyWithRole>> diveBuddies;

  /// Assembly template rows between gear on the exported dives. The export
  /// filters them again against the items it declares.
  final List<EquipmentComponent> components;

  /// The exporting diver's own roles, built-ins included. The export
  /// declares a custom role only when this list holds it, so a role
  /// resolved as synthetic (an id with no row, or another diver's role) is
  /// never written out as a definition.
  final List<DiveRole> diveRoles;

  const UddfDivesExtras({
    this.diveBuddies = const {},
    this.components = const [],
    this.diveRoles = const [],
  });

  const UddfDivesExtras.empty() : this();
}

/// Fetches the [UddfDivesExtras] a dives only export needs for [diveIds].
typedef UddfDivesExtrasFetch =
    Future<UddfDivesExtras> Function(
      List<String> diveIds,
      UddfExportOptions options,
    );

/// The fetch every dives only export action uses.
///
/// A provider for the same reason as `uddfSourceFetchProvider`: the export
/// actions live in widgets whose tests have no database, and overriding
/// this is how such a test opts out.
final uddfDivesExtrasFetchProvider = Provider<UddfDivesExtrasFetch>((ref) {
  return (diveIds, options) async => resolveDivesExtras(
    ref.read(buddyRepositoryProvider),
    ref.read(equipmentComponentRepositoryProvider),
    ref.read(diveRoleRepositoryProvider),
    // The same diver `allDiveRolesProvider` scopes the role list to.
    await ref.read(validatedCurrentDiverIdProvider.future),
    diveIds,
    options,
  );
});

/// Loads the extras for [diveIds], skipping any query whose checkbox in
/// [options] is off: a share without participants or gear must not pay for
/// reads it will not use.
///
/// [diverId]'s roles are read whatever the checkboxes: every dive writes
/// its diver's own role, which is not a participant, so leaving
/// participants out must not leave a custom one undefined.
Future<UddfDivesExtras> resolveDivesExtras(
  BuddyRepository buddies,
  EquipmentComponentRepository components,
  DiveRoleRepository roles,
  String? diverId,
  List<String> diveIds,
  UddfExportOptions options,
) async => UddfDivesExtras(
  // The lean list-view load leaves certifications out, and every <buddy>
  // declaration carries one, so this path reads them too.
  diveBuddies: options.includeParticipants
      ? await buddies.getBuddiesForDivesWithCertifications(diveIds)
      : const {},
  components: options.includeGear
      ? await components.getComponentsForDives(diveIds)
      : const [],
  diveRoles: await roles.getAllDiveRoles(diverId: diverId),
);
