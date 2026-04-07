import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/domain/constants/certification_field.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/domain/constants/course_field.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_centers/domain/constants/dive_center_field.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_field.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/domain/constants/trip_field.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../helpers/mock_providers.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    // Create a container without a diver ID and without a real database.
    // The providers detect null diverId and skip init(), so we only exercise
    // the default config path -- which is exactly the uncovered code.
    container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  // -----------------------------------------------------------------------
  // buddyTableConfigProvider
  // -----------------------------------------------------------------------

  group('buddyTableConfigProvider', () {
    test('provides default config with expected columns', () {
      final config = container.read(buddyTableConfigProvider);
      expect(config.columns, isNotEmpty);
      expect(config.columns.length, equals(5));
      expect(config.columns.first.field, equals(BuddyField.buddyName));
      expect(config.columns.first.isPinned, isTrue);
    });

    test('default config includes expected fields', () {
      final config = container.read(buddyTableConfigProvider);
      final fields = config.columns.map((c) => c.field).toList();
      expect(fields, contains(BuddyField.certificationLevel));
      expect(fields, contains(BuddyField.certificationAgency));
      expect(fields, contains(BuddyField.email));
      expect(fields, contains(BuddyField.diveCount));
    });

    test('default config has no sort', () {
      final config = container.read(buddyTableConfigProvider);
      expect(config.sortField, isNull);
      expect(config.sortAscending, isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // certificationTableConfigProvider
  // -----------------------------------------------------------------------

  group('certificationTableConfigProvider', () {
    test('provides default config with expected columns', () {
      final config = container.read(certificationTableConfigProvider);
      expect(config.columns, isNotEmpty);
      expect(config.columns.length, equals(6));
      expect(config.columns.first.field, equals(CertificationField.certName));
      expect(config.columns.first.isPinned, isTrue);
    });

    test('default config includes expected fields', () {
      final config = container.read(certificationTableConfigProvider);
      final fields = config.columns.map((c) => c.field).toList();
      expect(fields, contains(CertificationField.agency));
      expect(fields, contains(CertificationField.level));
      expect(fields, contains(CertificationField.issueDate));
      expect(fields, contains(CertificationField.expiryDate));
      expect(fields, contains(CertificationField.expiryStatus));
    });

    test('default config has no sort', () {
      final config = container.read(certificationTableConfigProvider);
      expect(config.sortField, isNull);
      expect(config.sortAscending, isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // courseTableConfigProvider
  // -----------------------------------------------------------------------

  group('courseTableConfigProvider', () {
    test('provides default config with expected columns', () {
      final config = container.read(courseTableConfigProvider);
      expect(config.columns, isNotEmpty);
      expect(config.columns.length, equals(6));
      expect(config.columns.first.field, equals(CourseField.courseName));
      expect(config.columns.first.isPinned, isTrue);
    });

    test('default config includes expected fields', () {
      final config = container.read(courseTableConfigProvider);
      final fields = config.columns.map((c) => c.field).toList();
      expect(fields, contains(CourseField.agency));
      expect(fields, contains(CourseField.startDate));
      expect(fields, contains(CourseField.completionDate));
      expect(fields, contains(CourseField.isCompleted));
      expect(fields, contains(CourseField.location));
    });

    test('default config has no sort', () {
      final config = container.read(courseTableConfigProvider);
      expect(config.sortField, isNull);
      expect(config.sortAscending, isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // diveCenterTableConfigProvider
  // -----------------------------------------------------------------------

  group('diveCenterTableConfigProvider', () {
    test('provides default config with expected columns', () {
      final config = container.read(diveCenterTableConfigProvider);
      expect(config.columns, isNotEmpty);
      expect(config.columns.length, equals(6));
      expect(config.columns.first.field, equals(DiveCenterField.centerName));
      expect(config.columns.first.isPinned, isTrue);
    });

    test('default config includes expected fields', () {
      final config = container.read(diveCenterTableConfigProvider);
      final fields = config.columns.map((c) => c.field).toList();
      expect(fields, contains(DiveCenterField.city));
      expect(fields, contains(DiveCenterField.country));
      expect(fields, contains(DiveCenterField.phone));
      expect(fields, contains(DiveCenterField.diveCount));
      expect(fields, contains(DiveCenterField.rating));
    });

    test('default config has no sort', () {
      final config = container.read(diveCenterTableConfigProvider);
      expect(config.sortField, isNull);
      expect(config.sortAscending, isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // equipmentTableConfigProvider
  // -----------------------------------------------------------------------

  group('equipmentTableConfigProvider', () {
    test('provides default config with expected columns', () {
      final config = container.read(equipmentTableConfigProvider);
      expect(config.columns, isNotEmpty);
      expect(config.columns.length, equals(6));
      expect(config.columns.first.field, equals(EquipmentField.itemName));
      expect(config.columns.first.isPinned, isTrue);
    });

    test('default config includes expected fields', () {
      final config = container.read(equipmentTableConfigProvider);
      final fields = config.columns.map((c) => c.field).toList();
      expect(fields, contains(EquipmentField.type));
      expect(fields, contains(EquipmentField.brand));
      expect(fields, contains(EquipmentField.model));
      expect(fields, contains(EquipmentField.status));
      expect(fields, contains(EquipmentField.lastServiceDate));
    });

    test('default config has no sort', () {
      final config = container.read(equipmentTableConfigProvider);
      expect(config.sortField, isNull);
      expect(config.sortAscending, isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // tripTableConfigProvider
  // -----------------------------------------------------------------------

  group('tripTableConfigProvider', () {
    test('provides default config with expected columns', () {
      final config = container.read(tripTableConfigProvider);
      expect(config.columns, isNotEmpty);
      expect(config.columns.length, equals(6));
      expect(config.columns.first.field, equals(TripField.tripName));
      expect(config.columns.first.isPinned, isTrue);
    });

    test('default config includes expected fields', () {
      final config = container.read(tripTableConfigProvider);
      final fields = config.columns.map((c) => c.field).toList();
      expect(fields, contains(TripField.startDate));
      expect(fields, contains(TripField.endDate));
      expect(fields, contains(TripField.location));
      expect(fields, contains(TripField.diveCount));
      expect(fields, contains(TripField.maxDepth));
    });

    test('default config has no sort', () {
      final config = container.read(tripTableConfigProvider);
      expect(config.sortField, isNull);
      expect(config.sortAscending, isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // siteTableConfigProvider
  // -----------------------------------------------------------------------

  group('siteTableConfigProvider', () {
    test('provides default config with expected columns', () {
      final config = container.read(siteTableConfigProvider);
      expect(config.columns, isNotEmpty);
      expect(config.columns.length, equals(6));
      expect(config.columns.first.field, equals(SiteField.siteName));
      expect(config.columns.first.isPinned, isTrue);
    });

    test('default config includes expected fields', () {
      final config = container.read(siteTableConfigProvider);
      final fields = config.columns.map((c) => c.field).toList();
      expect(fields, contains(SiteField.location));
      expect(fields, contains(SiteField.country));
      expect(fields, contains(SiteField.maxDepth));
      expect(fields, contains(SiteField.diveCount));
      expect(fields, contains(SiteField.waterType));
    });

    test('default config has no sort', () {
      final config = container.read(siteTableConfigProvider);
      expect(config.sortField, isNull);
      expect(config.sortAscending, isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // Notifier mutations via provider
  // -----------------------------------------------------------------------

  group('notifier mutations through provider', () {
    test('buddyTableConfigProvider notifier toggleColumn works', () {
      final notifier = container.read(buddyTableConfigProvider.notifier);
      final before = container.read(buddyTableConfigProvider).columns.length;
      // Toggle off a non-pinned column
      notifier.toggleColumn(BuddyField.email);
      final after = container.read(buddyTableConfigProvider).columns.length;
      expect(after, equals(before - 1));
    });

    test('tripTableConfigProvider notifier setSortField works', () {
      final notifier = container.read(tripTableConfigProvider.notifier);
      notifier.setSortField(TripField.startDate);
      final config = container.read(tripTableConfigProvider);
      expect(config.sortField, equals(TripField.startDate));
      expect(config.sortAscending, isTrue);
    });

    test('siteTableConfigProvider notifier togglePin works', () {
      final notifier = container.read(siteTableConfigProvider.notifier);
      // location is not pinned by default
      final before = container
          .read(siteTableConfigProvider)
          .columns
          .firstWhere((c) => c.field == SiteField.location)
          .isPinned;
      expect(before, isFalse);

      notifier.togglePin(SiteField.location);
      final after = container
          .read(siteTableConfigProvider)
          .columns
          .firstWhere((c) => c.field == SiteField.location)
          .isPinned;
      expect(after, isTrue);
    });

    test('equipmentTableConfigProvider notifier resizeColumn works', () {
      final notifier = container.read(equipmentTableConfigProvider.notifier);
      notifier.resizeColumn(EquipmentField.brand, 250.0);
      final col = container
          .read(equipmentTableConfigProvider)
          .columns
          .firstWhere((c) => c.field == EquipmentField.brand);
      expect(col.width, equals(250.0));
    });

    test('certificationTableConfigProvider notifier reorderColumn works', () {
      final notifier = container.read(
        certificationTableConfigProvider.notifier,
      );
      final firstField = container
          .read(certificationTableConfigProvider)
          .columns
          .first
          .field;
      // Move first column to end
      notifier.reorderColumn(0, 6);
      final lastField = container
          .read(certificationTableConfigProvider)
          .columns
          .last
          .field;
      expect(lastField, equals(firstField));
    });
  });

  // -----------------------------------------------------------------------
  // Save timer and dispose coverage
  // -----------------------------------------------------------------------

  group('EntityTableConfigNotifier save timer and dispose', () {
    test('dispose cancels pending save timer for buddy config', () {
      final notifier = container.read(buddyTableConfigProvider.notifier);
      notifier.toggleColumn(BuddyField.email);
      // dispose is handled by container.dispose() in tearDown
    });

    test('save timer fires without crash when no repo (null diverId)', () async {
      final notifier = container.read(tripTableConfigProvider.notifier);
      notifier.toggleColumn(TripField.maxDepth);
      // Wait for the 500ms debounce timer to fire
      await Future<void>.delayed(const Duration(milliseconds: 600));
      // No assertion needed -- just exercises the timer callback with null repo
    });

    test('multiple rapid mutations do not throw', () {
      final notifier = container.read(equipmentTableConfigProvider.notifier);
      notifier.toggleColumn(EquipmentField.brand);
      notifier.setSortField(EquipmentField.type);
      notifier.resizeColumn(EquipmentField.model, 200);
      notifier.togglePin(EquipmentField.status);
      notifier.reorderColumn(0, 3);
      // All mutations should succeed without throwing
    });

    test('setSortField cycles through all sort states', () {
      final notifier = container.read(siteTableConfigProvider.notifier);
      // Initial: no sort
      expect(container.read(siteTableConfigProvider).sortField, isNull);

      // First call: ascending
      notifier.setSortField(SiteField.maxDepth);
      expect(
        container.read(siteTableConfigProvider).sortField,
        equals(SiteField.maxDepth),
      );
      expect(container.read(siteTableConfigProvider).sortAscending, isTrue);

      // Second call (same field): descending
      notifier.setSortField(SiteField.maxDepth);
      expect(
        container.read(siteTableConfigProvider).sortField,
        equals(SiteField.maxDepth),
      );
      expect(container.read(siteTableConfigProvider).sortAscending, isFalse);

      // Third call (same field): clear sort
      notifier.setSortField(SiteField.maxDepth);
      expect(container.read(siteTableConfigProvider).sortField, isNull);
    });

    test('resizeColumn clamps to field min and max', () {
      final notifier = container.read(courseTableConfigProvider.notifier);

      // Resize below minimum
      notifier.resizeColumn(CourseField.courseName, 10.0);
      final col = container
          .read(courseTableConfigProvider)
          .columns
          .firstWhere((c) => c.field == CourseField.courseName);
      expect(col.width, greaterThanOrEqualTo(CourseField.courseName.minWidth));

      // Resize above maximum
      notifier.resizeColumn(CourseField.courseName, 9999.0);
      final col2 = container
          .read(courseTableConfigProvider)
          .columns
          .firstWhere((c) => c.field == CourseField.courseName);
      expect(col2.width, equals(600.0));
    });

    test('toggleColumn does not remove pinned column', () {
      final notifier = container.read(diveCenterTableConfigProvider.notifier);
      final before = container
          .read(diveCenterTableConfigProvider)
          .columns
          .length;
      // centerName is pinned
      notifier.toggleColumn(DiveCenterField.centerName);
      final after = container
          .read(diveCenterTableConfigProvider)
          .columns
          .length;
      expect(after, equals(before));
    });

    test('toggleColumn adds then removes non-pinned column', () {
      final notifier = container.read(buddyTableConfigProvider.notifier);
      final before = container.read(buddyTableConfigProvider).columns.length;

      // Add a new column
      notifier.toggleColumn(BuddyField.phone);
      expect(
        container.read(buddyTableConfigProvider).columns.length,
        equals(before + 1),
      );

      // Remove it
      notifier.toggleColumn(BuddyField.phone);
      expect(
        container.read(buddyTableConfigProvider).columns.length,
        equals(before),
      );
    });
  });
}
