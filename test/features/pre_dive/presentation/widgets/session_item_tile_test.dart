import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/overdue_service_entry.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/pre_dive/presentation/widgets/session_item_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  // The value line formats through Intl.getCurrentLocale(), which resolves the
  // Intl.defaultLocale process global rather than the MaterialApp locale. The
  // app assigns it from the diver's locale (lib/app.dart); a widget test that
  // pumps the tile alone never runs that.
  //
  // Pinned rather than merely saved. Left unset, getCurrentLocale falls back to
  // Intl.systemLocale, and the assertions below that spell out a '.' would then
  // rest on that fallback happening to be en_US: a default owned by intl, not
  // by this file. Tests that need another locale set it in the test body.
  late String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousLocale;
  });

  PreDiveSession session({bool locked = false, bool strict = false}) =>
      PreDiveSession(
        id: 's1',
        templateName: 'T',
        startedAt: now,
        createdAt: now,
        updatedAt: now,
        strictOrder: strict,
        status: locked
            ? PreDiveSessionStatus.completed
            : PreDiveSessionStatus.inProgress,
      );

  PreDiveSessionItem item({
    String id = 'i1',
    String title = 'Check air',
    PreDiveItemState state = PreDiveItemState.pending,
    PreDiveItemType type = PreDiveItemType.check,
    bool required = false,
    String note = '',
    String notes = '',
    String? valueLabel,
    double? valueNumber,
    String? valueUnit,
    double? valueMin,
    double? valueMax,
    DateTime? completedAt,
    String? equipmentId,
    List<OverdueServiceEntry>? overdueServices,
    String? sourceItemId,
    double? sourceValueNumber,
  }) => PreDiveSessionItem(
    id: id,
    sessionId: 's1',
    title: title,
    state: state,
    itemType: type,
    isRequired: required,
    note: note,
    notes: notes,
    valueLabel: valueLabel,
    valueNumber: valueNumber,
    valueUnit: valueUnit,
    valueMin: valueMin,
    valueMax: valueMax,
    completedAt: completedAt,
    equipmentId: equipmentId,
    overdueServices: overdueServices,
    sourceItemId: sourceItemId,
    sourceValueNumber: sourceValueNumber,
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pumpTile(
    WidgetTester tester, {
    required PreDiveSession s,
    required PreDiveSessionItem it,
    List<PreDiveSessionItem>? items,
    VoidCallback? onDone,
    VoidCallback? onSkip,
    VoidCallback? onFlag,
    VoidCallback? onEditValue,
    VoidCallback? onAddNote,
    VoidCallback? onReset,
    List<dynamic> overrides = const [],
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      testApp(
        locale: locale,
        overrides: overrides,
        child: SessionItemTile(
          session: s,
          sortedItems: items ?? [it],
          item: it,
          onDone: onDone ?? () {},
          onSkip: onSkip ?? () {},
          onFlag: onFlag ?? () {},
          onEditValue: onEditValue ?? () {},
          onAddNote: onAddNote ?? () {},
          onReset: onReset ?? () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
  }

  group('state rendering', () {
    testWidgets('long item title keeps its width beside the completion time', (
      tester,
    ) async {
      // Guards the ListTile.trailing hazard behind issue #935: the trailing
      // widget is measured against the full tile width before the title column
      // gets what is left.
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const longTitle =
          'Verify both oxygen cells read within 2 mV of each '
          'other before closing the loop';
      await pumpTile(
        tester,
        s: session(),
        it: item(
          title: longTitle,
          state: PreDiveItemState.done,
          completedAt: now,
        ),
      );

      final titleSize = tester.getSize(find.text(longTitle));

      expect(
        titleSize.width,
        greaterThan(150),
        reason:
            'Item title collapsed to ${titleSize.width}px wide on a 360px '
            'screen; the trailing row is starving the text column.',
      );
    });

    testWidgets('pending item shows unchecked icon and title', (tester) async {
      await pumpTile(tester, s: session(), it: item());
      expect(find.text('Check air'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('done item shows filled check and a completion time', (
      tester,
    ) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(
          state: PreDiveItemState.done,
          completedAt: DateTime(2024, 1, 1, 10, 30),
        ),
      );
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      // Trailing completion time is rendered (line-exercise for completedAt).
      expect(find.textContaining('10:30'), findsOneWidget);
    });

    testWidgets('skipped item shows remove-circle icon', (tester) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(state: PreDiveItemState.skipped),
      );
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
    });

    testWidgets('flagged item shows flag icon', (tester) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(state: PreDiveItemState.flagged),
      );
      expect(find.byIcon(Icons.flag), findsOneWidget);
    });
  });

  group('subtitle content', () {
    testWidgets('value item renders the value line', (tester) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(
          type: PreDiveItemType.value,
          valueLabel: 'SPG',
          valueNumber: 200,
          valueUnit: 'bar',
        ),
      );
      expect(find.text('SPG: 200.0 bar'), findsOneWidget);
    });

    testWidgets('value line follows a comma-decimal locale', (tester) async {
      // double.toString() always emits '.', so the recorded reading read
      // "200.0 bar" to a German diver while every number they typed used a
      // comma. Both the process global and the MaterialApp locale are set:
      // the first drives the separator, the second the surrounding strings.
      Intl.defaultLocale = 'de';
      await pumpTile(
        tester,
        s: session(),
        it: item(
          type: PreDiveItemType.value,
          valueLabel: 'SPG',
          valueNumber: 200,
          valueUnit: 'bar',
        ),
        locale: const Locale('de'),
      );
      expect(find.text('SPG: 200,0 bar'), findsOneWidget);
    });

    testWidgets('out-of-range value line is bold', (tester) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(
          type: PreDiveItemType.value,
          valueLabel: 'SPG',
          valueNumber: 300,
          valueUnit: 'bar',
          valueMax: 200,
        ),
      );
      final text = tester.widget<Text>(find.text('SPG: 300.0 bar'));
      expect(text.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('note and notes lines both render', (tester) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(note: 'Needle jumpy', notes: 'Should read 200 bar'),
      );
      expect(find.text('Needle jumpy'), findsOneWidget);
      expect(find.text('Should read 200 bar'), findsOneWidget);
    });
  });

  group('overdue service warning', () {
    final overdueStatus = ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 'sched1',
        equipmentId: 'g1',
        serviceKindId: 'vip',
        createdAt: now,
        updatedAt: now,
      ),
      kind: ServiceKind(
        id: 'vip',
        name: 'Visual inspection',
        applicableTypes: const [],
        createdAt: now,
        updatedAt: now,
      ),
      anchor: now,
      dueDate: DateTime(2020, 1, 1),
      severity: ServiceClockSeverity.overdue,
      now: DateTime(2026, 1, 1),
    );

    testWidgets(
      'pending item with overdue equipment shows a live warning, not a '
      'resolved state',
      (tester) async {
        await pumpTile(
          tester,
          s: session(),
          it: item(equipmentId: 'g1'),
          overrides: [
            serviceClockStatusesProvider(
              'g1',
            ).overrideWith((ref) async => [overdueStatus]),
          ],
        );
        expect(find.text('Service overdue'), findsOneWidget);
        expect(find.textContaining('Visual inspection'), findsOneWidget);
        // Still pending: the warning is informative only, not a done state.
        expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
        expect(find.byIcon(Icons.flag), findsNothing);
      },
    );

    EquipmentFinding finding(
      ConditionSeverity severity, {
      bool dismissed = false,
    }) {
      final rule = severity == ConditionSeverity.significant
          ? ConditionRuleId.cellOutputLow
          : ConditionRuleId.cellOutputDeclining;
      final evidence = FindingEvidence(n: 3, windowStart: now, windowEnd: now);
      return EquipmentFinding(
        id: conditionFindingId('g1', rule, slot: 1),
        equipmentId: 'g1',
        ruleId: rule,
        severity: severity,
        evidence: evidence,
        evidenceFingerprint: evidenceFingerprint(evidence),
        engineVersion: 1,
        createdAt: now,
        dismissedAt: dismissed ? now : null,
      );
    }

    List<dynamic> findingOverrides(
      List<EquipmentFinding> findings, {
      AppSettings settings = const AppSettings(),
      bool overdue = false,
    }) => [
      settingsProvider.overrideWith((ref) => MockSettingsNotifier(settings)),
      serviceClockStatusesProvider(
        'g1',
      ).overrideWith((ref) async => overdue ? [overdueStatus] : []),
      equipmentConditionProvider('g1').overrideWith((ref) async => findings),
    ];

    testWidgets('a significant finding joins the warning block', (
      tester,
    ) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(equipmentId: 'g1'),
        overrides: findingOverrides([finding(ConditionSeverity.significant)]),
      );
      expect(find.text('Condition findings'), findsOneWidget);
      expect(find.text('Cell output low'), findsOneWidget);
      expect(find.text('Service overdue'), findsNothing);
    });

    testWidgets('a caution or dismissed finding shows nothing', (tester) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(equipmentId: 'g1'),
        overrides: findingOverrides([
          finding(ConditionSeverity.caution),
          finding(ConditionSeverity.significant, dismissed: true),
        ]),
      );
      expect(find.text('Condition findings'), findsNothing);
    });

    testWidgets('clocks come first, then the findings', (tester) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(equipmentId: 'g1'),
        overrides: findingOverrides([
          finding(ConditionSeverity.significant),
        ], overdue: true),
      );
      final overdueY = tester.getTopLeft(find.text('Service overdue')).dy;
      final findingsY = tester.getTopLeft(find.text('Condition findings')).dy;
      expect(overdueY, lessThan(findingsY));
      expect(find.text('Cell output low'), findsOneWidget);
    });

    testWidgets('a disabled rule or the engine off hides the finding', (
      tester,
    ) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(equipmentId: 'g1'),
        overrides: findingOverrides(
          [finding(ConditionSeverity.significant)],
          settings: const AppSettings(
            conditionDisabledRules: {'cellOutputLow'},
          ),
        ),
      );
      expect(find.text('Condition findings'), findsNothing);
      await pumpTile(
        tester,
        s: session(),
        it: item(equipmentId: 'g1'),
        overrides: findingOverrides([
          finding(ConditionSeverity.significant),
        ], settings: const AppSettings(conditionEngineEnabled: false)),
      );
      expect(find.text('Condition findings'), findsNothing);
    });

    testWidgets('a resolved item shows no finding line', (tester) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(
          equipmentId: 'g1',
          state: PreDiveItemState.done,
          completedAt: now,
        ),
        overrides: findingOverrides([finding(ConditionSeverity.significant)]),
      );
      expect(find.text('Condition findings'), findsNothing);
    });

    testWidgets('pending item with no overdue clocks shows nothing extra', (
      tester,
    ) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(equipmentId: 'g1'),
        overrides: [
          serviceClockStatusesProvider('g1').overrideWith((ref) async => []),
        ],
      );
      expect(find.text('Service overdue'), findsNothing);
    });

    testWidgets(
      'resolved item shows its frozen overdue snapshot without touching the '
      "equipment provider (a later service log entry can't rewrite it)",
      (tester) async {
        await pumpTile(
          tester,
          s: session(),
          it: item(
            state: PreDiveItemState.done,
            completedAt: now,
            equipmentId: 'g1',
            overdueServices: const [
              OverdueServiceEntry(
                kindName: 'Hydrostatic test',
                divesRemaining: -3,
              ),
            ],
          ),
          // No serviceClockStatusesProvider override: a resolved item must
          // never watch it, so this would fail with a missing-provider error
          // if the live path were used by mistake.
        );
        expect(find.text('Service overdue'), findsOneWidget);
        expect(find.textContaining('Hydrostatic test'), findsOneWidget);
      },
    );

    testWidgets('resolved item with an empty frozen list shows nothing extra', (
      tester,
    ) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(
          state: PreDiveItemState.done,
          completedAt: now,
          equipmentId: 'g1',
          overdueServices: const [],
        ),
      );
      expect(find.text('Service overdue'), findsNothing);
    });

    testWidgets(
      'a frozen entry is worded against completedAt, not the wall clock: a '
      'dueDate that was still in the future at freeze time keeps reading '
      '"Due", however long ago the item was resolved',
      (tester) async {
        // The entry was frozen because its dives trigger was overdue, while
        // its date trigger was not yet due. Reading it against DateTime.now()
        // would silently reword the snapshot to "Overdue since" once real
        // time passed dueDate, even though nothing stored changed.
        await pumpTile(
          tester,
          s: session(),
          it: item(
            state: PreDiveItemState.done,
            completedAt: now, // 2023-11-14
            equipmentId: 'g1',
            overdueServices: [
              OverdueServiceEntry(
                kindName: 'Hydrostatic test',
                dueDate: DateTime(2024, 6), // after completedAt, before today
                divesSinceAnchor: 53,
                divesRemaining: -3,
              ),
            ],
          ),
        );

        expect(find.text('Service overdue'), findsOneWidget);
        expect(find.textContaining('Hydrostatic test: Due '), findsOneWidget);
        expect(find.textContaining('Overdue since'), findsNothing);
      },
    );

    testWidgets(
      'a pending item is still worded against the wall clock, so a dueDate '
      'already in the past reads "Overdue since"',
      (tester) async {
        await pumpTile(
          tester,
          s: session(),
          it: item(equipmentId: 'g1'),
          overrides: [
            serviceClockStatusesProvider('g1').overrideWith(
              (ref) async => [
                ServiceClockStatus(
                  schedule: overdueStatus.schedule,
                  kind: overdueStatus.kind,
                  anchor: now,
                  dueDate: DateTime(2024, 6),
                  severity: ServiceClockSeverity.overdue,
                  now: DateTime(2026, 1, 1),
                ),
              ],
            ),
          ],
        );

        expect(find.textContaining('Overdue since'), findsOneWidget);
      },
    );
  });

  group('tap target', () {
    testWidgets('tapping a check item fires onDone', (tester) async {
      var done = false;
      await pumpTile(
        tester,
        s: session(),
        it: item(),
        onDone: () => done = true,
      );
      await tester.tap(find.byType(ListTile));
      expect(done, isTrue);
    });

    testWidgets('tapping a value item fires onEditValue, not onDone', (
      tester,
    ) async {
      var done = false;
      var edit = false;
      await pumpTile(
        tester,
        s: session(),
        it: item(
          type: PreDiveItemType.value,
          valueLabel: 'SPG',
          valueNumber: 200,
        ),
        onDone: () => done = true,
        onEditValue: () => edit = true,
      );
      await tester.tap(find.byType(ListTile));
      expect(edit, isTrue);
      expect(done, isFalse);
    });
  });

  group('strict-order gating', () {
    testWidgets('non-next item is dimmed and inert', (tester) async {
      var done = false;
      final first = item(id: 'a', title: 'First');
      final target = item(id: 'b', title: 'Second');
      await pumpTile(
        tester,
        s: session(strict: true),
        it: target,
        items: [first, target],
        onDone: () => done = true,
      );

      // Wrapped in a 0.4-opacity layer when gated.
      expect(
        find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.4),
        findsOneWidget,
      );
      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.enabled, isFalse);

      await tester.tap(find.byType(ListTile), warnIfMissed: false);
      expect(done, isFalse);

      // The overflow menu is also gated: Skip/Flag/Note must not be reachable
      // on a not-yet-actionable pending item in a strict-order session.
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('the next item is not dimmed and is actionable', (
      tester,
    ) async {
      var done = false;
      final first = item(id: 'a', title: 'First');
      final second = item(id: 'b', title: 'Second');
      await pumpTile(
        tester,
        s: session(strict: true),
        it: first,
        items: [first, second],
        onDone: () => done = true,
      );
      expect(
        find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.4),
        findsNothing,
      );
      await tester.tap(find.byType(ListTile));
      expect(done, isTrue);
    });
  });

  group('popup menu', () {
    testWidgets('pending optional item offers Skip, Flag, Add note', (
      tester,
    ) async {
      await pumpTile(tester, s: session(), it: item());
      await openMenu(tester);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Flag'), findsOneWidget);
      expect(find.text('Add note'), findsOneWidget);
      expect(find.text('Reset to pending'), findsNothing);
    });

    testWidgets('required item hides Skip', (tester) async {
      await pumpTile(tester, s: session(), it: item(required: true));
      await openMenu(tester);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Flag'), findsOneWidget);
      expect(find.text('Add note'), findsOneWidget);
    });

    testWidgets('resolved item offers Undo but not Skip/Flag', (tester) async {
      await pumpTile(
        tester,
        s: session(),
        it: item(state: PreDiveItemState.done),
      );
      await openMenu(tester);
      expect(find.text('Reset to pending'), findsOneWidget);
      expect(find.text('Add note'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Flag'), findsNothing);
    });

    testWidgets('selecting Skip fires onSkip', (tester) async {
      var skipped = false;
      await pumpTile(
        tester,
        s: session(),
        it: item(),
        onSkip: () => skipped = true,
      );
      await openMenu(tester);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(skipped, isTrue);
    });

    testWidgets('selecting Flag fires onFlag', (tester) async {
      var flagged = false;
      await pumpTile(
        tester,
        s: session(),
        it: item(),
        onFlag: () => flagged = true,
      );
      await openMenu(tester);
      await tester.tap(find.text('Flag'));
      await tester.pumpAndSettle();
      expect(flagged, isTrue);
    });

    testWidgets('selecting Add note fires onAddNote', (tester) async {
      var noted = false;
      await pumpTile(
        tester,
        s: session(),
        it: item(),
        onAddNote: () => noted = true,
      );
      await openMenu(tester);
      await tester.tap(find.text('Add note'));
      await tester.pumpAndSettle();
      expect(noted, isTrue);
    });

    testWidgets('selecting Undo fires onReset', (tester) async {
      var reset = false;
      await pumpTile(
        tester,
        s: session(),
        it: item(state: PreDiveItemState.done),
        onReset: () => reset = true,
      );
      await openMenu(tester);
      await tester.tap(find.text('Reset to pending'));
      await tester.pumpAndSettle();
      expect(reset, isTrue);
    });

    testWidgets('locked session hides the menu entirely', (tester) async {
      await pumpTile(
        tester,
        s: session(locked: true),
        it: item(state: PreDiveItemState.done),
      );
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });
  });

  group('cell linearity (#986)', () {
    PreDiveSessionItem linearity({
      PreDiveItemState state = PreDiveItemState.done,
      double? o2 = 48.0,
      double? air = 10.1,
      double? min = 95,
    }) => item(
      title: 'Cell 1 mV in O2',
      type: PreDiveItemType.cellLinearity,
      state: state,
      valueLabel: 'Cell 1',
      valueUnit: 'mV',
      valueNumber: o2,
      valueMin: min,
      sourceItemId: 'air1',
      sourceValueNumber: air,
    );

    testWidgets('shows the working and the percentage', (tester) async {
      await pumpTile(tester, s: session(), it: linearity());

      expect(find.textContaining('Cell 1: 48.0 mV'), findsOneWidget);
      expect(find.textContaining('Air 10.1 mV'), findsOneWidget);
      expect(find.textContaining('expected 48.3 mV'), findsOneWidget);
      expect(find.textContaining('linearity 99%'), findsOneWidget);
    });

    testWidgets('the working uses the diver\'s decimal separator', (
      tester,
    ) async {
      // Same bug #1684 fixed on the value line above, on the same tile
      // (#1682). Pins the process global the formatter actually reads, not
      // just the MaterialApp locale, or this passes against unfixed code.
      Intl.defaultLocale = 'de';
      await pumpTile(tester, s: session(), it: linearity());

      // The sentence stays English because pumpTile pins the MaterialApp to
      // 'en'; only the numbers follow Intl.defaultLocale. The two locales are
      // deliberately independent, which is why pinning the widget locale
      // alone would not catch this.
      expect(find.textContaining('Air 10,1 mV'), findsOneWidget);
      expect(find.textContaining('expected 48,3 mV'), findsOneWidget);
      expect(find.textContaining('10.1'), findsNothing);
      expect(find.textContaining('48.3'), findsNothing);
    });

    testWidgets('the air reading keeps the precision the diver entered', (
      tester,
    ) async {
      // The air value is the diver's own input, so it is never rounded: a
      // check that exists so they can redo the sum must not show a figure
      // they did not type. Only the derived expected value is pinned to 1 dp.
      await pumpTile(tester, s: session(), it: linearity(air: 10.15));

      expect(find.textContaining('Air 10.15 mV'), findsOneWidget);
      expect(find.textContaining('expected 48.6 mV'), findsOneWidget);
    });

    testWidgets('a low reading is styled as out of range', (tester) async {
      await pumpTile(tester, s: session(), it: linearity(o2: 40.0));

      final line = tester.widget<Text>(find.textContaining('linearity 83%'));
      expect(line.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('the warning marks the percentage, not the O2 millivolts', (
      tester,
    ) async {
      // The threshold on a linearity item is a percentage, so the amber has
      // to point at the figure that actually breached it. Highlighting
      // "Cell 1: 40.0 mV" would claim the millivolt reading was out of
      // range, which is the same category error valueOutOfRange itself had.
      await pumpTile(tester, s: session(), it: linearity(o2: 40.0));

      final working = tester.widget<Text>(find.textContaining('linearity 83%'));
      expect(working.style?.fontWeight, FontWeight.bold);

      final primary = tester.widget<Text>(find.textContaining('Cell 1: 40.0'));
      expect(
        primary.style?.fontWeight,
        isNot(FontWeight.bold),
        reason: 'no threshold applies to the recorded millivolts',
      );
    });

    testWidgets('a plain value item still warns on its own line', (
      tester,
    ) async {
      // The other side of the split: for a value item the recorded number is
      // exactly what the threshold measures, so it keeps the warning.
      await pumpTile(
        tester,
        s: session(),
        it: item(
          type: PreDiveItemType.value,
          state: PreDiveItemState.done,
          valueLabel: 'Cell 1',
          valueUnit: 'mV',
          valueNumber: 8.0,
          valueMin: 8.5,
        ),
      );

      final primary = tester.widget<Text>(find.textContaining('Cell 1: 8'));
      expect(primary.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('a healthy reading is not styled as out of range', (
      tester,
    ) async {
      await pumpTile(tester, s: session(), it: linearity());

      final line = tester.widget<Text>(find.textContaining('linearity 99%'));
      expect(line.style?.fontWeight, isNot(FontWeight.bold));
    });

    testWidgets('no air reading means no percentage line', (tester) async {
      await pumpTile(
        tester,
        s: session(),
        it: linearity(air: null, o2: null, state: PreDiveItemState.pending),
      );

      expect(find.textContaining('linearity'), findsNothing);
    });

    testWidgets('tapping opens value entry, not done', (tester) async {
      var editCalls = 0;
      var doneCalls = 0;
      await pumpTile(
        tester,
        s: session(),
        it: linearity(state: PreDiveItemState.pending, o2: null, air: null),
        onEditValue: () => editCalls++,
        onDone: () => doneCalls++,
      );

      await tester.tap(find.text('Cell 1 mV in O2'));
      await tester.pump();
      expect(editCalls, 1);
      expect(doneCalls, 0);
    });

    testWidgets('the stale-source hint appears only when asked', (
      tester,
    ) async {
      await pumpTile(tester, s: session(), it: linearity());
      expect(find.textContaining('has changed since'), findsNothing);

      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          child: SessionItemTile(
            session: session(),
            sortedItems: [linearity()],
            item: linearity(),
            staleSourceValue: 9.4,
            onDone: () {},
            onSkip: () {},
            onFlag: () {},
            onEditValue: () {},
            onAddNote: () {},
            onReset: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('has changed since'), findsOneWidget);
    });
  });
}
