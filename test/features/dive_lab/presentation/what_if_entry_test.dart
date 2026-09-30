import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/presentation/pages/dive_lab_page.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/what_if_entry.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/what_if_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';

List<DiveProfilePoint> _profile() => [
  for (var t = 0; t <= 600; t += 10) DiveProfilePoint(timestamp: t, depth: 20),
];

Dive _dive(DiveMode mode) => Dive(
  id: 'd',
  dateTime: DateTime(2026, 1, 1),
  diveMode: mode,
  profile: _profile(),
);

Widget _harness(Dive dive) => testApp(
  overrides: [
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    labRequestInputsProvider('d').overrideWith((ref) async => null),
    labDefaultBranchProvider('d').overrideWith((ref) async => 0),
    diveProvider.overrideWith((ref, id) async => dive),
    divesProvider.overrideWith((ref) async => <Dive>[]),
    diveProfileProvider.overrideWith((ref, id) async => dive.profile),
    gasSwitchesProvider.overrideWith((ref, id) async => <GasSwitchWithTank>[]),
  ],
  locale: const Locale('en'),
  child: Builder(
    builder: (context) => ElevatedButton(
      onPressed: () => openWhatIf(context, dive),
      child: const Text('open'),
    ),
  ),
);

void main() {
  testWidgets('an eligible dive opens the Dive Lab', (tester) async {
    await tester.pumpWidget(_harness(_dive(DiveMode.oc)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(DiveLabPage), findsOneWidget);
    expect(find.byType(WhatIfSheet), findsNothing);
  });

  testWidgets('a gauge dive with a profile opens the rebuild sheet', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_dive(DiveMode.gauge)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(WhatIfSheet), findsOneWidget);
    expect(find.byType(DiveLabPage), findsNothing);
  });
}
