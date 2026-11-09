import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_fold_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/settings/domain/list_arrangements.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';

/// Holds the diver's saved arrangement back until the first write, as a
/// settings load that lands after a launch tap does: the write then runs
/// against what loaded.
class _LateLoadSettings extends MockSettingsNotifier {
  _LateLoadSettings(this.loaded) : super(const AppSettings());

  final ListArrangements loaded;
  bool _landed = false;

  @override
  Future<void> updateListArrangements(
    ListArrangements Function(ListArrangements current) change,
  ) async {
    if (!_landed) {
      _landed = true;
      state = state.copyWith(listArrangements: loaded);
    }
    state = state.copyWith(listArrangements: change(state.listArrangements));
  }
}

/// The Equipment page's folds (issue #4184): saved per diver, except while a
/// filter is on, when every group shows open and folds live in memory only.
void main() {
  late ProviderContainer container;
  late MockSettingsNotifier settings;

  ProviderContainer build({String? saved}) {
    settings = MockSettingsNotifier(
      AppSettings(
        listArrangements: ListArrangements(equipmentCollapsedGroups: saved),
      ),
    );
    final c = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => settings),
        hasMultipleDiversProvider.overrideWithValue(false),
      ],
    );
    addTearDown(c.dispose);
    // Keep the notifier alive across reads, as the list page does.
    c.listen(equipmentFoldsProvider, (_, _) {});
    return c;
  }

  String? stored() => settings.state.listArrangements.equipmentCollapsedGroups;

  test('reads saved folds', () {
    container = build(saved: '["loc:a"]');
    expect(container.read(equipmentFoldsProvider), ['loc:a']);
    expect(
      container.read(equipmentFoldsProvider.notifier).isSessionOnly,
      isFalse,
    );
  });

  test('nothing saved reads as every group open', () {
    container = build();
    expect(container.read(equipmentFoldsProvider), isEmpty);
  });

  test('toggle saves', () {
    container = build(saved: '["loc:a"]');
    container.read(equipmentFoldsProvider.notifier).toggle('type:bcd');
    expect(container.read(equipmentFoldsProvider), ['loc:a', 'type:bcd']);
    expect(stored(), '["loc:a","type:bcd"]');
  });

  test('session folds are dropped and never saved', () {
    container = build(saved: '["loc:a"]');
    container.read(equipmentFilterProvider.notifier).state =
        const EquipmentFilterState(type: EquipmentType.bcd);
    final notifier = container.read(equipmentFoldsProvider.notifier);
    expect(container.read(equipmentFoldsProvider), isEmpty);
    expect(notifier.isSessionOnly, isTrue);

    notifier.toggle('loc:b');
    expect(container.read(equipmentFoldsProvider), ['loc:b']);
    expect(stored(), '["loc:a"]');

    container.read(equipmentFilterProvider.notifier).state =
        const EquipmentFilterState();
    expect(container.read(equipmentFoldsProvider), ['loc:a']);
    expect(stored(), '["loc:a"]');
  });

  test('collapseAll folds outer keys only, keeping inner folds', () {
    container = build(saved: '["loc:a/type:bcd"]');
    container.read(equipmentOuterGroupKeysProvider.notifier).state = const [
      'loc:a',
      'loc:b',
    ];
    container.read(equipmentFoldsProvider.notifier).collapseAll();
    expect(
      container.read(equipmentFoldsProvider),
      unorderedEquals(['loc:a/type:bcd', 'loc:a', 'loc:b']),
    );
    expect(stored(), '["loc:a/type:bcd","loc:a","loc:b"]');
  });

  test('expandAll clears and saves an empty list', () {
    container = build(saved: '["loc:a","type:bcd"]');
    container.read(equipmentFoldsProvider.notifier).expandAll();
    expect(container.read(equipmentFoldsProvider), isEmpty);
    expect(stored(), '[]');
  });

  test('a fold tapped before settings load keeps the saved folds', () {
    final late = _LateLoadSettings(
      const ListArrangements(equipmentCollapsedGroups: '["loc:a"]'),
    );
    final c = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => late),
        hasMultipleDiversProvider.overrideWithValue(false),
      ],
    );
    addTearDown(c.dispose);
    c.listen(equipmentFoldsProvider, (_, _) {});
    expect(c.read(equipmentFoldsProvider), isEmpty);

    c.read(equipmentFoldsProvider.notifier).toggle('type:bcd');

    expect(
      late.state.listArrangements.equipmentCollapsedGroups,
      '["loc:a","type:bcd"]',
    );
  });

  test('collapse all before settings load keeps the saved folds', () {
    final late = _LateLoadSettings(
      const ListArrangements(equipmentCollapsedGroups: '["loc:a/type:bcd"]'),
    );
    final c = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => late),
        hasMultipleDiversProvider.overrideWithValue(false),
      ],
    );
    addTearDown(c.dispose);
    c.listen(equipmentFoldsProvider, (_, _) {});
    c.read(equipmentOuterGroupKeysProvider.notifier).state = const ['loc:a'];

    c.read(equipmentFoldsProvider.notifier).collapseAll();

    expect(
      late.state.listArrangements.equipmentCollapsedGroups,
      '["loc:a/type:bcd","loc:a"]',
    );
  });
}
