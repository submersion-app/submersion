import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/finish_step.dart';

import '../../../../../helpers/test_app.dart';
import '../../../../../helpers/test_database.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  testWidgets('start logging applies draft and navigates to dashboard', (
    tester,
  ) async {
    var dashboardShown = false;
    var seeded = false;
    final router = GoRouter(
      initialLocation: '/wizard',
      routes: [
        GoRoute(
          path: '/wizard',
          builder: (context, state) => Consumer(
            builder: (context, ref, _) {
              // Watch keeps the autoDispose family instance alive for the
              // whole test (in production the wizard shell watches it).
              ref.watch(setupWizardProvider(SetupWizardMode.firstRun));
              // Seed a completed fresh-path draft after this build frame
              // (mutating providers during build is forbidden). Once only:
              // the mutation rebuilds this watcher, which must not reseed.
              if (!seeded) {
                seeded = true;
                Future.microtask(() {
                  final notifier = ref.read(
                    setupWizardProvider(SetupWizardMode.firstRun).notifier,
                  );
                  notifier.choosePath(SetupPath.fresh);
                  notifier.setName('Eric');
                });
              }
              return const Scaffold(
                body: FinishStep(mode: SetupWizardMode.firstRun),
              );
            },
          ),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) {
            dashboardShown = true;
            return const Scaffold(body: Text('dashboard'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      testAppRouter(
        router: router,
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("You're all set"), findsOneWidget);
    expect(find.text('Download dives from your dive computer'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.runAsync(() async {
      // Apply performs real DB writes; let them settle outside fake time.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(dashboardShown, isTrue);
    final divers = await tester.runAsync(
      () => DiverRepository().getAllDivers(),
    );
    expect(divers, hasLength(1));
    expect(divers!.single.name, 'Eric');
  });

  testWidgets('apply failure surfaces an error and re-enables the button', (
    tester,
  ) async {
    var seeded = false;
    await tester.pumpWidget(
      testApp(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: Consumer(
          builder: (context, ref, _) {
            ref.watch(setupWizardProvider(SetupWizardMode.firstRun));
            if (!seeded) {
              seeded = true;
              // Fresh path but no name -> applyFirstRun throws ArgumentError.
              Future.microtask(
                () => ref
                    .read(
                      setupWizardProvider(SetupWizardMode.firstRun).notifier,
                    )
                    .choosePath(SetupPath.fresh),
              );
            }
            return const FinishStep(mode: SetupWizardMode.firstRun);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not complete setup'), findsOneWidget);
    // Button re-enabled so the user can retry.
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Get started'),
    );
    expect(button.onPressed, isNotNull);
  });
}
