import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/settings/data/set_up_card_prefs.dart';
import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/settings/presentation/pages/set_up_device_page.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_progress_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_navigation.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../set_up_progress_fixture.dart';

/// The flow page's navigation (issue #3482, Part B Task 7). The step bodies
/// are the steps' own tests; here each step is found by its key.
void main() {
  late SharedPreferences prefs;

  Future<void> pump(
    WidgetTester tester,
    SetUpDevicePage page, {
    SetUpProgress? progress,
    Map<String, Object> prefValues = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefValues);
    prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          setUpProgressProvider.overrideWithValue(
            progress ?? setUpProgressOf(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => page)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder stepShown(SetUpStep step) => find.byKey(ValueKey(step));

  test('a location names the step and whether it is a fresh run', () {
    final sync = SetUpDevicePage.fromUri(
      Uri.parse('/settings/setup?step=sync'),
    );
    expect((sync.start, sync.again), (SetUpStep.sync, false));
    final again = SetUpDevicePage.fromUri(
      Uri.parse('/settings/setup?again=true'),
    );
    expect((again.start, again.again), (null, true));
    final unknown = SetUpDevicePage.fromUri(
      Uri.parse('/settings/setup?step=nonsense'),
    );
    expect(unknown.start, isNull);
  });

  /// Stands in for the real steps: each button runs one navigation.
  Widget fakeStep(SetUpStep step, SetUpStepNavigation nav) => Column(
    children: [
      Text('step ${step.name}'),
      TextButton(onPressed: nav.onNext, child: const Text('next')),
      TextButton(onPressed: nav.onBack, child: const Text('back')),
      TextButton(onPressed: nav.onNotNow, child: const Text('not now')),
      if (nav.onSkip != null)
        TextButton(onPressed: nav.onSkip, child: const Text('skip')),
    ],
  );

  testWidgets('opens at the step the progress names next', (tester) async {
    await pump(
      tester,
      SetUpDevicePage(stepBody: fakeStep),
      progress: setUpProgressOf(accountHere: true),
    );
    expect(stepShown(SetUpStep.sync), findsOneWidget);
  });

  testWidgets('a given step wins over the progress', (tester) async {
    await pump(
      tester,
      SetUpDevicePage(start: SetUpStep.backups, stepBody: fakeStep),
      progress: setUpProgressOf(accountHere: true),
    );
    expect(stepShown(SetUpStep.backups), findsOneWidget);
  });

  testWidgets('a fresh run starts at the account step and shows the card '
      'again', (tester) async {
    await pump(
      tester,
      SetUpDevicePage(again: true, stepBody: fakeStep),
      progress: setUpProgressOf(everything: true),
      prefValues: {SetUpCardPrefs.hiddenKey: true},
    );
    expect(stepShown(SetUpStep.account), findsOneWidget);
    expect(prefs.getBool(SetUpCardPrefs.hiddenKey), isFalse);
  });

  testWidgets('Next walks the steps in order, then the done view', (
    tester,
  ) async {
    await pump(tester, SetUpDevicePage(stepBody: fakeStep));

    for (final step in [SetUpStep.sync, SetUpStep.backups, SetUpStep.photos]) {
      await tester.tap(find.text('next'));
      await tester.pumpAndSettle();
      expect(stepShown(step), findsOneWidget);
    }
    expect(find.text('skip'), findsOneWidget, reason: 'only photos skips');

    await tester.tap(find.text('next'));
    await tester.pumpAndSettle();
    expect(find.byKey(SetUpDevicePage.doneKey), findsOneWidget);
  });

  testWidgets('Skip on the photo step goes to the done view', (tester) async {
    await pump(
      tester,
      SetUpDevicePage(start: SetUpStep.photos, stepBody: fakeStep),
    );

    await tester.tap(find.text('skip'));
    await tester.pumpAndSettle();

    expect(find.byKey(SetUpDevicePage.doneKey), findsOneWidget);
  });

  testWidgets('Back moves to the previous step, and closes the flow from the '
      'first', (tester) async {
    await pump(
      tester,
      SetUpDevicePage(start: SetUpStep.sync, stepBody: fakeStep),
    );

    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();
    expect(stepShown(SetUpStep.account), findsOneWidget);

    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();
    expect(find.byType(SetUpDevicePage), findsNothing);
  });

  testWidgets('Not now closes the flow from any step', (tester) async {
    await pump(
      tester,
      SetUpDevicePage(start: SetUpStep.backups, stepBody: fakeStep),
    );

    await tester.tap(find.text('not now'));
    await tester.pumpAndSettle();

    expect(find.byType(SetUpDevicePage), findsNothing);
  });
}
