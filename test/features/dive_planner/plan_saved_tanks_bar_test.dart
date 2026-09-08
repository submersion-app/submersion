import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/database/database.dart'
    hide CylinderConfig, CylinderConfigItem, DiveTank;
import 'package:submersion/features/cylinder_configs/data/repositories/cylinder_config_repository.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_saved_tanks_bar.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_list.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

/// The saved-tanks bar sits above the plan's tanks, closed. Opening it shows
/// every saved cylinder as its own object, and tapping one adds it to the
/// plan with its gas - the diver's rig, a tap away from any plan. Saving is
/// one tank at a time, chosen from the plan's tanks and named by the diver.
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _now = DateTime(2026, 9, 2);

CylinderConfigItem _item(
  String id,
  String label, {
  double o2 = 21,
  double volume = 11.1,
  TankRole role = TankRole.backGas,
}) => CylinderConfigItem(
  id: id,
  configId: 'cfg',
  label: label,
  tankRole: role,
  volumeL: volume,
  workingPressureBar: 207,
  o2Percent: o2,
  defaultStartPressureBar: 200,
  createdAt: _now,
  updatedAt: _now,
);

final _saved = CylinderConfig(
  id: 'cfg',
  name: 'Saved tanks',
  items: [
    _item('i1', 'D12', volume: 24),
    _item('i2', 'S80 EAN50', o2: 50, role: TankRole.deco),
  ],
  createdAt: _now,
  updatedAt: _now,
);

/// A repository that answers from memory and records what the bar writes,
/// so the save flow can be checked without a database.
class _FakeConfigRepository implements CylinderConfigRepository {
  _FakeConfigRepository({this.configs = const [], this.saveError});

  final List<CylinderConfig> configs;

  /// Thrown from [saveItems] when set, to drive the bar's error path.
  final Object? saveError;

  int createConfigCalls = 0;
  String? savedConfigId;
  List<CylinderConfigItem>? savedItems;

  @override
  Future<List<CylinderConfig>> getAllConfigs({
    String? diverId,
    bool includeItems = false,
  }) async => configs;

  @override
  Future<String> createConfig({
    String? diverId,
    String? equipmentId,
    required String name,
    String description = '',
    int sortOrder = 0,
  }) async {
    createConfigCalls++;
    return 'new-cfg';
  }

  @override
  Future<void> saveItems(
    String configId,
    List<CylinderConfigItem> desired,
  ) async {
    if (saveError != null) throw saveError!;
    savedConfigId = configId;
    savedItems = desired;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The bar alone, backed by [repository] for the save flow.
Widget _barHarness(_FakeConfigRepository repository) => testApp(
  overrides: [
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    cylinderConfigsProvider.overrideWith((ref) async => repository.configs),
    cylinderConfigRepositoryProvider.overrideWithValue(repository),
    validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
  ],
  child: const SizedBox(width: 500, child: PlanSavedTanksBar()),
);

/// Open the bar, pick the plan's only tank from the save menu and accept the
/// default name in the dialog.
Future<void> _saveOnlyPlanTank(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(PlanSavedTanksBar)),
  );
  final planTank = container.read(divePlanNotifierProvider).tanks.single;

