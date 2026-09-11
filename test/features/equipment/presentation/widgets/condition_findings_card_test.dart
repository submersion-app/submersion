import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_findings_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/condition_trend_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/condition_findings_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const reg = EquipmentItem(
  id: 'reg',
  name: 'Reg',
  type: EquipmentType.regulator,
);

class _RecordingFindings extends EquipmentFindingsRepository {
  final calls = <(String, bool)>[];

  @override
  Future<void> setDismissed({
    required String findingId,
    required bool dismissed,
    required DateTime now,
  }) async {
    calls.add((findingId, dismissed));
  }
}

EquipmentFinding finding(
  ConditionRuleId rule, {
  Map<String, double> values = const {},
  int? slot,
  String? tag,
  bool dismissed = false,
  List<String> diveIds = const ['d1', 'd2'],
}) {
  final evidence = FindingEvidence(
    n: 5,
    windowStart: DateTime(2026, 3, 3),
    windowEnd: DateTime(2026, 6, 9),
    diveIds: diveIds,
    values: values,
    slot: slot,
    tag: tag,
  );
  return EquipmentFinding(
    id: conditionFindingId('reg', rule, slot: slot, tag: tag),
    equipmentId: 'reg',
    ruleId: rule,
    severity: rule.severity,
    value: 30,
    evidence: evidence,
    evidenceFingerprint: evidenceFingerprint(evidence),
    engineVersion: 1,
    createdAt: DateTime(2026, 6, 9),
    dismissedAt: dismissed ? DateTime(2026, 6, 10) : null,
  );
}

final three = [
  finding(ConditionRuleId.incidentLinked, values: {'count': 1}),
  finding(
    ConditionRuleId.issueRecurring,
    values: {'count': 3},
    tag: 'freeFlow',
  ),
  finding(
    ConditionRuleId.cellOutputLow,
    values: {'recentMedian': 35.5},
    slot: 1,
    dismissed: true,
  ),
];

Widget host(
  List<EquipmentFinding>? findings, {
  AppSettings settings = const AppSettings(),
  EquipmentFindingsRepository? repo,
}) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith((ref) => MockSettingsNotifier(settings)),
    equipmentConditionProvider('reg').overrideWith((ref) async => findings),
    if (repo != null)
      equipmentFindingsRepositoryProvider.overrideWithValue(repo),
  ],
  child: const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: ConditionFindingsCard(equipment: reg)),
  ),
);

