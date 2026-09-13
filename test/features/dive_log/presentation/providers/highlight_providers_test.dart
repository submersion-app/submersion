import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  group('highlightedDiveIdProvider', () {
    test('defaults to null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(highlightedDiveIdProvider), isNull);
    });

    test('can be set and read', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(highlightedDiveIdProvider.notifier).state = 'dive-123';
      expect(container.read(highlightedDiveIdProvider), 'dive-123');
    });

    test('can be cleared back to null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(highlightedDiveIdProvider.notifier).state = 'dive-123';
      container.read(highlightedDiveIdProvider.notifier).state = null;
      expect(container.read(highlightedDiveIdProvider), isNull);
    });
  });

  group('listedHighlightedDiveIdProvider', () {
    ProviderContainer containerWith({
      required String? highlightedId,
      required AsyncValue<List<Dive>> tableDives,
    }) {
      final container = ProviderContainer(
        overrides: [
          highlightedDiveIdProvider.overrideWith((ref) => highlightedId),
          allDivesForTableProvider.overrideWith((ref) => tableDives),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    final listed = AsyncValue.data([
      createTestDiveWithBottomTime(id: 'dive-a'),
      createTestDiveWithBottomTime(id: 'dive-b'),
    ]);

    test('is null when nothing is highlighted', () {
      final container = containerWith(highlightedId: null, tableDives: listed);
      expect(container.read(listedHighlightedDiveIdProvider), isNull);
    });

    test('is the highlight while the filtered list includes its dive', () {
      final container = containerWith(
        highlightedId: 'dive-b',
        tableDives: listed,
      );
      expect(container.read(listedHighlightedDiveIdProvider), 'dive-b');
    });

    test('is null while the filtered list excludes its dive', () {
      final container = containerWith(
        highlightedId: 'dive-gone',
        tableDives: listed,
      );
      expect(container.read(listedHighlightedDiveIdProvider), isNull);
      // Ignored, not dropped: the highlight itself is untouched.
      expect(container.read(highlightedDiveIdProvider), 'dive-gone');
    });

    test('passes the highlight through before the list has loaded', () {
      final container = containerWith(
        highlightedId: 'dive-b',
        tableDives: const AsyncValue.loading(),
      );
      expect(container.read(listedHighlightedDiveIdProvider), 'dive-b');
    });
  });

  group('showProfilePanelProvider', () {
    test('defaults to true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(showProfilePanelProvider), isTrue);
    });

    test('can be toggled off', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(showProfilePanelProvider.notifier).state = false;
      expect(container.read(showProfilePanelProvider), isFalse);
    });
  });
}
