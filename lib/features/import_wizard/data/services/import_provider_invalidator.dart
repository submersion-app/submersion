import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';

/// Invalidates the Riverpod providers that correspond to the given set of
/// imported entity types.
///
/// Pass [ref] from the calling notifier or widget. At call sites:
///
/// ```dart
/// invalidateImportRelatedProviders(ref, importedTypes);
/// ```
///
/// Call this after a successful import to ensure all affected UI providers
/// refresh their data from the database.
void invalidateImportRelatedProviders(
  Ref ref,
  Set<ImportEntityType> importedTypes,
) {
  if (importedTypes.isEmpty) return;

  for (final type in importedTypes) {
    switch (type) {
      case ImportEntityType.dives:
        ref.invalidate(diveListNotifierProvider);
        ref.invalidate(paginatedDiveListProvider);
        // Dive computer records may be updated when dives are imported.
        ref.invalidate(allDiveComputersProvider);

      case ImportEntityType.sites:
        ref.invalidate(sitesProvider);
        ref.invalidate(sitesWithCountsProvider);
        ref.invalidate(siteListNotifierProvider);

      case ImportEntityType.buddies:
        ref.invalidate(allBuddiesProvider);

      case ImportEntityType.equipment:
        ref.invalidate(allEquipmentProvider);
        ref.invalidate(activeEquipmentProvider);
        ref.invalidate(retiredEquipmentProvider);
        ref.invalidate(serviceDueEquipmentProvider);
        ref.invalidate(equipmentListNotifierProvider);

      case ImportEntityType.equipmentSets:
        ref.invalidate(equipmentSetsProvider);

      case ImportEntityType.trips:
        ref.invalidate(allTripsProvider);

      case ImportEntityType.diveCenters:
        ref.invalidate(allDiveCentersProvider);

      case ImportEntityType.certifications:
        ref.invalidate(allCertificationsProvider);

      case ImportEntityType.courses:
        ref.invalidate(allCoursesProvider);

      case ImportEntityType.tags:
        ref.invalidate(tagsProvider);

      case ImportEntityType.diveTypes:
        ref.invalidate(diveTypesProvider);
    }
  }
}