void main() {
  // Dates format through the process-global Intl.defaultLocale, which
  // MaterialApp.locale does not set; pin it so the English month names
  // in these expectations hold on any host.
  late String? savedIntlLocale;
  setUp(() {
    savedIntlLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() => Intl.defaultLocale = savedIntlLocale);

  testWidgets('lists active findings and folds the dismissed away', (
    tester,
  ) async {
    await tester.pumpWidget(host(three));
    await tester.pumpAndSettle();
    expect(find.text('Condition findings'), findsOneWidget);
    expect(find.text('2 findings'), findsOneWidget);
    expect(find.text('1 incident names this item'), findsOneWidget);
    expect(
      find.text('Free flow reported 3 times in the last 5 dives'),
      findsOneWidget,
    );
    expect(find.textContaining('Cell 1 output'), findsNothing);
    await tester.tap(find.text('Show 1 dismissed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cell 1 output'), findsOneWidget);
    // The incident finding gives its range alone: its n counts incidents.
    expect(find.text('5 dives, Mar 3 - Jun 9, 2026'), findsNWidgets(2));
    expect(find.text('Mar 3 - Jun 9, 2026'), findsOneWidget);
  });

  testWidgets('a finding with no dives offers no evidence dives', (
    tester,
  ) async {
    // An incident logged on the bench names no dive; the action would
    // open an empty sheet.
    await tester.pumpWidget(
      host([
        finding(
          ConditionRuleId.incidentLinked,
          values: {'count': 1},
          diveIds: const [],
        ),
        finding(
          ConditionRuleId.issueRecurring,
          values: {'count': 3},
          tag: 'freeFlow',
        ),
      ]),
    );
    await tester.pumpAndSettle();
    Finder tileOf(String sentence) =>
        find.ancestor(of: find.text(sentence), matching: find.byType(ListTile));
    Finder evidenceIn(Finder tile) =>
        find.descendant(of: tile, matching: find.text('Evidence dives'));
    // The bench incident's row has no action; the recurring issue's does.
    expect(evidenceIn(tileOf('1 incident names this item')), findsNothing);
    expect(
      evidenceIn(tileOf('Free flow reported 3 times in the last 5 dives')),
      findsOneWidget,
    );
  });

  testWidgets('a disabled rule is hidden and the count follows', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        three,
        settings: const AppSettings(conditionDisabledRules: {'issueRecurring'}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 finding'), findsOneWidget);
    expect(find.textContaining('Free flow'), findsNothing);
  });

  testWidgets('the master toggle off renders no card', (tester) async {
    await tester.pumpWidget(
      host(three, settings: const AppSettings(conditionEngineEnabled: false)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('no findings renders no card', (tester) async {
    await tester.pumpWidget(host(const []));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);
  });

  testWidgets(
    'tapping a finding selects it for the chart, tapping again clears',
    (tester) async {
      await tester.pumpWidget(host(three));
      await tester.pumpAndSettle();
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(ConditionFindingsCard)),
      );
      await tester.tap(find.text('1 incident names this item'));
      await tester.pumpAndSettle();
      expect(
        scope.read(selectedConditionFindingProvider('reg'))?.ruleId,
        ConditionRuleId.incidentLinked,
      );
      await tester.tap(find.text('1 incident names this item'));
      await tester.pumpAndSettle();
      expect(scope.read(selectedConditionFindingProvider('reg')), isNull);
    },
  );

  testWidgets('folding a selected dismissed row away clears the selection', (
    tester,
  ) async {
    // The chart shades the selected finding's window; once the card no
    // longer shows the row, the chart must not keep shading it.
    await tester.pumpWidget(host(three));
    await tester.pumpAndSettle();
    final scope = ProviderScope.containerOf(
      tester.element(find.byType(ConditionFindingsCard)),
    );
    await tester.tap(find.text('Show 1 dismissed'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Cell 1 output'));
    await tester.pumpAndSettle();
    expect(scope.read(selectedConditionFindingProvider('reg')), isNotNull);

    await tester.tap(find.text('Show 1 dismissed'));
    await tester.pumpAndSettle();
    expect(scope.read(selectedConditionFindingProvider('reg')), isNull);
  });

  testWidgets('a finding dismissed elsewhere stops being selected', (
    tester,
  ) async {
    // A sync or a recompute can dismiss the selected finding without the
    // card's own button, which is the only path that cleared it.
    final findings = StateProvider<List<EquipmentFinding>>((ref) => three);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          equipmentConditionProvider(
            'reg',
          ).overrideWith((ref) async => ref.watch(findings)),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ConditionFindingsCard(equipment: reg)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scope = ProviderScope.containerOf(
      tester.element(find.byType(ConditionFindingsCard)),
    );
    await tester.tap(find.text('1 incident names this item'));
    await tester.pumpAndSettle();
    expect(scope.read(selectedConditionFindingProvider('reg')), isNotNull);

    scope.read(findings.notifier).state = [
      finding(
        ConditionRuleId.incidentLinked,
        values: {'count': 1},
        dismissed: true,
      ),
      ...three.skip(1),
    ];
    await tester.pumpAndSettle();
    expect(scope.read(selectedConditionFindingProvider('reg')), isNull);
  });

  testWidgets('the dismiss button writes through the repository', (
    tester,
  ) async {
    final repo = _RecordingFindings();
    await tester.pumpWidget(host(three, repo: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dismiss').first);
    await tester.pumpAndSettle();
    expect(repo.calls, [('cf_reg_incidentLinked', true)]);
  });
}
