import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';

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
