import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/condition_evidence_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/condition_evidence_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const reg = EquipmentItem(
  id: 'reg',
  name: 'Reg',
  type: EquipmentType.regulator,
);

final evidence = FindingEvidence(
  n: 2,
  windowStart: DateTime(2026, 3, 3),
  windowEnd: DateTime(2026, 6, 9),
  diveIds: const ['d1', 'd2'],
  values: const {'count': 1},
);
final finding = EquipmentFinding(
  id: 'cf_reg_incidentLinked',
  equipmentId: 'reg',
  ruleId: ConditionRuleId.incidentLinked,
  severity: ConditionSeverity.info,
  evidence: evidence,
  evidenceFingerprint: evidenceFingerprint(evidence),
  engineVersion: 1,
  createdAt: DateTime(2026),
);

final summaries = <DiveSummary>[
  DiveSummary(
    id: 'd2',
    diveNumber: 42,
    dateTime: DateTime(2026, 6, 9, 10),
    sortTimestamp: DateTime(2026, 6, 9, 10).millisecondsSinceEpoch,
    maxDepth: 30.48,
    bottomTime: const Duration(minutes: 45),
  ),
  DiveSummary(
    id: 'd1',
    dateTime: DateTime(2026, 3, 3, 9),
    sortTimestamp: DateTime(2026, 3, 3, 9).millisecondsSinceEpoch,
    maxDepth: 12,
    bottomTime: const Duration(minutes: 30),
  ),
];

Widget host(
  AppSettings settings, {
  required List<String> pushed,
  bool failLoad = false,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showConditionEvidenceSheet(
                context,
                equipment: reg,
                finding: finding,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/dives/:id',
        builder: (context, state) {
          pushed.add(state.pathParameters['id']!);
          return const Scaffold(body: Text('DIVE'));
        },
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => MockSettingsNotifier(settings)),
      conditionEvidenceDivesProvider((
        equipmentId: 'reg',
        findingId: 'cf_reg_incidentLinked',
      )).overrideWith(
        (ref) async => failLoad ? throw StateError('db closed') : summaries,
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  testWidgets('lists the evidence dives in the diver units and opens one', (
    tester,
  ) async {
    final pushed = <String>[];
    await tester.pumpWidget(
      host(const AppSettings(depthUnit: DepthUnit.feet), pushed: pushed),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Evidence dives'), findsOneWidget);
    expect(find.text('1 incident names this item'), findsOneWidget);
    expect(find.text('Dive 42'), findsOneWidget);
    expect(find.text('Dive'), findsOneWidget);
    expect(find.textContaining('100.0ft'), findsOneWidget);
    expect(find.textContaining('45 min'), findsOneWidget);
    await tester.tap(find.text('Dive 42'));
    await tester.pumpAndSettle();
    expect(pushed, ['d2']);
    expect(find.text('DIVE'), findsOneWidget);
  });

  testWidgets('a failed load says so in words, never the raw error', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const AppSettings(), pushed: [], failLoad: true),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('db closed'), findsNothing);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });
}