  await tester.tap(find.textContaining('Saved tanks'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save a tank'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(PopupMenuItem<DiveTank>),
      matching: find.textContaining(planTank.gasMix.name),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

Widget _harness(List<CylinderConfig> configs) => testApp(
  overrides: [
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    cylinderConfigsProvider.overrideWith((ref) async => configs),
  ],
  child: const SizedBox(
    width: 500,
    height: 700,
    child: SingleChildScrollView(child: PlanTankList()),
  ),
);

void main() {
  testWidgets('starts closed, showing how many saved tanks there are', (
    tester,
  ) async {
    await tester.pumpWidget(_harness([_saved]));
    await tester.pumpAndSettle();

    expect(find.text('Saved tanks (2)'), findsOneWidget);
    expect(find.text('D12'), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });

  testWidgets('opens into the saved cylinders, each its own chip', (
    tester,
  ) async {
    await tester.pumpWidget(_harness([_saved]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved tanks (2)'));
    await tester.pumpAndSettle();

    expect(find.text('D12'), findsOneWidget);
    expect(find.text('S80 EAN50'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    expect(find.text('Save a tank'), findsOneWidget);
    expect(find.text('Manage'), findsOneWidget);
  });

  testWidgets('tapping a saved cylinder adds it to the plan with its gas', (
    tester,
  ) async {
    await tester.pumpWidget(_harness([_saved]));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanSavedTanksBar)),
    );
    final before = container.read(divePlanNotifierProvider).tanks.length;

    await tester.tap(find.text('Saved tanks (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('S80 EAN50'));
    await tester.pumpAndSettle();

    final tanks = container.read(divePlanNotifierProvider).tanks;
    expect(tanks.length, before + 1);
    final added = tanks.last;
    expect(added.name, 'S80 EAN50');
    expect(added.gasMix.o2, 50);
    expect(added.volume, 11.1);
    expect(added.role, TankRole.deco);
    expect(added.order, before);
    // The saved cylinder is still offered: picking is a copy, not a move.
    expect(find.text('S80 EAN50'), findsNWidgets(2));
  });

  testWidgets('saving offers the plan tanks one at a time, then asks for a '
      'tank name', (tester) async {
    await tester.pumpWidget(_harness([_saved]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved tanks (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save a tank'));
    await tester.pumpAndSettle();

    // The default plan has one tank; the menu lists it.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanSavedTanksBar)),
    );
    final planTank = container.read(divePlanNotifierProvider).tanks.single;
    final menuEntry = find.textContaining(planTank.gasMix.name).last;
    await tester.tap(menuEntry);
    await tester.pumpAndSettle();

    expect(find.text('Save tank as'), findsOneWidget);
    expect(find.text('Tank name'), findsOneWidget);
    expect(find.text('Plan Name'), findsNothing);
  });

  testWidgets('a tank saved from the planner keeps its derived role, not the '
      'back-gas placeholder', (tester) async {
    // The planner stores TankRole.backGas as the "derive me" placeholder and
    // lets TankRoleResolver work the real role out from the gas and the
    // segments. A cylinder leaving the planner for the equipment pages has no
    // plan around it any more, so the role has to be resolved before it is
    // written or every saved bottle reads back as back gas.
    final db = await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final stamp = _now.millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'Diver',
            createdAt: stamp,
            updatedAt: stamp,
          ),
        );

    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        ],
        child: const SizedBox(
          width: 500,
          height: 700,
          child: SingleChildScrollView(child: PlanTankList()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanSavedTanksBar)),
    );
    // Richer than the bottom mix, so the resolver calls it a deco bottle.
    container
        .read(divePlanNotifierProvider.notifier)
        .addTank(
          const DiveTank(
            id: 'deco-1',
            name: 'S80 EAN50',
            volume: 11.1,
            workingPressure: 207,
            startPressure: 200,
            gasMix: GasMix(o2: 50, he: 0),
            role: TankRole.backGas,
            order: 1,
          ),
        );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved tanks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save a tank'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(PopupMenuItem<DiveTank>),
        matching: find.textContaining('S80 EAN50'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = (await CylinderConfigRepository().getAllConfigs(
      diverId: 'd1',
      includeItems: true,
    )).expand((config) => config.items).toList();
    expect(saved, hasLength(1));
    expect(saved.single.label, 'S80 EAN50');
    expect(saved.single.tankRole, TankRole.deco);
  });

  testWidgets('with nothing saved it explains how to save', (tester) async {
    await tester.pumpWidget(_harness(const []));
    await tester.pumpAndSettle();

    expect(find.text('Saved tanks'), findsOneWidget);
    await tester.tap(find.text('Saved tanks'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No saved tanks yet'), findsOneWidget);
  });
  testWidgets('Manage opens the cylinder configurations page', (tester) async {
    String? pushedPath;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: SizedBox(width: 500, child: PlanSavedTanksBar()),
          ),
        ),
        GoRoute(
          path: '/equipment/cylinder-configs',
          builder: (context, state) {
            pushedPath = state.uri.toString();
            return const Scaffold(body: SizedBox());
          },
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          cylinderConfigsProvider.overrideWith((ref) async => [_saved]),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved tanks (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();

    expect(pushedPath, '/equipment/cylinder-configs');
    expect(find.byType(PlanSavedTanksBar), findsNothing);
  });

  testWidgets('saving into an existing Saved tanks folder appends to it '
      'instead of creating another', (tester) async {
    final folder = CylinderConfig(
      id: 'folder',
      name: 'Saved tanks',
      items: [_item('i1', 'D12', volume: 24)],
      createdAt: _now,
      updatedAt: _now,
    );
    final repository = _FakeConfigRepository(configs: [folder]);
    await tester.pumpWidget(_barHarness(repository));
    await tester.pumpAndSettle();

    await _saveOnlyPlanTank(tester);

    expect(repository.createConfigCalls, 0);
    expect(repository.savedConfigId, 'folder');
    final labels = repository.savedItems!.map((item) => item.label).toList();
    expect(labels, ['D12', 'Primary']);
    expect(repository.savedItems!.first.id, 'i1');
    expect(find.text('Tank saved'), findsOneWidget);
  });

  testWidgets('a repository failure while saving surfaces as a snackbar', (
    tester,
  ) async {
    final repository = _FakeConfigRepository(
      saveError: StateError('disk full'),
    );
    await tester.pumpWidget(_barHarness(repository));
    await tester.pumpAndSettle();

    await _saveOnlyPlanTank(tester);

    // No folder existed, so one was created before the write failed.
    expect(repository.createConfigCalls, 1);
    expect(repository.savedItems, isNull);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('disk full'), findsOneWidget);
    expect(find.text('Tank saved'), findsNothing);
  });

  testWidgets('with no plan tanks the save menu is greyed out and inert', (
    tester,
  ) async {
    await tester.pumpWidget(_barHarness(_FakeConfigRepository()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanSavedTanksBar)),
    );
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.loadPlan(
      container.read(divePlanNotifierProvider).copyWith(tanks: const []),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved tanks'));
    await tester.pumpAndSettle();

    final menu = tester.widget<PopupMenuButton<DiveTank>>(
      find.byType(PopupMenuButton<DiveTank>),
    );
    expect(menu.enabled, isFalse);
    final icon = tester.widget<Icon>(find.byIcon(Icons.save_outlined));
    final theme = Theme.of(tester.element(find.byType(PlanSavedTanksBar)));
    expect(icon.color!.a, closeTo(0.38, 0.01));
    expect(icon.color, isNot(theme.colorScheme.primary));

    await tester.tap(find.text('Save a tank'));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<DiveTank>), findsNothing);
  });
}
