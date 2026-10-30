import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_job_provider.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/leave_running_import_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late ProviderContainer container;

  ImportJobNotifier job() => container.read(importJobProvider.notifier);

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  ImportCancellationToken startImport({bool continuesWithoutWizard = true}) =>
      job().start(continuesWithoutWizard: continuesWithoutWizard)!;

  Future<GoRouter> pumpWizard(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/wizard',
      routes: [
        GoRoute(
          path: '/wizard',
          onExit: confirmLeaveRunningImport,
          builder: (_, _) => const Text('wizard'),
        ),
        GoRoute(path: '/dives', builder: (_, _) => const Text('dives')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> leave(WidgetTester tester, GoRouter router) async {
    router.go('/dives');
    await tester.pumpAndSettle();
  }

  testWidgets('leaves without asking when no import runs', (tester) async {
    final router = await pumpWizard(tester);

    await leave(tester, router);

    expect(find.text('Import still running'), findsNothing);
    expect(find.text('dives'), findsOneWidget);
  });

  testWidgets('does not ask about an import that already runs on alone', (
    tester,
  ) async {
    final token = startImport();
    job().detach(token);
    final router = await pumpWizard(tester);

    await leave(tester, router);

    expect(find.text('Import still running'), findsNothing);
    expect(find.text('dives'), findsOneWidget);
    expect(token.isCancelled, isFalse);
  });

  testWidgets('continue in background leaves and keeps the import', (
    tester,
  ) async {
    final token = startImport();
    final router = await pumpWizard(tester);

    await leave(tester, router);
    expect(find.text('Import still running'), findsOneWidget);
    await tester.tap(find.text('Continue in background'));
    await tester.pumpAndSettle();

    expect(find.text('dives'), findsOneWidget);
    expect(token.isCancelled, isFalse);
  });

  testWidgets('cancel import leaves and stops the import', (tester) async {
    final token = startImport();
    final router = await pumpWizard(tester);

    await leave(tester, router);
    await tester.tap(find.text('Cancel import'));
    await tester.pumpAndSettle();

    expect(find.text('dives'), findsOneWidget);
    expect(token.isCancelled, isTrue);
    expect(container.read(importJobProvider).isCancellationRequested, isTrue);
  });

  testWidgets('stay keeps the diver on the wizard', (tester) async {
    final token = startImport();
    final router = await pumpWizard(tester);

    await leave(tester, router);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();

    expect(find.text('wizard'), findsOneWidget);
    expect(find.text('dives'), findsNothing);
    expect(token.isCancelled, isFalse);
  });

  testWidgets('dismissing the dialog also stays', (tester) async {
    startImport();
    final router = await pumpWizard(tester);

    await leave(tester, router);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.text('wizard'), findsOneWidget);
  });

  testWidgets('an import that cannot go on alone offers no background', (
    tester,
  ) async {
    final token = startImport(continuesWithoutWizard: false);
    final router = await pumpWizard(tester);

    await leave(tester, router);

    expect(
      find.text('The import has not finished yet. Leaving cancels it.'),
      findsOneWidget,
    );
    expect(find.text('Continue in background'), findsNothing);
    await tester.tap(find.text('Cancel import'));
    await tester.pumpAndSettle();

    expect(find.text('dives'), findsOneWidget);
    expect(token.isCancelled, isTrue);
  });
}
