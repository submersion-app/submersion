import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/home_panels.dart';
import 'package:submersion/features/dashboard/presentation/home_presets.dart';

void main() {
  test('each preset lists known panels once, key numbers first', () {
    for (final p in HomeLayoutPreset.values) {
      final panels = homePresetPanels(p);
      expect(panels.toSet().length, panels.length, reason: '$p');
      expect(panels.first, HomePanelType.keyNumbers, reason: '$p');
    }
  });

  test('presets differ from one another', () {
    final lists = HomeLayoutPreset.values.map(homePresetPanels).toList();
    for (var i = 0; i < lists.length; i++) {
      for (var j = i + 1; j < lists.length; j++) {
        expect(lists[i], isNot(lists[j]));
      }
    }
  });

  test('a preset layout holds every panel once, others hidden', () {
    for (final p in HomeLayoutPreset.values) {
      final layout = homeLayoutForPreset(p);
      expect(layout.order.toSet(), HomePanelType.values.toSet());
      expect(layout.order.length, HomePanelType.values.length);
      expect(layout.visible, homePresetPanels(p));
    }
  });

  test('matchingPreset finds each preset from its own layout', () {
    for (final p in HomeLayoutPreset.values) {
      expect(matchingPreset(homeLayoutForPreset(p)), p);
    }
  });

  test('nothing stored resolves to Balanced', () {
    final layout = resolveHomeLayout(
      storedOrder: null,
      storedHidden: null,
      legacyHiddenCards: const {},
    );
    expect(layout.visible, homePresetPanels(HomeLayoutPreset.balanced));
    expect(matchingPreset(layout), HomeLayoutPreset.balanced);
  });

  test('a card hidden before the upgrade stays hidden', () {
    final layout = resolveHomeLayout(
      storedOrder: null,
      storedHidden: null,
      legacyHiddenCards: const {'photoRibbon', 'hero', 'milestones'},
    );
    expect(layout.visible, isNot(contains(HomePanelType.photoRibbon)));
    expect(layout.visible, contains(HomePanelType.recentDives));
    expect(matchingPreset(layout), isNull);
  });

  test('unknown and duplicate names are dropped, missing panels hidden', () {
    final layout = resolveHomeLayout(
      storedOrder: const ['recentDives', 'bogus', 'recentDives', 'keyNumbers'],
      storedHidden: const {'bogus'},
      legacyHiddenCards: const {},
    );
    expect(layout.order.toSet(), HomePanelType.values.toSet());
    expect(layout.order.length, HomePanelType.values.length);
    expect(layout.visible, [
      HomePanelType.recentDives,
      HomePanelType.keyNumbers,
    ]);
  });

  test('a panel missing from the stored order is slotted after its '
      'nearest earlier neighbour', () {
    final stored = homeLayoutForPreset(HomeLayoutPreset.balanced).order
        .where((p) => p != HomePanelType.gearService)
        .map((p) => p.name)
        .toList();
    final layout = resolveHomeLayout(
      storedOrder: stored,
      storedHidden: const {},
      legacyHiddenCards: const {},
    );
    final i = layout.order.indexOf(HomePanelType.gearService);
    expect(layout.order[i - 1], HomePanelType.activityCalendar);
    expect(layout.hidden, contains(HomePanelType.gearService));
  });

  test('a stored layout ignores the legacy hidden cards', () {
    final layout = resolveHomeLayout(
      storedOrder: homeLayoutForPreset(
        HomeLayoutPreset.balanced,
      ).order.map((p) => p.name).toList(),
      storedHidden: const {},
      legacyHiddenCards: const {'recentDives'},
    );
    expect(layout.visible, contains(HomePanelType.recentDives));
  });

  test('withPanelEnabled and withOrder keep every panel exactly once', () {
    final base = homeLayoutForPreset(HomeLayoutPreset.balanced);
    final off = base.withPanelEnabled(HomePanelType.recentDives, false);
    expect(off.visible, isNot(contains(HomePanelType.recentDives)));
    final on = off.withPanelEnabled(HomePanelType.sacTrend, true);
    expect(on.visible, contains(HomePanelType.sacTrend));
    final moved = on.withOrder(on.order.reversed.toList());
    expect(moved.order.first, on.order.last);
    expect(moved.hidden, on.hidden);
  });
}
