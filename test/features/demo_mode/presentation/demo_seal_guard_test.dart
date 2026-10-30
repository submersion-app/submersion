import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/global_test_defaults.dart';

void main() {
  tearDown(applyGlobalTestDefaults);

  Future<List<bool>> tapGuard(WidgetTester tester) async {
    final results = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  results.add(demoSealGuard(context, DemoSealedFeature.export)),
              child: const Text('Export'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Export'));
    await tester.pump();
    return results;
  }

  testWidgets('guard passes through while demo mode is off', (tester) async {
    final results = await tapGuard(tester);

    expect(results, [true]);
    expect(find.text('Not available in demo mode'), findsNothing);
  });

  testWidgets('guard shows the note and blocks while demo mode is on', (
    tester,
  ) async {
    DemoModeGate.instance.debugActive = true;

    final results = await tapGuard(tester);

    expect(results, [false]);
    expect(find.text('Not available in demo mode'), findsOneWidget);
  });
}
