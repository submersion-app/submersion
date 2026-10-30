import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_job_provider.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/running_import_gate.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _nothing = UnifiedImportResult(
  importedCounts: {},
  consolidatedCount: 0,
  skippedCount: 0,
);

void main() {
  late ProviderContainer container;

  ImportJobNotifier job() => container.read(importJobProvider.notifier);

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  Future<void> pumpGate(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RunningImportGate(title: 'File Import', child: Text('wizard')),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('opens the wizard straight away when nothing runs', (
    tester,
  ) async {
    await pumpGate(tester);
    expect(find.text('wizard'), findsOneWidget);
  });

  testWidgets('its own import later does not hide the wizard', (tester) async {
    await pumpGate(tester);
    job().start(continuesWithoutWizard: true);
    await tester.pump();
    expect(find.text('wizard'), findsOneWidget);
  });

  testWidgets('holds the wizard back while another import runs', (
    tester,
  ) async {
    final token = job().start(continuesWithoutWizard: true)!;
    job().report(token, ImportPhase.dives, 3, 10);
    await pumpGate(tester);

    expect(find.text('wizard'), findsNothing);
    expect(find.text('An import is still running'), findsOneWidget);
    expect(find.text('Importing dives...'), findsOneWidget);
    expect(find.text('3 of 10'), findsOneWidget);

    job().finish(token, result: _nothing);
    await tester.pump();

    expect(find.text('wizard'), findsOneWidget);
  });

  testWidgets('cancels the running import from there', (tester) async {
    final token = job().start(continuesWithoutWizard: true)!;
    await pumpGate(tester);

    await tester.tap(find.byKey(const Key('running_import_cancel_button')));
    await tester.pump();

    expect(token.isCancelled, isTrue);
    expect(find.text('Cancelling...'), findsOneWidget);
  });
}
