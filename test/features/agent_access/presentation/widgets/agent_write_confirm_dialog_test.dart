import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/agent_access/domain/write_confirmer.dart';
import 'package:submersion/features/agent_access/presentation/providers/agent_write_providers.dart';
import 'package:submersion/features/agent_access/presentation/widgets/agent_write_confirm_dialog.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

final _now = DateTime.utc(2026, 11, 2);

PlanItem _item({
  String id = 'd1',
  String? title,
  Map<String, FieldChange> fields = const {},
  ChangeKind kind = ChangeKind.update,
}) => PlanItem(
  operation: 0,
  kind: kind,
  entity: 'dives',
  id: id,
  diverId: 'diver-a',
  title: title,
  fields: fields,
);

WriteConfirmation _request({
  String? client = 'Test Agent',
  List<PlanItem>? items,
}) => WriteConfirmation(
  clientName: client,
  label: 'Fix buddy names',
  countsByEntity: const {'dives': 40, 'sites': 2},
  countsByDiver: const {'diver-a': 41, 'diver-b': 1},
  items:
      items ??
      [
        _item(
          title: 'Morning dive',
          fields: const {'water_temp_c': FieldChange(12.0, 24.0)},
        ),
      ],
);

final _divers = [
  Diver(id: 'diver-a', name: 'Ana', createdAt: _now, updatedAt: _now),
  Diver(id: 'diver-b', name: 'Rui', createdAt: _now, updatedAt: _now),
];

const _tables = {'dives': 'dives', 'sites': 'dive_sites'};

GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

Future<void> _pump(
  WidgetTester tester, {
  Widget? home,
  AppSettings settings = const AppSettings(),
  double textScale = 1,
}) async {
  final overrides = await getBaseOverrides(
    settingsNotifier: MockSettingsNotifier(settings),
  );
  _navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        allDiversProvider.overrideWith((ref) async => _divers),
      ],
      child: MaterialApp(
        navigatorKey: _navigator,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home ?? const Scaffold(body: SizedBox.shrink()),
      ),
    ),
  );
  await tester.pump();
}

AppWriteConfirmer _confirmer({
  Duration timeout = const Duration(minutes: 5),
  BuildContext? Function()? context,
  Future<void> Function()? raise,
}) => AppWriteConfirmer(
  context: context ?? () => _navigator.currentContext,
  timeout: timeout,
  raiseWindow: raise ?? () async {},
  entityTables: _tables,
);

Finder get _allow => find.byKey(AgentWriteConfirmDialog.allowKey);
Finder get _deny => find.byKey(AgentWriteConfirmDialog.denyKey);

/// Taps Allow once it has had time to arm.
Future<void> _tapAllow(WidgetTester tester) async {
  await tester.pump(kAgentWriteAllowDelay);
  await tester.tap(_allow);
}

