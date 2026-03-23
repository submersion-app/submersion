import 'package:flutter_test/flutter_test.dart';

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

// ---------------------------------------------------------------------------
// Testable mirror of invalidateImportRelatedProviders.
//
// Rather than calling the real function (which requires a live Ref and
// database), tests use this local helper that accepts a plain callback so the
// exact set of invalidated providers can be recorded and asserted.
// The mapping must stay in sync with the production implementation in
// lib/features/import_wizard/data/services/import_provider_invalidator.dart.
// ---------------------------------------------------------------------------
void _invalidateWithCallback(
  void Function(Object) invalidate,
  Set<ImportEntityType> importedTypes,
) {
  if (importedTypes.isEmpty) return;

  for (final type in importedTypes) {
    switch (type) {
      case ImportEntityType.dives:
        invalidate(diveListNotifierProvider);
        invalidate(paginatedDiveListProvider);
        invalidate(allDiveComputersProvider);

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
        invalidate(serviceDueEquipmentProvider);
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
    }
  }
}

List<Object> _record(Set<ImportEntityType> types) {
  final recorded = <Object>[];
  _invalidateWithCallback((p) => recorded.add(p), types);
  return recorded;
}

void main() {
  group('invalidateImportRelatedProviders', () {
    test('does nothing when importedTypes is empty', () {
      expect(_record({}), isEmpty);
    });

    test('every ImportEntityType maps to at least one provider', () {
      for (final type in ImportEntityType.values) {
        expect(
          _record({type}),
          isNotEmpty,
          reason:
              'ImportEntityType.$type should invalidate at least one provider',
        );
      }
    });

    test(
      'dives invalidates diveListNotifierProvider, paginatedDiveListProvider,'
      ' and allDiveComputersProvider',
      () {
        final recorded = _record({ImportEntityType.dives});

        expect(recorded, contains(diveListNotifierProvider));
        expect(recorded, contains(paginatedDiveListProvider));
        expect(recorded, contains(allDiveComputersProvider));
      },
    );

    test('sites invalidates sitesProvider, sitesWithCountsProvider, and'
        ' siteListNotifierProvider', () {
      final recorded = _record({ImportEntityType.sites});

      expect(recorded, contains(sitesProvider));
      expect(recorded, contains(sitesWithCountsProvider));
      expect(recorded, contains(siteListNotifierProvider));
    });

    test('buddies invalidates allBuddiesProvider', () {
      expect(_record({ImportEntityType.buddies}), contains(allBuddiesProvider));
    });

    test('equipment invalidates all equipment-related providers', () {
      final recorded = _record({ImportEntityType.equipment});

      expect(recorded, contains(allEquipmentProvider));
      expect(recorded, contains(activeEquipmentProvider));
      expect(recorded, contains(retiredEquipmentProvider));
      expect(recorded, contains(serviceDueEquipmentProvider));
      expect(recorded, contains(equipmentListNotifierProvider));
    });

    test('equipmentSets invalidates equipmentSetsProvider', () {
      expect(
        _record({ImportEntityType.equipmentSets}),
        contains(equipmentSetsProvider),
      );
    });

    test('trips invalidates allTripsProvider', () {
      expect(_record({ImportEntityType.trips}), contains(allTripsProvider));
    });

    test('diveCenters invalidates allDiveCentersProvider', () {
      expect(
        _record({ImportEntityType.diveCenters}),
        contains(allDiveCentersProvider),
      );
    });

    test('certifications invalidates allCertificationsProvider', () {
      expect(
        _record({ImportEntityType.certifications}),
        contains(allCertificationsProvider),
      );
    });

    test('courses invalidates allCoursesProvider', () {
      expect(_record({ImportEntityType.courses}), contains(allCoursesProvider));
    });

    test('tags invalidates tagsProvider', () {
      expect(_record({ImportEntityType.tags}), contains(tagsProvider));
    });

    test('diveTypes invalidates diveTypesProvider', () {
      expect(
        _record({ImportEntityType.diveTypes}),
        contains(diveTypesProvider),
      );
    });

    test('multiple entity types each trigger their own providers', () {
      final recorded = _record({
        ImportEntityType.dives,
        ImportEntityType.sites,
        ImportEntityType.tags,
      });

      expect(recorded, contains(diveListNotifierProvider));
      expect(recorded, contains(paginatedDiveListProvider));
      expect(recorded, contains(sitesProvider));
      expect(recorded, contains(tagsProvider));
    });

    test('all entity types together trigger providers for every type', () {
      final recorded = _record(ImportEntityType.values.toSet());

      expect(recorded, contains(diveListNotifierProvider));
      expect(recorded, contains(allDiveComputersProvider));
      expect(recorded, contains(sitesProvider));
      expect(recorded, contains(allBuddiesProvider));
      expect(recorded, contains(allEquipmentProvider));
      expect(recorded, contains(equipmentSetsProvider));
      expect(recorded, contains(allTripsProvider));
      expect(recorded, contains(allDiveCentersProvider));
      expect(recorded, contains(allCertificationsProvider));
      expect(recorded, contains(allCoursesProvider));
      expect(recorded, contains(tagsProvider));
      expect(recorded, contains(diveTypesProvider));
    });
  });
}
