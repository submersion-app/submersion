import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/presentation/pages/demo_unavailable_page.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  testWidgets('the unavailable page explains and offers Exit demo', (
    tester,
  ) async {
    var exits = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demoExitActionProvider.overrideWithValue(() async => exits++),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DemoUnavailablePage(feature: DemoSealedFeature.backup),
        ),
      ),
    );

    expect(find.text('Unavailable in demo mode'), findsWidgets);
    await tester.tap(find.text('Exit demo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit demo').last);
    await tester.pumpAndSettle();

    expect(exits, 1);
  });
}
