import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/demo_mode/presentation/widgets/demo_mode_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<void> pumpStrip(
    WidgetTester tester, {
    required bool active,
    Size size = const Size(800, 600),
    double textScale = 1,
    Future<void> Function()? exit,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demoModeActiveProvider.overrideWithValue(active),
          if (exit != null) demoExitActionProvider.overrideWithValue(exit),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: const Scaffold(
              body: Column(
                children: [
                  DemoModeStrip(),
                  Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('strip is absent when demo mode is off', (tester) async {
    await pumpStrip(tester, active: false);

    expect(find.text('Demo mode: you are exploring sample data'), findsNothing);
    expect(find.text('Exit demo'), findsNothing);
  });

  testWidgets('strip shows the label and Exit demo when demo mode is on', (
    tester,
  ) async {
    var exits = 0;
    await pumpStrip(tester, active: true, exit: () async => exits++);

    expect(
      find.text('Demo mode: you are exploring sample data'),
      findsOneWidget,
    );
    await tester.tap(find.text('Exit demo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit demo').last);
    await tester.pumpAndSettle();
    expect(exits, 1);
  });

  testWidgets('strip text does not overflow at 320 px and text scale 2', (
    tester,
  ) async {
    await pumpStrip(
      tester,
      active: true,
      size: const Size(320, 640),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
  });

  test('the main scaffold shows the strip in every layout', () {
    final source = File(
      'lib/shared/widgets/main_scaffold.dart',
    ).readAsStringSync();

    expect('const DemoModeStrip()'.allMatches(source).length, 3);
  });
}
