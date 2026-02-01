import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';

void main() {
  group('MapListSelectionState', () {
    test('initial state has null selectedId and isCollapsed false', () {
      const state = MapListSelectionState();
      expect(state.selectedId, isNull);
      expect(state.isCollapsed, isFalse);
    });

    test('copyWith updates selectedId', () {
      const state = MapListSelectionState();
      final updated = state.copyWith(selectedId: 'test-id');
      expect(updated.selectedId, 'test-id');
      expect(updated.isCollapsed, isFalse);
    });

    test('copyWith updates isCollapsed', () {
      const state = MapListSelectionState();
      final updated = state.copyWith(isCollapsed: true);
      expect(updated.selectedId, isNull);
      expect(updated.isCollapsed, isTrue);
    });

    test('copyWith can clear selectedId with clearSelectedId', () {
      const state = MapListSelectionState(selectedId: 'test-id');
      final updated = state.copyWith(clearSelectedId: true);
      expect(updated.selectedId, isNull);
    });
  });

  group('MapListSelectionNotifier', () {
    test('select updates selectedId', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        mapListSelectionProvider('sites').notifier,
      );
      notifier.select('site-123');

      final state = container.read(mapListSelectionProvider('sites'));
      expect(state.selectedId, 'site-123');
    });

    test('deselect clears selectedId', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        mapListSelectionProvider('sites').notifier,
      );
      notifier.select('site-123');
      notifier.deselect();

      final state = container.read(mapListSelectionProvider('sites'));
      expect(state.selectedId, isNull);
    });

    test('toggleCollapse toggles isCollapsed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        mapListSelectionProvider('sites').notifier,
      );
      expect(
        container.read(mapListSelectionProvider('sites')).isCollapsed,
        isFalse,
      );

      notifier.toggleCollapse();
      expect(
        container.read(mapListSelectionProvider('sites')).isCollapsed,
        isTrue,
      );

      notifier.toggleCollapse();
      expect(
        container.read(mapListSelectionProvider('sites')).isCollapsed,
        isFalse,
      );
    });

    test('different section keys have independent state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(mapListSelectionProvider('sites').notifier)
          .select('site-1');
      container
          .read(mapListSelectionProvider('dive-centers').notifier)
          .select('center-1');

      expect(
        container.read(mapListSelectionProvider('sites')).selectedId,
        'site-1',
      );
      expect(
        container.read(mapListSelectionProvider('dive-centers')).selectedId,
        'center-1',
      );
    });
  });
}
