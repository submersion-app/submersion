import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  group('personalRecordsProvider', () {
    test('finds longest dive by bottomTime', () async {
      final dives = [
        createTestDiveWithBottomTime(
          id: 'short',
          bottomTime: const Duration(minutes: 20),
          maxDepth: 15.0,
          waterTemp: 24.0,
        ),
        createTestDiveWithBottomTime(
          id: 'long',
          bottomTime: const Duration(minutes: 60),
          maxDepth: 25.0,
          waterTemp: 22.0,
        ),
        createTestDiveWithBottomTime(
          id: 'medium',
          bottomTime: const Duration(minutes: 40),
          maxDepth: 30.0,
          waterTemp: 20.0,
        ),
      ];

      final container = ProviderContainer(
        overrides: [divesProvider.overrideWith((ref) async => dives)],
      );
      addTearDown(container.dispose);

      final records = await container.read(personalRecordsProvider.future);

      expect(records.longestDive, isNotNull);
      expect(records.longestDive!.id, 'long');
      expect(records.longestDive!.bottomTime!.inMinutes, 60);
    });

    test('handles dives with null bottomTime', () async {
      final dives = [
        createTestDiveWithBottomTime(
          id: 'no-bt',
          bottomTime: null,
          maxDepth: 20.0,
        ),
        createTestDiveWithBottomTime(
          id: 'has-bt',
          bottomTime: const Duration(minutes: 30),
          maxDepth: 15.0,
        ),
      ];

      final container = ProviderContainer(
        overrides: [divesProvider.overrideWith((ref) async => dives)],
      );
      addTearDown(container.dispose);

      final records = await container.read(personalRecordsProvider.future);

      expect(records.longestDive, isNotNull);
      expect(records.longestDive!.id, 'has-bt');
    });
  });
}
