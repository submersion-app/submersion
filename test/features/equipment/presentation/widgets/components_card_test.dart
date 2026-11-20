import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_history_rewrite.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/services/assembly_totals.dart';
import 'package:submersion/features/equipment/presentation/providers/assembly_totals_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_totals_section.dart';
import 'package:submersion/features/equipment/presentation/widgets/components_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_components_sitting.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

class _FakeComponentRepository extends EquipmentComponentRepository {
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
class _DiveCount {
  int diveCount = 0;
  Object? throwOnCount;
}

/// Stands in for anything else that reads the equipment repository.
class _FakeEquipmentRepository extends EquipmentRepository {}

/// DiveRepository only has a factory, so a Fake stands in for it.
class _FakeDiveRepository extends Fake implements DiveRepository {
  final rewrites = <(String, List<GearHistoryRewrite>, bool)>[];
  _DiveCount count = _DiveCount();
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

void main() {
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
      const EquipmentItem(
        id: 'reg',
        name: 'Reg',
        type: EquipmentType.regulator,
      ),
    );
    addTearDown(session.dispose);
    gearItemComponentsList
      ..loadNone(session)
      ..set(session, rows);
    return session;
  }

  Widget build(
    List<EquipmentComponent> parts,
    _FakeComponentRepository repo, {
    _DiveCount? count,
    _FakeDiveRepository? dives,
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
        equipmentRepositoryProvider.overrideWithValue(
          _FakeEquipmentRepository(),
        ),
        diveRepositoryProvider.overrideWithValue(
          (dives ?? _FakeDiveRepository())..count = count ?? _DiveCount(),
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

  // Issue #4527, phase 3: a part added in the item's sitting and removed
  // again was never on a dive, so there is nothing to ask about.
  testWidgets('in a sitting, removing a part added in it asks nothing', (
    tester,
  ) async {
    final session = EditSession(
      const EquipmentItem(
        id: 'reg',
        name: 'Reg',
        type: EquipmentType.regulator,
      ),
    );
    addTearDown(session.dispose);
    gearItemComponentsList.loadNone(session);
    gearItemComponentsList.set(session, [part('held', hose)]);
    await tester.pumpWidget(
      build(
        const [],
        _FakeComponentRepository(),
        count: _DiveCount()..diveCount = 3,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ComponentsCard(equipmentId: 'reg', editing: session),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(hose.name), findsOneWidget);

    await tester.tap(find.byTooltip('Remove component'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(hose.name), findsNothing);
    expect(session.hasHeldWrites, isFalse);
  });

  testWidgets('ends with what the parts add up to (#4443)', (tester) async {
    await tester.pumpWidget(
      build(
        [part('a', first)],
        _FakeComponentRepository(),
        totals: const AssemblyTotals(
          partCount: 1,
          buoyancy: (kg: -4.0, parts: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AssemblyTotalsSection), findsOneWidget);
    expect(find.text('-4 kg'), findsOneWidget);
  });

  group('part of', () {
    const cold = EquipmentItem(
      id: 'cold',
      name: 'Cold water reg',
      type: EquipmentType.regulator,
    );
    const travel = EquipmentItem(
      id: 'travel',
      name: 'Travel reg',
      type: EquipmentType.regulator,
    );
    const old = EquipmentItem(
      id: 'old',
      name: 'Old reg',
      type: EquipmentType.regulator,
      status: EquipmentStatus.retired,
      isActive: false,
    );

    testWidgets('an item that is part of nothing keeps the plain card', (
      tester,
    ) async {
      await tester.pumpWidget(build(const [], _FakeComponentRepository()));
      await tester.pumpAndSettle();
      expect(find.text('Part of'), findsNothing);
      expect(find.text('Contains'), findsNothing);
      expect(find.textContaining('No components'), findsOneWidget);
    });

    testWidgets('lists each parent with its role and every rig above it', (
      tester,
    ) async {
      await tester.pumpWidget(
        build(
          [part('c1', first, role: 'Primary')],
          _FakeComponentRepository(),
          partOf: [
            parentEntry(cold),
            parentEntry(
              travel,
              role: 'Octopus',
              rigs: ['Backmount rig', 'Sidemount rig'],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Part of'), findsOneWidget);
      expect(find.text('Contains'), findsOneWidget);
      expect(find.text('Cold water reg'), findsOneWidget);
      // No role falls back to the parent's type; a top-level parent has no
      // rig line.
      expect(find.text('Regulator'), findsOneWidget);
      expect(
        find.text('Octopus, in Backmount rig, Sidemount rig'),
        findsOneWidget,
      );
      // The item's own parts still follow under Contains.
      expect(find.text('DGX first stage'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Travel reg')).dy,
        lessThan(tester.getTopLeft(find.text('Contains')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Contains')).dy,
        lessThan(tester.getTopLeft(find.text('DGX first stage')).dy),
      );
    });

    testWidgets('a retired parent is listed with its status', (tester) async {
      await tester.pumpWidget(
        build(
          const [],
          _FakeComponentRepository(),
          partOf: [parentEntry(old, role: 'Octopus')],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Old reg'), findsOneWidget);
      expect(find.text('Retired'), findsOneWidget);
    });

    testWidgets('a sold parent keeps its Sold status, not Retired', (
      tester,
    ) async {
      const sold = EquipmentItem(
        id: 'sold',
        name: 'Sold reg',
        type: EquipmentType.regulator,
        status: EquipmentStatus.sold,
        isActive: false,
      );
      await tester.pumpWidget(
        build(
          const [],
          _FakeComponentRepository(),
          partOf: [parentEntry(sold, role: 'Octopus')],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sold'), findsOneWidget);
      expect(find.text('Retired'), findsNothing);
    });

    testWidgets('a part with nothing of its own says so, not "no components"', (
      tester,
    ) async {
      // In the open card, which offers to add one.
      await tester.pumpWidget(
        build(
          const [],
          _FakeComponentRepository(),
          partOf: [parentEntry(cold)],
          home: openCard(sittingWith(const [])),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No parts of its own'), findsOneWidget);
      expect(find.textContaining('No components'), findsNothing);
      expect(find.text('Add component'), findsOneWidget);
    });

    testWidgets('a parent row opens that assembly and has no edit actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        build(
          const [],
          _FakeComponentRepository(),
          partOf: [parentEntry(travel, role: 'Octopus')],
          routed: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      await tester.tap(find.text('Travel reg'));
      await tester.pumpAndSettle();
      expect(find.text('Detail travel'), findsOneWidget);
    });

    testWidgets('a failed upward read is shown, and the parts still render', (
      tester,
    ) async {
      await tester.pumpWidget(
        build(
          [part('c1', first)],
          _FakeComponentRepository(),
          partOfError: StateError('no database'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Something went wrong'), findsOneWidget);
      expect(find.text('DGX first stage'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('row labels (#2791)', () {
    /// An item that may carry an identifier, brand and model, or a serial.
    EquipmentItem gear(
      String id,
      String name,
      EquipmentType type, {
      String? identifier,
      String? brand,
      String? model,
      String? serial,
    }) => EquipmentItem(
      id: id,
      name: name,
      type: type,
      brand: brand,
      model: model,
      serialNumber: serial,
      attributes: [
        if (identifier != null)
          EquipmentAttribute.curated(
            equipmentId: id,
            key: EquipmentAttrKeys.identifier,
            valueText: identifier,
          ),
      ],
    );

    testWidgets('a part shows its identifier after its role', (tester) async {
      await tester.pumpWidget(
        build([
          part(
            'c1',
            gear(
              'z1',
              'HOG Zenith',
              EquipmentType.secondStage,
              identifier: 'Necklace',
            ),
            role: 'Second Stage',
          ),
          part(
            'c2',
            gear(
              'z2',
              'HOG Zenith',
              EquipmentType.secondStage,
              identifier: 'Primary',
            ),
            role: 'Second Stage',
            order: 1,
          ),
        ], _FakeComponentRepository()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Second Stage · ID Necklace'), findsOneWidget);
      expect(find.text('Second Stage · ID Primary'), findsOneWidget);
    });

    testWidgets(
      'the label wraps rather than hiding the identifier on a phone',
      (tester) async {
        final rows = [
          part(
            'c1',
            gear(
              'z1',
              'HOG Zenith',
              EquipmentType.secondStage,
              brand: 'Halcyon',
              model: 'Zenith Pro',
              identifier: 'Necklace left',
            ),
            role: 'Second Stage',
          ),
        ];
        tester.view.devicePixelRatio = 1.0;
        // About 320 px of label beside the action icons. The label below
        // needs more than one line there whether the test font (every glyph
        // a full em wide) or a real one loaded by another bundled test file
        // draws it, so a one-line label always fails this.
        tester.view.physicalSize = const Size(600, 800);
        addTearDown(tester.view.reset);
        // In the open card, where the action icons take their room.
        await tester.pumpWidget(
          build(
            rows,
            _FakeComponentRepository(),
            home: openCard(sittingWith(rows)),
          ),
        );
        await tester.pumpAndSettle();
        // find.text matches an ellipsized line too, so ask the paragraph
        // whether it had to cut the label short.
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text('Second Stage · Halcyon Zenith Pro · ID Necklace left'),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
      },
    );

    testWidgets('a part with no role shows its type, then its identifier', (
      tester,
    ) async {
      await tester.pumpWidget(
        build([
          part(
            'c1',
            gear('sw', 'Swift', EquipmentType.transmitter, identifier: 'Bill'),
          ),
        ], _FakeComponentRepository()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Transmitter · ID Bill'), findsOneWidget);
    });

    testWidgets('brand and model show when they differ from the name', (
      tester,
    ) async {
      await tester.pumpWidget(
        build([
          part(
            'c1',
            gear(
              'd3',
              'Yoke first',
              EquipmentType.firstStage,
              brand: 'HOG',
              model: 'D3',
              identifier: 'YOKE',
            ),
            role: 'First Stage',
          ),
        ], _FakeComponentRepository()),
      );
      await tester.pumpAndSettle();
      expect(find.text('First Stage · HOG D3 · ID YOKE'), findsOneWidget);
    });

    testWidgets('identical parts are told apart by their serials', (
      tester,
    ) async {
      await tester.pumpWidget(
        build([
          part(
            'c1',
            gear('h1', 'MP hose', EquipmentType.hose, serial: 'A1'),
            role: 'Hose',
          ),
          part(
            'c2',
            gear('h2', 'MP hose', EquipmentType.hose, serial: 'B2'),
            role: 'Hose',
            order: 1,
          ),
        ], _FakeComponentRepository()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hose · S/N A1'), findsOneWidget);
      expect(find.text('Hose · S/N B2'), findsOneWidget);
    });

    testWidgets('parts already told apart by their roles get no tie-break', (
      tester,
    ) async {
      await tester.pumpWidget(
        build([
          part(
            'c1',
            gear('z1', 'HOG Zenith', EquipmentType.secondStage, serial: 'A1'),
            role: 'Primary',
          ),
          part(
            'c2',
            gear('z2', 'HOG Zenith', EquipmentType.secondStage, serial: 'B2'),
            role: 'Octopus',
            order: 1,
          ),
        ], _FakeComponentRepository()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('Octopus'), findsOneWidget);
      expect(find.textContaining('S/N'), findsNothing);
    });

    testWidgets('a departed part keeps its badge beside the label', (
      tester,
    ) async {
      await tester.pumpWidget(
        build([
          part(
            'c1',
            EquipmentItem(
              id: 'old',
              name: 'Old hose',
              type: EquipmentType.hose,
              status: EquipmentStatus.retired,
              isActive: false,
              attributes: [
                EquipmentAttribute.curated(
                  equipmentId: 'old',
                  key: EquipmentAttrKeys.identifier,
                  valueText: 'H1',
                ),
              ],
            ),
          ),
        ], _FakeComponentRepository()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hose · ID H1'), findsOneWidget);
      expect(find.text('Retired'), findsOneWidget);
    });

    testWidgets('parents already told apart by their rigs get no tie-break', (
      tester,
    ) async {
      await tester.pumpWidget(
        build(
          const [],
          _FakeComponentRepository(),
          partOf: [
            parentEntry(
              gear(
                'ra1',
                'Regulator Assembly',
                EquipmentType.regulator,
                serial: 'R1',
              ),
              role: 'Second Stage',
              rigs: ['Backmount rig'],
            ),
            parentEntry(
              gear(
                'ra2',
                'Regulator Assembly',
                EquipmentType.regulator,
                serial: 'R2',
              ),
              role: 'Second Stage',
              rigs: ['Sidemount rig'],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Second Stage, in Backmount rig'), findsOneWidget);
      expect(find.text('Second Stage, in Sidemount rig'), findsOneWidget);
      expect(find.textContaining('S/N'), findsNothing);
    });

    testWidgets('a parent assembly shows its identifier too', (tester) async {
      await tester.pumpWidget(
        build(
          const [],
          _FakeComponentRepository(),
          partOf: [
            parentEntry(
              gear(
                'ra1',
                'Regulator Assembly',
                EquipmentType.regulator,
                identifier: 'Yoke',
              ),
              role: 'Second Stage',
            ),
            parentEntry(
              gear(
                'ra2',
                'Regulator Assembly',
                EquipmentType.regulator,
                identifier: 'DIN',
              ),
              role: 'Second Stage',
              rigs: ['Sidemount rig'],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Second Stage · ID Yoke'), findsOneWidget);
      expect(
        find.text('Second Stage, in Sidemount rig · ID DIN'),
        findsOneWidget,
      );
    });
  });

  testWidgets('the open card\'s empty state shows the prompt and the add '
      'button', (tester) async {
    await tester.pumpWidget(
      build(
        const [],
        _FakeComponentRepository(),
        home: openCard(sittingWith(const [])),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Components'), findsOneWidget);
    expect(find.textContaining('No components'), findsOneWidget);
    expect(find.text('Add component'), findsOneWidget);
  });

  testWidgets('renders one row per part with role, and a retired badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      build([
        part('c1', first, role: 'Primary', order: 0),
        part('c2', hose, order: 1),
      ], _FakeComponentRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.text('DGX first stage'), findsOneWidget);
    expect(find.text('Primary'), findsOneWidget);
    expect(find.text('Long hose'), findsOneWidget);
    // A part with no role falls back to its type label.
    expect(find.text('Hose'), findsOneWidget);
    expect(find.text('Retired'), findsOneWidget);
  });

  testWidgets('with no sitting the card offers no add, replace, remove, role '
      'edit or drag', (tester) async {
    await tester.pumpWidget(
      build([
        part('c1', first, role: 'Primary', order: 0),
        part('c2', hose, order: 1),
      ], _FakeComponentRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.text('DGX first stage'), findsOneWidget);
    expect(find.text('Add component'), findsNothing);
    expect(find.byTooltip('Replace component'), findsNothing);
    expect(find.byTooltip('Remove component'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
  });

  testWidgets('a part with a clock coming due gets the warn dot', (
    tester,
  ) async {
    final dueSoon = (
      item: first,
      status: ServiceClockStatus(
        schedule: ServiceSchedule(
          id: 's1',
          equipmentId: first.id,
          serviceKindId: 'annual',
          createdAt: t0,
          updatedAt: t0,
        ),
        kind: ServiceKind(
          id: 'annual',
          name: 'Annual service',
          createdAt: t0,
          updatedAt: t0,
        ),
        anchor: t0,
        dueDate: t0.add(const Duration(days: 360)),
        severity: ServiceClockSeverity.dueSoon,
        now: t0.add(const Duration(days: 340)),
      ),
    );
    await tester.pumpWidget(
      build(
        [part('c1', first, order: 0), part('c2', spare, order: 1)],
        _FakeComponentRepository(),
        worst: {first.id: dueSoon},
      ),
    );
    await tester.pumpAndSettle();

    final dots = tester
        .widgetList<Icon>(find.byIcon(Icons.circle))
        .map((d) => d.color)
        .toList();
    expect(dots, contains(StatusColors.light.warn.accent));
    expect(dots, isNot(contains(StatusColors.light.alert.accent)));
  });

  testWidgets('a sold part keeps its Sold status, not Retired', (tester) async {
    const sold = EquipmentItem(
      id: 'sold',
      name: 'Sold hose',
      type: EquipmentType.hose,
      status: EquipmentStatus.sold,
      isActive: false,
    );
    await tester.pumpWidget(
      build([part('c1', sold)], _FakeComponentRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sold'), findsOneWidget);
    expect(find.text('Retired'), findsNothing);
  });

  testWidgets('a lost part still marked active is badged Lost', (tester) async {
    const lost = EquipmentItem(
      id: 'lost',
      name: 'Lost torch',
      type: EquipmentType.light,
      status: EquipmentStatus.lost,
    );
    await tester.pumpWidget(
      build([part('c1', lost)], _FakeComponentRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lost'), findsOneWidget);
  });

  testWidgets('a drag reorders the rows at once and holds the order', (
    tester,
  ) async {
    final repo = _FakeComponentRepository();
    final rows = [
      part('c1', first, role: 'Primary', order: 0),
      part('c2', hose, order: 1),
    ];
    final session = sittingWith(rows);
    await tester.pumpWidget(build(rows, repo, home: openCard(session)));
    await tester.pumpAndSettle();
    final handles = find.byIcon(Icons.drag_handle);
    expect(handles, findsNWidgets(2));
    final firstBefore = tester.getTopLeft(find.text('DGX first stage')).dy;
    final hoseBefore = tester.getTopLeft(find.text('Long hose')).dy;
    expect(firstBefore, lessThan(hoseBefore));

    // Drag the first row's handle below the second row. The handle is a
    // ReorderableDragStartListener, so the drag starts on touch-down.
    final drag = await tester.startGesture(tester.getCenter(handles.first));
    await tester.pump();
    // A row is about 72 px tall; the dragged row must travel past the next
    // row's midpoint before the list commits the swap, so go well beyond.
    for (var i = 0; i < 10; i++) {
      await drag.moveBy(const Offset(0, 16));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await tester.pumpAndSettle();

    // The rows swapped, and the new order is held in the sitting until
    // Save rather than written.
    expect(
      tester.getTopLeft(find.text('Long hose')).dy,
      lessThan(tester.getTopLeft(find.text('DGX first stage')).dy),
    );
    expect(gearItemComponentsList.current(session)!.map((p) => p.id), [
      'c2',
      'c1',
    ]);
    expect(repo.reorders, isEmpty);
  });

  // The parts as stored, read into the open card's sitting: removing one
  // asks "Update past dives?", and both the removal and the answer wait for
  // Save, which writes through the fakes here.
  group('removing a stored part in a sitting', () {
    late _FakeComponentRepository repo;
    late _FakeDiveRepository dives;
    late EditSession<EquipmentItem> session;
    late EquipmentComponent stored;

    setUp(() async {
      await setUpTestDatabase();
      addTearDown(SyncCoordinator.reset);
      repo = _FakeComponentRepository();
      dives = _FakeDiveRepository();
      const reg = EquipmentItem(
        id: 'reg',
        name: 'Reg',
        type: EquipmentType.regulator,
      );
      final items = EquipmentRepository();
      for (final item in const [reg, first]) {
        await items.createEquipment(item);
      }
      await EquipmentComponentRepository().addComponent(
        parentId: 'reg',
        componentId: 'first',
      );
      session = EditSession(reg);
      addTearDown(session.dispose);
      T read<T>(ProviderListenable<T> provider) =>
          (identical(provider, equipmentComponentRepositoryProvider)
                  ? repo
                  : identical(provider, diveRepositoryProvider)
                  ? dives
                  : throw ArgumentError('$provider'))
              as T;
      holdGearItemComponents(session, read);
      await gearItemComponentsList.currentOrRead(session);
      stored = gearItemComponentsList.loaded(session)!.single;
    });
    tearDown(tearDownTestDatabase);

    Future<void> pumpOpenCard(WidgetTester tester, {_DiveCount? count}) async {
      await tester.pumpWidget(
        build(
          const [],
          repo,
          count: count,
          dives: dives,
          home: openCard(session),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('DGX first stage'), findsOneWidget);
    }

    testWidgets('with no past dives it asks nothing, and Save rewrites the '
        'planned dives', (tester) async {
      await pumpOpenCard(tester);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('Update past dives?'), findsNothing);
      expect(find.text('DGX first stage'), findsNothing);
      expect(gearItemComponentsList.current(session), isEmpty);
      expect(repo.removed, isEmpty);
      expect(dives.rewrites, isEmpty);

      await session.runHeldWrites();

      expect(repo.removed, [stored.id]);
      // Planned dives still follow the change (issue #4283). Compared field
      // by field: a record holding a List compares that field by identity.
      expect(dives.rewrites.map((r) => r.$3), [true, false]);
      expect(dives.rewrites.first.$2, isEmpty);
      expect(dives.rewrites.last.$2, const [GearPartRemoved('first')]);
    });

    testWidgets('with past dives it asks, and Also update reaches the logged '
        'dives at Save', (tester) async {
      await pumpOpenCard(tester, count: _DiveCount()..diveCount = 2);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('Update past dives?'), findsOneWidget);
      expect(find.textContaining('Remove the part'), findsOneWidget);
      await tester.tap(find.text('Also update 2 dives'));
      await tester.pumpAndSettle();
      expect(gearItemComponentsList.current(session), isEmpty);
      expect(repo.removed, isEmpty);
      expect(dives.rewrites, isEmpty);

      await session.runHeldWrites();

      expect(repo.removed, [stored.id]);
      expect(dives.rewrites.map((r) => (r.$1, r.$3)), [
        ('reg', true),
        ('reg', false),
      ]);
      expect(dives.rewrites.first.$2, const [GearPartRemoved('first')]);
      expect(dives.rewrites.last.$2, isEmpty);
    });

    testWidgets('From now on holds the removal for the planned dives only', (
      tester,
    ) async {
      await pumpOpenCard(tester, count: _DiveCount()..diveCount = 2);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('From now on'));
      await tester.pumpAndSettle();
      expect(gearItemComponentsList.current(session), isEmpty);
      expect(repo.removed, isEmpty);

      await session.runHeldWrites();

      expect(repo.removed, [stored.id]);
      expect(dives.rewrites.map((r) => r.$3), [true, false]);
      expect(dives.rewrites.first.$2, isEmpty);
      expect(dives.rewrites.last.$2, const [GearPartRemoved('first')]);
    });

    testWidgets('a failed dive count is reported, and removes nothing', (
      tester,
    ) async {
      await pumpOpenCard(
        tester,
        count: _DiveCount()..throwOnCount = StateError('no database'),
      );
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('Update past dives?'), findsNothing);
      expect(find.textContaining('no database'), findsOneWidget);
      expect(gearItemComponentsList.current(session), [stored]);
      expect(session.hasHeldWrites, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelling the question changes nothing', (tester) async {
      await pumpOpenCard(tester, count: _DiveCount()..diveCount = 2);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('DGX first stage'), findsOneWidget);
      expect(gearItemComponentsList.current(session), [stored]);
      expect(session.hasHeldWrites, isFalse);
      expect(repo.removed, isEmpty);
      expect(dives.rewrites, isEmpty);
    });
  });

  testWidgets('the replace icon opens the picker in single-select mode', (
    tester,
  ) async {
    final rows = [part('c1', first)];
    await tester.pumpWidget(
      build(
        rows,
        _FakeComponentRepository(),
        home: openCard(sittingWith(rows)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Replace component'));
    await tester.pumpAndSettle();
    expect(find.text('Replace with'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Replace'), findsOneWidget);
    // The row being replaced is a current part, so it is not a candidate,
    // while the spare of the same type is.
    expect(find.text('Spare first stage'), findsOneWidget);
    expect(find.text('DGX first stage'), findsOneWidget);
  });

  testWidgets('the edit icon opens the role dialog and holds the new role', (
    tester,
  ) async {
    final repo = _FakeComponentRepository();
    final rows = [part('c1', first, role: 'Primary')];
    final session = sittingWith(rows);
    await tester.pumpWidget(build(rows, repo, home: openCard(session)));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Component role'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Backup');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(gearItemComponentsList.current(session)!.single.role, 'Backup');
    expect(find.text('Backup'), findsOneWidget);
    expect(repo.roles, isEmpty);
  });
}
