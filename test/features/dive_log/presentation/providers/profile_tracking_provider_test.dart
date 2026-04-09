import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';

void main() {
  group('profileTrackingIndexProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('defaults to null', () {
      expect(container.read(profileTrackingIndexProvider('dive-1')), isNull);
    });

    test('can be set to an index', () {
      container.read(profileTrackingIndexProvider('dive-1').notifier).state =
          42;
      expect(container.read(profileTrackingIndexProvider('dive-1')), 42);
    });

    test('can be reset to null', () {
      container.read(profileTrackingIndexProvider('dive-1').notifier).state =
          10;
      container.read(profileTrackingIndexProvider('dive-1').notifier).state =
          null;
      expect(container.read(profileTrackingIndexProvider('dive-1')), isNull);
    });

    test('different dive IDs are independent', () {
      container.read(profileTrackingIndexProvider('dive-1').notifier).state = 5;
      container.read(profileTrackingIndexProvider('dive-2').notifier).state =
          99;

      expect(container.read(profileTrackingIndexProvider('dive-1')), 5);
      expect(container.read(profileTrackingIndexProvider('dive-2')), 99);
      expect(container.read(profileTrackingIndexProvider('dive-3')), isNull);
    });

    test('updating one dive does not affect another', () {
      container.read(profileTrackingIndexProvider('dive-1').notifier).state =
          10;
      container.read(profileTrackingIndexProvider('dive-2').notifier).state =
          20;

      // Update dive-1
      container.read(profileTrackingIndexProvider('dive-1').notifier).state =
          15;

      expect(container.read(profileTrackingIndexProvider('dive-1')), 15);
      expect(container.read(profileTrackingIndexProvider('dive-2')), 20);
    });
  });
}