/// Answers the open dialog, so its timeout does not outlive the test.
Future<void> _close(WidgetTester tester) async {
  await tester.tap(_deny);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the client, label and counts', (tester) async {
    await _pump(tester);
    unawaited(
      _confirmer().confirm(
        _request(items: [for (var i = 0; i < 40; i++) _item(id: 'd$i')]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Test Agent'), findsOneWidget);
    expect(find.text('Fix buddy names'), findsOneWidget);
    expect(find.textContaining('40'), findsOneWidget);
    expect(find.textContaining('Ana'), findsOneWidget);
    expect(find.textContaining('Rui'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('names an unknown client generically', (tester) async {
    await _pump(tester);
    unawaited(_confirmer().confirm(_request(client: null)));
    await tester.pumpAndSettle();

    expect(find.textContaining('An agent'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('Allow answers true', (tester) async {
    await _pump(tester);
    final answer = _confirmer().confirm(_request());
    await tester.pumpAndSettle();

    await _tapAllow(tester);
    await tester.pumpAndSettle();

    expect(await answer, isTrue);
    expect(_allow, findsNothing);
  });

  testWidgets('Deny answers false', (tester) async {
    await _pump(tester);
    final answer = _confirmer().confirm(_request());
    await tester.pumpAndSettle();

    await tester.tap(_deny);
    await tester.pumpAndSettle();

    expect(await answer, isFalse);
  });

  testWidgets('barrier dismiss is off', (tester) async {
    await _pump(tester);
    unawaited(_confirmer().confirm(_request()));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();

    expect(_allow, findsOneWidget);
    await _close(tester);
  });

  testWidgets('timeout closes the dialog and answers false', (tester) async {
    await _pump(tester);
    final answer = _confirmer(
      timeout: const Duration(minutes: 5),
    ).confirm(_request());
    await tester.pumpAndSettle();
    expect(_allow, findsOneWidget);

    await tester.pump(const Duration(minutes: 5, seconds: 1));
    await tester.pumpAndSettle();

    expect(_allow, findsNothing);
    expect(await answer, isFalse);
  });

  testWidgets('a timeout leaves a dialog above it alone', (tester) async {
    await _pump(tester);
    final answer = _confirmer(
      timeout: const Duration(seconds: 30),
    ).confirm(_request());
    await tester.pumpAndSettle();
    unawaited(
      showDialog<void>(
        context: _navigator.currentContext!,
        builder: (_) => const AlertDialog(content: Text('Quit Submersion?')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();

    expect(find.text('Quit Submersion?'), findsOneWidget);
    expect(await answer, isFalse);
  });

  testWidgets('a second request while one is open is refused', (tester) async {
    await _pump(tester);
    final confirmer = _confirmer();
    final first = confirmer.confirm(_request());
    await tester.pumpAndSettle();

    await expectLater(
      confirmer.confirm(_request()),
      throwsA(
        isA<AgentToolException>()
            .having(
              (e) => e.code,
              'code',
              AgentToolErrorCode.confirmationPending,
            )
            // apply_changes has used the plan up by now, so a retry of the
            // same plan_id could only fail.
            .having((e) => e.message, 'message', contains('preview_changes')),
      ),
    );

    await _tapAllow(tester);
    await tester.pumpAndSettle();
    expect(await first, isTrue);

    final next = confirmer.confirm(_request());
    await tester.pumpAndSettle();
    await tester.tap(_deny);
    await tester.pumpAndSettle();
    expect(await next, isFalse);
  });

  testWidgets('a delete says so without opening the details', (tester) async {
    await _pump(tester);
    unawaited(
      _confirmer().confirm(
        _request(
          items: [
            _item(kind: ChangeKind.delete),
            _item(id: 'd2', kind: ChangeKind.delete),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Delete'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('a merge reads as merge into the survivor and lists what moves', (
    tester,
  ) async {
    await _pump(tester);
    unawaited(
      _confirmer().confirm(
        _request(
          items: [
            const PlanItem(
              operation: 0,
              kind: ChangeKind.delete,
              entity: 'tags',
              id: 'wrecks',
              diverId: 'diver-a',
              title: 'Wrecks',
              mergeInto: 'wreck',
              mergeTitle: 'Wreck',
              reach: DeleteReach(moved: {'dive_tags': 3}),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AgentWriteConfirmDialog.detailsKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('Merge into Wreck'), findsOneWidget);
    expect(find.textContaining('Moves'), findsWidgets);
    expect(find.textContaining('3'), findsWidgets);
    await _close(tester);
  });

  testWidgets('names the dives a delete reaches on another profile', (
    tester,
  ) async {
    await _pump(tester);
    unawaited(
      _confirmer().confirm(
        _request(
          items: [
            const PlanItem(
              operation: 0,
              kind: ChangeKind.delete,
              entity: 'sites',
              id: 's1',
              diverId: 'diver-a',
              title: 'Blue Hole',
              reach: DeleteReach(
                linkedDives: {'diver-b': 3},
                records: {'documents': 2},
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Rui'), findsWidgets);
    expect(find.textContaining('3'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('shows what a delete unlinks, and keeps its parts in the '
      'details', (tester) async {
    await _pump(tester);
    unawaited(
      _confirmer().confirm(
        _request(
          items: [
            const PlanItem(
              operation: 0,
              kind: ChangeKind.delete,
              entity: 'sites',
              id: 's1',
              diverId: 'diver-a',
              title: 'Blue Hole',
              reach: DeleteReach(
                records: {'documents': 2},
                parts: {'site_tags': 4},
                unlinked: {'dive_plans': 3},
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Also deletes Document: 2'), findsOneWidget);
    expect(find.textContaining('Also unlinks Dive plan: 3'), findsOneWidget);
    expect(find.textContaining('Site Tags: 4'), findsNothing);

    await tester.tap(find.byKey(AgentWriteConfirmDialog.detailsKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('Site Tags: 4'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('a profile it cannot name is not called shared', (tester) async {
    await _pump(tester);
    unawaited(
      _confirmer().confirm(
        WriteConfirmation(
          clientName: 'Test Agent',
          label: 'Fix notes',
          countsByEntity: const {'dives': 2},
          countsByDiver: const {'diver-c': 1, '': 1},
          items: [_item()],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('diver-c: 1'), findsOneWidget);
    expect(find.text('Shared: 1'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('Allow ignores a click before it has armed', (tester) async {
    await _pump(tester);
    final answer = _confirmer().confirm(_request());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(_allow, warnIfMissed: false);
    await tester.pump();
    expect(_allow, findsOneWidget, reason: 'an early click must not answer');

    await _tapAllow(tester);
    await tester.pumpAndSettle();
    expect(await answer, isTrue);
  });

  testWidgets('links show names, not ids', (tester) async {
    await _pump(tester);
    unawaited(
      _confirmer().confirm(
        _request(
          items: [
            const PlanItem(
              operation: 0,
              kind: ChangeKind.update,
              entity: 'dives',
              id: 'd1',
              relations: {
                'buddies': RelationDelta(add: {'uuid-1'}),
              },
              indirectRelations: {
                'types': {'uuid-2'},
              },
              names: {'uuid-1': 'Ana', 'uuid-2': 'Wreck'},
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AgentWriteConfirmDialog.detailsKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ana'), findsWidgets);
    expect(find.textContaining('Wreck'), findsOneWidget);
    expect(find.textContaining('uuid-1'), findsNothing);
    await _close(tester);
  });

  testWidgets('no navigator answers false', (tester) async {
    await _pump(tester);

    final answer = await _confirmer(context: () => null).confirm(_request());

    expect(answer, isFalse);
  });

  testWidgets('raises the window before asking', (tester) async {
    await _pump(tester);
    var raised = 0;
    unawaited(_confirmer(raise: () async => raised++).confirm(_request()));
    await tester.pumpAndSettle();

    expect(raised, 1);
    await _close(tester);
  });

  testWidgets('a window that cannot be raised still asks', (tester) async {
    await _pump(tester);
    unawaited(
      _confirmer(
        raise: () async => throw StateError('no window'),
      ).confirm(_request()),
    );
    await tester.pumpAndSettle();

    expect(_allow, findsOneWidget);
    await _close(tester);
  });

  testWidgets('every change is one tap away', (tester) async {
    await _pump(tester);
    unawaited(
      _confirmer().confirm(
        _request(
          items: [
            _item(
              title: 'Morning dive',
              fields: const {'boat_name': FieldChange('Sea Star', null)},
            ),
            _item(id: 'd2', kind: ChangeKind.delete),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Morning dive'), findsNothing);

    await tester.tap(find.byKey(AgentWriteConfirmDialog.detailsKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('Morning dive'), findsOneWidget);
    expect(find.textContaining('boat_name'), findsOneWidget);
    expect(find.textContaining('Sea Star'), findsOneWidget);
    // An untitled record is named by its kind, not its id.
    expect(find.textContaining(': Dive'), findsOneWidget);
    expect(find.textContaining('d2'), findsNothing);
    await _close(tester);
  });

  testWidgets('depth respects the diver units', (tester) async {
    await _pump(
      tester,
      settings: const AppSettings(
        depthUnit: DepthUnit.feet,
        temperatureUnit: TemperatureUnit.fahrenheit,
      ),
    );
    unawaited(
      _confirmer().confirm(
        _request(
          items: [
            _item(
              fields: const {
                'max_depth_m': FieldChange(10.0, 30.0),
                'water_temp_c': FieldChange(null, 20.0),
              },
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AgentWriteConfirmDialog.detailsKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('98'), findsOneWidget);
    expect(find.textContaining('ft'), findsOneWidget);
    expect(find.textContaining('68'), findsOneWidget);
    await _close(tester);
  });

  // A weight preset's entries and a cylinder config's cylinders are lists of
  // objects; each value inside reads as it would on its own.
  testWidgets('values inside a list of objects respect the diver units', (
    tester,
  ) async {
    await _pump(
      tester,
      settings: const AppSettings(weightUnit: WeightUnit.pounds),
    );
    unawaited(
      _confirmer().confirm(
        _request(
          items: [
            _item(
              fields: const {
                'entries': FieldChange(null, [
                  {'type': 'integrated', 'amount_kg': 4.0, 'label': 'Trim'},
                ]),
                'items': FieldChange(null, [
                  {'role': 'deco', 'o2_fraction': 0.5, 'label': null},
                ]),
              },
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AgentWriteConfirmDialog.detailsKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('8.8 lb'), findsOneWidget);
    expect(find.textContaining('50%'), findsOneWidget);
    expect(find.textContaining('amount_kg: 4.0'), findsNothing);
    expect(find.textContaining('label: null'), findsNothing);
    await _close(tester);
  });

  testWidgets('tank and weight values respect the diver units', (tester) async {
    await _pump(
      tester,
      settings: const AppSettings(
        pressureUnit: PressureUnit.psi,
        volumeUnit: VolumeUnit.cubicFeet,
        weightUnit: WeightUnit.pounds,
      ),
    );
    unawaited(
      _confirmer().confirm(
        _request(
          items: [
            _item(
              fields: const {
                'start_pressure_bar': FieldChange(200.0, 210.0),
                'amount_kg': FieldChange(null, 4.0),
                'o2_fraction': FieldChange(0.21, 0.32),
                'volume_l': FieldChange(null, 11.1),
              },
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AgentWriteConfirmDialog.detailsKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('2901 psi'), findsOneWidget);
    expect(find.textContaining('3046 psi'), findsOneWidget);
    expect(find.textContaining('8.8 lb'), findsOneWidget);
    expect(find.textContaining('21% '), findsOneWidget);
    expect(find.textContaining('32%'), findsOneWidget);
    expect(find.textContaining('cuft'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('a cylinder reads by the working pressure the plan sets', (
    tester,
  ) async {
    await _pump(
      tester,
      settings: const AppSettings(volumeUnit: VolumeUnit.cubicFeet),
    );
    unawaited(
      _confirmer().confirm(
        _request(
          items: [
            _item(
              fields: const {
                'volume_l': FieldChange(null, 11.1),
                'working_pressure_bar': FieldChange(null, 207.0),
              },
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AgentWriteConfirmDialog.detailsKey));
    await tester.pumpAndSettle();

    // From its own pressure, not the 200 bar estimate a '~' marks.
    expect(find.textContaining('cuft'), findsOneWidget);
    expect(find.textContaining('~'), findsNothing);
    await _close(tester);
  });

  testWidgets('a child change names its dive, references and parts', (
    tester,
  ) async {
    await _pump(
      tester,
      settings: const AppSettings(volumeUnit: VolumeUnit.cubicFeet),
    );
    unawaited(
      _confirmer().confirm(
        _request(
          items: const [
            PlanItem(
              operation: 0,
              kind: ChangeKind.create,
              entity: 'sightings',
              diverId: 'diver-a',
              parentTitle: 'Blue Hole',
              fields: {'species_id': FieldChange(null, 'sp-1')},
              names: {'sp-1': 'Moray eel'},
            ),
            PlanItem(
              operation: 1,
              kind: ChangeKind.update,
              entity: 'dive_tanks',
              id: 't1',
              diverId: 'diver-a',
              title: 'Back gas',
              // Only the size changes, so its stored pressure reads it.
              context: {'working_pressure_bar': 207.0},
              fields: {'volume_l': FieldChange(10.0, 11.1)},
            ),
            PlanItem(
              operation: 2,
              kind: ChangeKind.update,
              entity: 'dives',
              id: 'd1',
              diverId: 'diver-a',
              title: 'Wreck',
              indirectLost: {
                'gear': {'hose'},
              },
              names: {'hose': 'Low pressure hose'},
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AgentWriteConfirmDialog.detailsKey));
    await tester.pumpAndSettle();

    expect(find.text('Blue Hole'), findsOneWidget);
    expect(find.textContaining('Moray eel'), findsOneWidget);
    expect(find.textContaining('sp-1'), findsNothing);
    expect(find.textContaining('volume_l'), findsOneWidget);
    expect(find.textContaining('~'), findsNothing);
    expect(find.text('gear: -Low pressure hose'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('long values wrap at 2x text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, textScale: 2);
    unawaited(
      _confirmer().confirm(
        _request(
          client: 'A very long client name for an agent',
          items: [
            _item(
              title: 'A long name for a dive that goes on and on',
              fields: const {
                'notes': FieldChange('old', 'A long note that needs to wrap'),
              },
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AgentWriteConfirmDialog.detailsKey));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_allow, findsOneWidget);
    await _close(tester);
  });
}
