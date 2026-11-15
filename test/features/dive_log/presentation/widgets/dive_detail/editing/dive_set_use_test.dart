import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_set_use.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_rules.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/services/set_bundle_loader.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/set_bundle.dart';
import 'package:submersion/features/equipment/presentation/providers/set_bundle_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/test_database.dart';

class _Loader implements SetBundleLoader {
  _Loader(this.bundles);
  final Map<String, SetBundle> bundles;

  @override
  Future<List<SetBundle>> load(List<String> setIds) async => [
    for (final id in setIds) ?bundles[id],
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Using an equipment set during a sitting: its gear, weights and
/// cylinders (issue #4525, #4527).
void main() {
  final l = AppLocalizationsEn();
  final t0 = DateTime.utc(2026, 3, 9);
  const wing = EquipmentItem(
    id: 'wing',
    name: 'Wing',
    type: EquipmentType.wing,
  );
  const fins = EquipmentItem(
    id: 'fins',
    name: 'Fins',
    type: EquipmentType.fins,
  );
  final warm = EquipmentSet(
    id: 'warm',
    name: 'Warm water',
    equipmentIds: const ['wing'],
    includedSetIds: const ['inner'],
    createdAt: t0,
    updatedAt: t0,
  );
  final bundle = SetBundle(
    setId: 'warm',
    gearIds: const ['wing'],
    weights: const [
      (weightType: WeightType.integrated, amountKg: 4.0, notes: '', label: ''),
    ],
    cylinders: [
      CylinderConfigItem(
        id: 'c1',
        configId: 'cfg',
        tankRole: TankRole.backGas,
        volumeL: 11.1,
        workingPressureBar: 207,
        createdAt: t0,
        updatedAt: t0,
      ),
    ],
  );
  final bare = Dive(id: 'dive', dateTime: t0);
  const belt = DiveWeight(
    id: 'w',
    diveId: 'dive',
    weightType: WeightType.belt,
    amountKg: 6,
  );
  const ownTank = DiveTank(
    id: 't',
    volume: 12,
    workingPressure: 232,
    role: TankRole.backGas,
  );

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  late BuildContext context;
  late WidgetRef ref;

  Future<void> pumpHost(
    WidgetTester tester, {
    Map<String, SetBundle> loaded = const {},
    ValueListenable<bool>? shown,
    Future<String?>? diverId,
  }) async {
    final host = Consumer(
      builder: (c, r, _) {
        context = c;
        ref = r;
        return const SizedBox();
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) => diverId ?? Future<String?>.value(),
          ),
          setBundleProvider('warm').overrideWith((ref) async => bundle),
          setBundleLoaderProvider.overrideWithValue(_Loader(loaded)),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: shown == null
                ? host
                : ValueListenableBuilder<bool>(
                    valueListenable: shown,
                    builder: (_, on, _) => on ? host : const SizedBox(),
                  ),
          ),
        ),
      ),
    );
  }

  /// Starts using [warm] and lets it run, answering dialogs with [answer].
  Future<SetUseResult?> use(
    WidgetTester tester,
    EditSession<Dive> session, {
    bool auto = false,
    String? answer,
    void Function()? whileAsked,
  }) async {
    late Future<SetUseResult?> running;
    await tester.runAsync(() async {
      running = useSetInSitting(
        session,
        warm,
        read: ref.read,
        questions: SetUseQuestions.dialogs(
          context,
          const UnitFormatter(AppSettings()),
        ),
        const [wing],
        auto: auto,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    whileAsked?.call();
    if (answer != null) {
      await tester.tap(find.text(answer));
      await tester.pumpAndSettle();
    }
    SetUseResult? result;
    await tester.runAsync(() async {
      result = await running;
    });
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('a set brings gear, weights and cylinders: three cards change', (
    tester,
  ) async {
    await pumpHost(tester);
    final s = EditSession(bare);

    final result = await use(tester, s);

    final w = s.working;
    expect(
      [for (final g in w.gear) (g.item.id, g.viaSetId)],
      [('wing', 'warm')],
    );
    expect(w.weights.single.amountKg, 4);
    expect(w.tanks.single.volume, 11.1);
    expect(s.changedCardIds, {'equipment', 'weights', 'tanks'});
    expect(result!.before.gear, isEmpty);
    expect(result.after.weights, w.weights);
  });

  testWidgets('weights already on the dive ask add, replace or keep', (
    tester,
  ) async {
    await pumpHost(tester);
    final s = EditSession(bare.copyWith(weights: const [belt]));

    await use(tester, s, answer: l.diveLog_edit_setWeights_add);

    expect([for (final w in s.working.weights) w.amountKg], [6.0, 4.0]);
  });

  testWidgets('keep leaves the weights', (tester) async {
    await pumpHost(tester);
    final s = EditSession(bare.copyWith(weights: const [belt]));

    await use(tester, s, answer: l.diveLog_edit_setWeights_keep);

    expect(s.working.weights, const [belt]);
  });

  testWidgets('cylinders it would overwrite ask; declining keeps gear and '
      'weights', (tester) async {
    await pumpHost(tester);
    final s = EditSession(bare.copyWith(tanks: const [ownTank]));

    await use(tester, s, answer: l.common_action_cancel);

    expect(s.working.tanks, const [ownTank]);
    expect(s.working.gear, hasLength(1));
    expect(s.working.weights, hasLength(1));
  });

  testWidgets('confirming the overwrite keeps a cylinder that came while it '
      'was asked', (tester) async {
    await pumpHost(tester);
    final s = EditSession(bare.copyWith(tanks: const [ownTank]));
    const arrived = DiveTank(
      id: 'arrived',
      volume: 7,
      role: TankRole.stage,
      order: 1,
    );

    await use(
      tester,
      s,
      answer: l.cylinderConfigs_overwriteConfirm,
      whileAsked: () => setTanks(s, [...s.working.tanks, arrived]),
    );

    expect([for (final t in s.working.tanks) t.id], contains('arrived'));
    expect(s.working.tanks.first.volume, 11.1);
  });

  testWidgets('auto asks nothing and overwrites nothing', (tester) async {
    await pumpHost(tester);
    final s = EditSession(
      bare.copyWith(weights: const [belt], tanks: const [ownTank]),
    );

    await use(tester, s, auto: true);

    expect(find.byType(AlertDialog), findsNothing);
    expect(s.working.tanks, const [ownTank]);
    expect(s.working.weights, const [belt]);
    expect(s.working.gear, hasLength(1));
  });

  testWidgets('a set included in one on the dive is absorbed', (tester) async {
    await pumpHost(tester, loaded: {'inner': const SetBundle(setId: 'inner')});
    final s = EditSession(
      bare.copyWith(
        gear: const [GearLink(item: fins, viaSetId: 'inner')],
      ),
    );

    await use(tester, s);

    expect(
      [for (final g in s.working.gear) (g.item.id, g.viaSetId)],
      [('fins', 'warm'), ('wing', 'warm')],
    );
  });

  testWidgets('cancelled while the bundle loads: nothing is set', (
    tester,
  ) async {
    await pumpHost(tester);
    final s = EditSession(bare);
    late Future<SetUseResult?> running;
    await tester.runAsync(() async {
      running = useSetInSitting(
        s,
        warm,
        read: ref.read,
        questions: SetUseQuestions.dialogs(
          context,
          const UnitFormatter(AppSettings()),
        ),
        const [wing],
        auto: false,
      );
    });
    s.dispose();
    await tester.runAsync(() async => running);
    expect(s.working.gear, isEmpty);
    expect(s.working.weights, isEmpty);
  });

  testWidgets('the card that asked closing does not stop the use: the set '
      'still goes on', (tester) async {
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    final diver = Completer<String?>();
    await pumpHost(tester, shown: shown, diverId: diver.future);
    final container = ProviderScope.containerOf(context, listen: false);
    final s = EditSession(bare);
    late Future<SetUseResult?> running;
    await tester.runAsync(() async {
      running = useSetInSitting(
        s,
        warm,
        read: container.read,
        questions: SetUseQuestions.dialogs(
          context,
          const UnitFormatter(AppSettings()),
        ),
        const [wing],
        auto: false,
      );
    });
    // Done on the card while its gear is being read.
    shown.value = false;
    await tester.pump();
    diver.complete(null);
    await tester.runAsync(() async {
      await running;
      await s.settled();
    });

    final w = s.working;
    expect([for (final g in w.gear) g.item.id], ['wing']);
    expect(w.weights.single.amountKg, 4);
    expect(w.tanks.single.volume, 11.1);
  });
}
