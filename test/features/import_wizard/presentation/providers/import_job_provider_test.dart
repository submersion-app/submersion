import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_job_provider.dart';

UnifiedImportResult _result({int dives = 0, String? errorMessage}) =>
    UnifiedImportResult(
      importedCounts: {if (dives > 0) ImportEntityType.dives: dives},
      consolidatedCount: 0,
      skippedCount: 0,
      errorMessage: errorMessage,
    );

void main() {
  late ProviderContainer container;
  late int diveListBuilds;
  late int computerListBuilds;

  ImportJobNotifier job() => container.read(importJobProvider.notifier);
  ImportJobState state() => container.read(importJobProvider);

  setUp(() {
    diveListBuilds = 0;
    computerListBuilds = 0;
    container = ProviderContainer(
      overrides: [
        divesProvider.overrideWith((ref) async {
          diveListBuilds++;
          return const <domain.Dive>[];
        }),
        allDiveComputersProvider.overrideWith((ref) async {
          computerListBuilds++;
          return const [];
        }),
      ],
    );
    container.listen(divesProvider, (_, _) {});
    container.listen(allDiveComputersProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  test('refuses a second import while one runs', () {
    final first = job().start(continuesWithoutWizard: true);
    expect(first, isNotNull);
    expect(job().start(continuesWithoutWizard: true), isNull);

    job().finish(first!, result: _result());
    expect(job().start(continuesWithoutWizard: true), isNotNull);
  });

  test('takes progress only from the running import', () {
    final token = job().start(continuesWithoutWizard: true)!;
    job().report(token, ImportPhase.dives, 3, 10);
    job().report(ImportCancellationToken(), ImportPhase.sites, 1, 2);
    expect(state().phase, ImportPhase.dives);
    expect((state().current, state().total), (3, 10));
  });

  test('cancel stops the running import and says so', () {
    final token = job().start(continuesWithoutWizard: true)!;
    job().cancel();
    expect(token.isCancelled, isTrue);
    expect(state().isCancellationRequested, isTrue);
  });

  group('when the wizard goes away', () {
    test('an import that may go on keeps running', () {
      final token = job().start(continuesWithoutWizard: true)!;
      job().detach(token);
      expect(token.isCancelled, isFalse);
      expect(state().isRunning, isTrue);
      expect(state().isAttached, isFalse);
    });

    test('an import that may not go on is cancelled', () {
      final token = job().start(continuesWithoutWizard: false)!;
      job().detach(token);
      expect(token.isCancelled, isTrue);
    });
  });

  group('finish', () {
    test('refreshes the imported lists, wizard open or not', () async {
      await container.read(divesProvider.future);
      final token = job().start(continuesWithoutWizard: true)!;
      job().finish(token, result: _result(dives: 2));
      await container.read(divesProvider.future);
      expect(diveListBuilds, 2);
      expect(state().isRunning, isFalse);
    });

    test('refreshes every import list after a throw', () async {
      await container.read(divesProvider.future);
      final token = job().start(continuesWithoutWizard: true)!;
      job().finish(token);
      await container.read(divesProvider.future);
      expect(diveListBuilds, 2);
    });

    test('refreshes the computer list after a computer download', () async {
      await container.read(allDiveComputersProvider.future);
      final token = job().start(continuesWithoutWizard: false)!;
      job().finish(
        token,
        result: _result(),
        sourceType: ImportSourceType.diveComputer,
      );
      await container.read(allDiveComputersProvider.future);
      expect(computerListBuilds, 2);
    });

    test('leaves no outcome while the wizard shows the summary', () {
      final token = job().start(continuesWithoutWizard: true)!;
      job().finish(token, result: _result(dives: 4));
      expect(state().backgroundOutcome, isNull);
    });

    test('records how an import that ran on alone ended', () {
      ImportJobOutcome? endAlone(
        UnifiedImportResult? result, {
        bool cancel = false,
      }) {
        final token = job().start(continuesWithoutWizard: true)!;
        job().detach(token);
        if (cancel) job().cancel();
        job().finish(token, result: result);
        return state().backgroundOutcome;
      }

      final finished = endAlone(_result(dives: 4))!;
      expect(finished.kind, ImportJobOutcomeKind.finished);
      expect(finished.importedDives, 4);
      expect(
        endAlone(_result(dives: 2), cancel: true)!.kind,
        ImportJobOutcomeKind.stopped,
      );
      expect(
        endAlone(_result(dives: 2, errorMessage: 'stopped before B'))!.kind,
        ImportJobOutcomeKind.stopped,
      );
      expect(
        endAlone(_result(errorMessage: 'boom'))!.kind,
        ImportJobOutcomeKind.failed,
      );
      expect(endAlone(null)!.kind, ImportJobOutcomeKind.failed);
    });

    test('ignores a token that is not the running import', () {
      final token = job().start(continuesWithoutWizard: true)!;
      job().finish(token, result: _result());
      final next = job().start(continuesWithoutWizard: true)!;
      job().finish(token, result: _result());
      expect(state().isRunning, isTrue);
      job().finish(next, result: _result());
    });
  });
}
