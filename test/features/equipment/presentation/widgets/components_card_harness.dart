/// What the ComponentsCard tests share: the fakes the card writes through,
/// the parts of a regulator called "reg", and the app the card is pumped in.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_history_rewrite.dart';
import 'package:submersion/features/equipment/domain/services/assembly_totals.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_components_sitting.dart';
import 'package:submersion/features/equipment/presentation/providers/assembly_totals_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/components_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';

class FakeComponentRepository extends EquipmentComponentRepository {
  final removed = <String>[];
  final roles = <String, String>{};
  final reorders = <List<String>>[];

  @override
  Future<void> removeComponent(String id) async => removed.add(id);

  @override
  Future<void> updateRole(String id, String role) async => roles[id] = role;

  @override
  Future<void> reorder(String parentId, List<String> orderedIds) async =>
      reorders.add(orderedIds);

  @override
  Future<List<String>> distinctRoles() async => const ['Necklace', 'Primary'];
}

/// How many logged dives carry the assembly, as the history dialog reads it
/// from the dive repository. The real one logs and rethrows on a failure.
class DiveCount {
  int diveCount = 0;
  Object? throwOnCount;
}

/// Stands in for anything else that reads the equipment repository.
class FakeEquipmentRepository extends EquipmentRepository {}

/// DiveRepository only has a factory, so a Fake stands in for it.
class FakeDiveRepository extends Fake implements DiveRepository {
  final rewrites = <(String, List<GearHistoryRewrite>, bool)>[];
  DiveCount count = DiveCount();
  Object? throwOnRewrite;

  @override
  Future<int> countLoggedDivesWithAssembly(String assemblyId) async {
    if (count.throwOnCount != null) throw count.throwOnCount!;
    return count.diveCount;
  }

  @override
  Future<List<String>> rewriteAssemblyOnDives(
    String assemblyId,
    List<GearHistoryRewrite> rewrites_, {
    required bool alsoLogged,
    bool notify = true,
  }) async {
    if (throwOnRewrite != null) throw throwOnRewrite!;
    rewrites.add((assemblyId, rewrites_, alsoLogged));
    return const ['dive'];
  }
}

final t0 = DateTime(2026, 1, 1);

const first = EquipmentItem(
  id: 'first',
  name: 'DGX first stage',
  type: EquipmentType.firstStage,
);
const hose = EquipmentItem(
  id: 'hose',
  name: 'Long hose',
  type: EquipmentType.hose,
  status: EquipmentStatus.retired,
  isActive: false,
);
const spare = EquipmentItem(
  id: 'spare',
  name: 'Spare first stage',
  type: EquipmentType.firstStage,
);

EquipmentComponent part(
  String id,
  EquipmentItem item, {
  String role = '',
  int order = 0,
}) => EquipmentComponent(
  id: id,
  parentEquipmentId: 'reg',
  componentEquipmentId: item.id,
  role: role,
  sortOrder: order,
  createdAt: t0,
  updatedAt: t0,
  component: item,
);

/// "reg" as a part of [assembly], with the rigs above that assembly.
PartOfEntry parentEntry(
  EquipmentItem assembly, {
  String role = '',
  List<String> rigs = const [],
}) => (
  edge: EquipmentComponent(
    id: 'up-${assembly.id}',
    parentEquipmentId: assembly.id,
    componentEquipmentId: 'reg',
    role: role,
    createdAt: t0,
    updatedAt: t0,
    parent: assembly,
  ),
  rootNames: rigs,
);

const card = Scaffold(
  body: SingleChildScrollView(child: ComponentsCard(equipmentId: 'reg')),
);

/// The card open in [session], as the item's page shows it while editing.
Widget openCard(EditSession<EquipmentItem> session) => Scaffold(
  body: SingleChildScrollView(
    child: ComponentsCard(equipmentId: 'reg', editing: session),
  ),
);

/// A sitting on "reg" holding [rows] as its parts, none of them stored.
EditSession<EquipmentItem> sittingWith(List<EquipmentComponent> rows) {
  final session = EditSession(
    const EquipmentItem(id: 'reg', name: 'Reg', type: EquipmentType.regulator),
  );
  addTearDown(session.dispose);
  gearItemComponentsList
    ..loadNone(session)
    ..set(session, rows);
  return session;
}

Widget build(
  List<EquipmentComponent> parts,
  FakeComponentRepository repo, {
  DiveCount? count,
  FakeDiveRepository? dives,
  List<PartOfEntry> partOf = const [],
  Object? partOfError,
  bool routed = false,
  Map<String, DueClock> worst = const {},
  AssemblyTotals? totals,
  Widget home = card,
}) {
  return ProviderScope(
    overrides: [
      // Row labels format a purchase-date tie-break in the diver's format.
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      equipmentComponentRepositoryProvider.overrideWithValue(repo),
      equipmentRepositoryProvider.overrideWithValue(FakeEquipmentRepository()),
      diveRepositoryProvider.overrideWithValue(
        (dives ?? FakeDiveRepository())..count = count ?? DiveCount(),
      ),
      equipmentComponentsProvider('reg').overrideWith((ref) async => parts),
      equipmentPartOfProvider('reg').overrideWith((ref) async {
        if (partOfError != null) throw partOfError;
        return partOf;
      }),
      equipmentComponentsIndexProvider.overrideWith(
        (ref) async => ComponentsIndex.fromRows(parts),
      ),
      // These cards read the rollup now, so a part whose own sub-part is
      // overdue lights up here exactly as it does in the equipment list
      // (#2260). The fixtures still describe DueClocks; convert at the
      // boundary rather than restating every case.
      equipmentRollupClockProvider.overrideWith(
        (ref) async => {
          for (final e in worst.entries)
            e.key: (
              ownerId: e.value.item.id,
              ownerName: e.value.item.name,
              status: e.value.status,
            ),
        },
      ),
      if (totals != null)
        assemblyTotalsProvider('reg').overrideWith((ref) async => totals),
      activeEquipmentProvider.overrideWith(
        (ref) async => const [first, hose, spare],
      ),
    ],
    child: routed
        ? MaterialApp.router(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: GoRouter(
              routes: [
                GoRoute(path: '/', builder: (_, _) => card),
                GoRoute(
                  path: '/equipment/:id',
                  builder: (_, state) =>
                      Text('Detail ${state.pathParameters['id']}'),
                ),
              ],
            ),
          )
        : MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: home,
          ),
  );
}
