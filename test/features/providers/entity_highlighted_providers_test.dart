import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

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
}
