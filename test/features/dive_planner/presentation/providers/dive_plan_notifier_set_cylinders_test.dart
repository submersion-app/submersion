import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Applying an equipment set to a plan adds the cylinders the set carries
/// (issue #4525).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final t = DateTime(2026, 11, 1);

  CylinderConfigItem cylinder(
    String id, {
    TankRole role = TankRole.backGas,
    double volume = 11.1,
    double o2 = 32,
  }) => CylinderConfigItem(
    id: id,
    configId: 'c',
    tankRole: role,
    volumeL: volume,
    workingPressureBar: 207,
    o2Percent: o2,
    createdAt: t,
    updatedAt: t,
  );

  Future<ProviderContainer> makeContainer() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'the untouched default tank gives way to the set\'s cylinders',
    () async {
      final container = await makeContainer();
      final notifier = container.read(divePlanNotifierProvider.notifier);
      expect(container.read(divePlanNotifierProvider).tanks, hasLength(1));

      notifier.addSetCylinders([
        cylinder('a'),
        cylinder('b', role: TankRole.deco, volume: 5.7, o2: 50),
      ]);

      final tanks = container.read(divePlanNotifierProvider).tanks;
      expect(tanks.map((x) => x.gasMix.o2), [32, 50]);
      expect(tanks.map((x) => x.role), [TankRole.backGas, TankRole.deco]);
      // A plan tank needs a start pressure to plan gas from.
      expect(tanks.every((x) => x.startPressure != null), isTrue);
      expect(container.read(divePlanNotifierProvider).isDirty, isTrue);
    },
  );

  test('a default tank the diver changed is kept', () async {
    final container = await makeContainer();
    final notifier = container.read(divePlanNotifierProvider.notifier);
    final first = container.read(divePlanNotifierProvider).tanks.single;
    notifier.updateTank(first.id, first.copyWith(gasMix: const GasMix(o2: 28)));

    notifier.addSetCylinders([cylinder('a')]);

    final tanks = container.read(divePlanNotifierProvider).tanks;
    expect(tanks.map((x) => x.gasMix.o2), [28, 32]);
  });

  test('a cylinder the plan already has is not added again', () async {
    final container = await makeContainer();
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.addSetCylinders([cylinder('a')]);
    notifier.markSaved();

    notifier.addSetCylinders([cylinder('a2')]);

    final state = container.read(divePlanNotifierProvider);
    expect(state.tanks, hasLength(1));
    // Nothing changed, so the plan is not marked unsaved.
    expect(state.isDirty, isFalse);
  });

  test('a suit inflation cylinder never joins a plan', () async {
    final container = await makeContainer();
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.markSaved();

    notifier.addSetCylinders([cylinder('s', role: TankRole.suitInflation)]);

    final state = container.read(divePlanNotifierProvider);
    // The default tank stays: the set brought no breathing gas.
    expect(state.tanks.single.gasMix.o2, 21);
    expect(state.isDirty, isFalse);
  });

  test('no cylinders means no change', () async {
    final container = await makeContainer();
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.markSaved();
    notifier.addSetCylinders(const []);
    expect(container.read(divePlanNotifierProvider).isDirty, isFalse);
  });
}
