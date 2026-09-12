import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';

/// What a dives only UDDF export needs beyond the dives themselves.
///
/// The dives already carry their gear; participants and assembly rows are
/// not hydrated on them, so they travel here.
class UddfDivesExtras {
  /// Each exported dive's participants with their roles, by dive id.
  final Map<String, List<BuddyWithRole>> diveBuddies;

  /// Assembly template rows. The export keeps those whose parent and
  /// component are both on an exported dive.
  final List<EquipmentComponent> components;

  const UddfDivesExtras({
    this.diveBuddies = const {},
    this.components = const [],
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
  return (diveIds, options) => resolveDivesExtras(
    ref.read(buddyRepositoryProvider),
    ref.read(equipmentComponentRepositoryProvider),
    diveIds,
    options,
  );
});

/// Loads the extras for [diveIds], skipping any query whose checkbox in
/// [options] is off: a share without participants or gear must not pay for
/// reads it will not use.
Future<UddfDivesExtras> resolveDivesExtras(
  BuddyRepository buddies,
  EquipmentComponentRepository components,
  List<String> diveIds,
  UddfExportOptions options,
) async => UddfDivesExtras(
  // The lean list-view load leaves certifications out, and every <buddy>
  // declaration carries one, so this path reads them too.
  diveBuddies: options.includeParticipants
      ? await buddies.getBuddiesForDivesWithCertifications(diveIds)
      : const {},
  components: options.includeGear
      ? await components.getAllComponents()
      : const [],
);
