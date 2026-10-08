import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
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
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

/// Invalidates the Riverpod providers that correspond to the given set of
/// imported entity types.
///
/// Takes the invalidator as a callback rather than a `Ref` so the one mapping
/// serves both a notifier's `Ref` and a widget's `WidgetRef`, which share no
/// supertype, and so tests can record the exact set of providers without
/// standing up a container.
///
/// The callback parameter is `dynamic` because Riverpod 3 does not export
/// `ProviderOrFamily`, the type `invalidate` accepts, so it cannot be named
/// here. Call sites forward through a lambda:
///
/// ```dart
/// invalidateImportRelatedProviders((p) => ref.invalidate(p), importedTypes);
/// ```
///
/// Call this after a successful import to ensure all affected UI providers
/// refresh their data from the database.
void invalidateImportRelatedProviders(
  void Function(dynamic provider) invalidate,
  Set<ImportEntityType> importedTypes,
) {
  if (importedTypes.isEmpty) return;

  for (final type in importedTypes) {
    switch (type) {
      case ImportEntityType.dives:
        invalidate(diveListNotifierProvider);
        invalidate(paginatedDiveListProvider);
        invalidate(divesProvider);
        invalidate(diveStatisticsProvider);
        invalidate(diveRecordsProvider);
        invalidate(nextDiveNumberProvider);
        // Dive computer records may be updated when dives are imported.
        invalidate(allDiveComputersProvider);
        // Dives link to sites, buddies, trips and so on, so their counts and
        // lists can change even when those entities were not imported.
        invalidate(sitesWithCountsProvider);
        invalidate(siteListNotifierProvider);

      case ImportEntityType.sites:
        invalidate(sitesProvider);
        invalidate(sitesWithCountsProvider);
        invalidate(siteListNotifierProvider);

      case ImportEntityType.buddies:
        invalidate(allBuddiesProvider);

      case ImportEntityType.equipment:
        invalidate(allEquipmentProvider);
        invalidate(activeEquipmentProvider);
        invalidate(retiredEquipmentProvider);
        // Base clock evaluation: the service-due list derives from it.
        invalidate(activeEquipmentClocksProvider);
        invalidate(equipmentListNotifierProvider);

      case ImportEntityType.equipmentSets:
        invalidate(equipmentSetsProvider);

      case ImportEntityType.trips:
        invalidate(allTripsProvider);

      case ImportEntityType.diveCenters:
        invalidate(allDiveCentersProvider);

      case ImportEntityType.certifications:
        invalidate(allCertificationsProvider);

      case ImportEntityType.courses:
        invalidate(allCoursesProvider);

      case ImportEntityType.tags:
        invalidate(tagsProvider);

      case ImportEntityType.diveTypes:
        invalidate(diveTypesProvider);

      case ImportEntityType.media:
        // Photos land on dives that may already be on screen.
        invalidate(mediaForDiveProvider);
        invalidate(mediaCountForDiveProvider);
        invalidate(mediaListNotifierProvider);

      case ImportEntityType.fills:
        // A passport page may be showing the cylinder the fills landed on.
        invalidate(fillsForEquipmentProvider);
        invalidate(newestFillProvider);
    }
  }
}
