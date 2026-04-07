import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/providers/table_details_pane_provider.dart';

void main() {
  group('tableDetailsPaneProvider', () {
    test('defaults to false for unknown section', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final value = container.read(tableDetailsPaneProvider('sites'));
      expect(value, isFalse);
    });

    test('can be toggled to true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(tableDetailsPaneProvider('sites').notifier).state = true;
      expect(container.read(tableDetailsPaneProvider('sites')), isTrue);
    });

    test('sections are independent', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(tableDetailsPaneProvider('sites').notifier).state = true;
      expect(container.read(tableDetailsPaneProvider('buddies')), isFalse);
    });
  });
}
