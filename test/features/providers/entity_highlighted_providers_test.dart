import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_field.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/constants/trip_field.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

import '../../helpers/mock_providers.dart';

void main() {
  group('highlighted entity ID providers', () {
    // ========================================================================
    // Buddy
    // ========================================================================

    group('highlightedBuddyIdProvider', () {
      test('defaults to null', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        expect(container.read(highlightedBuddyIdProvider), isNull);
      });

      test('can be set to a string value', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(highlightedBuddyIdProvider.notifier).state = 'buddy-123';
        expect(container.read(highlightedBuddyIdProvider), 'buddy-123');
      });
    });

    // ========================================================================
    // Certification
    // ========================================================================

    group('highlightedCertificationIdProvider', () {
      test('defaults to null', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        expect(container.read(highlightedCertificationIdProvider), isNull);
      });

      test('can be set to a string value', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(highlightedCertificationIdProvider.notifier).state =
            'cert-456';
        expect(container.read(highlightedCertificationIdProvider), 'cert-456');
      });
    });

    // ========================================================================
    // Course
    // ========================================================================

    group('highlightedCourseIdProvider', () {
      test('defaults to null', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        expect(container.read(highlightedCourseIdProvider), isNull);
      });

      test('can be set to a string value', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(highlightedCourseIdProvider.notifier).state =
            'course-789';
        expect(container.read(highlightedCourseIdProvider), 'course-789');
      });
    });

    // ========================================================================
    // Dive Center
    // ========================================================================

    group('highlightedDiveCenterIdProvider', () {
      test('defaults to null', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        expect(container.read(highlightedDiveCenterIdProvider), isNull);
      });

      test('can be set to a string value', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(highlightedDiveCenterIdProvider.notifier).state =
            'center-101';
        expect(container.read(highlightedDiveCenterIdProvider), 'center-101');
      });
    });

    // ========================================================================
    // Dive Site
    // ========================================================================

    group('highlightedSiteIdProvider', () {
      test('defaults to null', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        expect(container.read(highlightedSiteIdProvider), isNull);
      });

      test('can be set to a string value', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(highlightedSiteIdProvider.notifier).state = 'site-202';
        expect(container.read(highlightedSiteIdProvider), 'site-202');
      });
    });

    // ========================================================================
    // Equipment
    // ========================================================================

    group('highlightedEquipmentIdProvider', () {
      test('defaults to null', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        expect(container.read(highlightedEquipmentIdProvider), isNull);
      });

      test('can be set to a string value', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(highlightedEquipmentIdProvider.notifier).state =
            'equip-303';
        expect(container.read(highlightedEquipmentIdProvider), 'equip-303');
      });
    });

    // ========================================================================
    // Trip
    // ========================================================================

    group('highlightedTripIdProvider', () {
      test('defaults to null', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        expect(container.read(highlightedTripIdProvider), isNull);
      });

      test('can be set to a string value', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(highlightedTripIdProvider.notifier).state = 'trip-404';
        expect(container.read(highlightedTripIdProvider), 'trip-404');
      });
    });
  });

  // ==========================================================================
  // Table config provider default column tests
  // ==========================================================================

  group('table config provider defaults', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    // ========================================================================
    // Buddy
    // ========================================================================

    group('buddyTableConfigProvider', () {
      test('has expected default columns', () {
        final config = container.read(buddyTableConfigProvider);
        final fields = config.columns.map((c) => c.field).toList();
        expect(fields, [
          BuddyField.buddyName,
          BuddyField.certificationLevel,
          BuddyField.certificationAgency,
          BuddyField.email,
          BuddyField.diveCount,
        ]);
      });

      test('first column is pinned', () {
        final config = container.read(buddyTableConfigProvider);
        expect(config.columns.first.isPinned, isTrue);
        expect(config.columns.first.field, BuddyField.buddyName);
      });
    });

    // ========================================================================
    // Certification
    // ========================================================================

    group('certificationTableConfigProvider', () {
      test('has expected default columns', () {
        final config = container.read(certificationTableConfigProvider);
        final fields = config.columns.map((c) => c.field).toList();
        expect(fields, [
          CertificationField.certName,
          CertificationField.agency,
          CertificationField.level,
          CertificationField.issueDate,
          CertificationField.expiryDate,
          CertificationField.expiryStatus,
        ]);
      });

      test('first column is pinned', () {
        final config = container.read(certificationTableConfigProvider);
        expect(config.columns.first.isPinned, isTrue);
        expect(config.columns.first.field, CertificationField.certName);
      });
    });

    // ========================================================================
    // Course
    // ========================================================================

    group('courseTableConfigProvider', () {
      test('has expected default columns', () {
        final config = container.read(courseTableConfigProvider);
        final fields = config.columns.map((c) => c.field).toList();
        expect(fields, [
          CourseField.courseName,
          CourseField.agency,
          CourseField.startDate,
          CourseField.completionDate,
          CourseField.isCompleted,
          CourseField.location,
        ]);
      });

      test('first column is pinned', () {
        final config = container.read(courseTableConfigProvider);
        expect(config.columns.first.isPinned, isTrue);
        expect(config.columns.first.field, CourseField.courseName);
      });
    });

    // ========================================================================
    // Dive Center
    // ========================================================================

    group('diveCenterTableConfigProvider', () {
      test('has expected default columns', () {
        final config = container.read(diveCenterTableConfigProvider);
        final fields = config.columns.map((c) => c.field).toList();
        expect(fields, [
          DiveCenterField.centerName,
          DiveCenterField.city,
          DiveCenterField.country,
          DiveCenterField.phone,
          DiveCenterField.diveCount,
          DiveCenterField.rating,
        ]);
      });

      test('first column is pinned', () {
        final config = container.read(diveCenterTableConfigProvider);
        expect(config.columns.first.isPinned, isTrue);
        expect(config.columns.first.field, DiveCenterField.centerName);
      });
    });

    // ========================================================================
    // Dive Site
    // ========================================================================

    group('siteTableConfigProvider', () {
      test('has expected default columns', () {
        final config = container.read(siteTableConfigProvider);
        final fields = config.columns.map((c) => c.field).toList();
        expect(fields, [
          SiteField.siteName,
          SiteField.location,
          SiteField.country,
          SiteField.maxDepth,
          SiteField.diveCount,
          SiteField.waterType,
        ]);
      });

      test('first column is pinned', () {
        final config = container.read(siteTableConfigProvider);
        expect(config.columns.first.isPinned, isTrue);
        expect(config.columns.first.field, SiteField.siteName);
      });
    });

    // ========================================================================
    // Equipment
    // ========================================================================

    group('equipmentTableConfigProvider', () {
      test('has expected default columns', () {
        final config = container.read(equipmentTableConfigProvider);
        final fields = config.columns.map((c) => c.field).toList();
        expect(fields, [
          EquipmentField.itemName,
          EquipmentField.type,
          EquipmentField.brand,
          EquipmentField.model,
          EquipmentField.status,
          EquipmentField.lastServiceDate,
        ]);
      });

      test('first column is pinned', () {
        final config = container.read(equipmentTableConfigProvider);
        expect(config.columns.first.isPinned, isTrue);
        expect(config.columns.first.field, EquipmentField.itemName);
      });
    });

    // ========================================================================
    // Trip
    // ========================================================================

    group('tripTableConfigProvider', () {
      test('has expected default columns', () {
        final config = container.read(tripTableConfigProvider);
        final fields = config.columns.map((c) => c.field).toList();
        expect(fields, [
          TripField.tripName,
          TripField.startDate,
          TripField.endDate,
          TripField.location,
          TripField.diveCount,
          TripField.maxDepth,
        ]);
      });

      test('first column is pinned', () {
        final config = container.read(tripTableConfigProvider);
        expect(config.columns.first.isPinned, isTrue);
        expect(config.columns.first.field, TripField.tripName);
      });
    });
  });
}
