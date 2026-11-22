import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/byte_format.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/pages/setup_wizard_page.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/species_model_step.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/presentation/providers/species_download_prompt_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_pack_controller.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_indicator.dart';

import '../../../../helpers/test_database.dart';
import 'setup_wizard_page_harness.dart';

/// A pack controller for the species model step (issue #4881): no network,
/// and a download that starts and never finishes.
class _StepPackController extends SpeciesPackController {
  var downloads = 0;

  @override
  SpeciesPackState build() =>
      const PackNotInstalled(bytes: 633 * 1024 * 1024, resumable: false);

  @override
  Future<void> refresh() async {}

  @override
  Future<void> download() {
    downloads++;
    state = const PackDownloading(received: 0, total: 633 * 1024 * 1024);
    return Completer<void>().future;
  }

  @override
  Future<bool> downloadFetchesHardwareEngine() async => false;
}

/// The species model step in the setup wizard (issue #4881), walked through
/// the wizard with the shared Set up this device steps stubbed.
void main() {
  // Finish reads the live diver count, so these need a database.
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  group('the species model step (#4881)', () {
    late _StepPackController controller;

    List<Override> offer(Future<bool> offered) {
      controller = _StepPackController();
      return [
        speciesModelOfferProvider.overrideWith((ref) => offered),
        speciesPackControllerProvider.overrideWith(() => controller),
      ];
    }

    SetupWizardDraft draft(WidgetTester tester) {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SetupWizardPage)),
      );
      return container.read(setupWizardProvider(SetupWizardMode.firstRun));
    }

    Future<void> toPhotos(WidgetTester tester) async {
      await throughProfileAndUnits(tester);
      for (var i = 0; i < 3; i++) {
        await tapStub(tester, 'stub next');
      }
      expect(find.text('stub photos firstRun'), findsOneWidget);
    }

    testWidgets('an offered species step runs after Photos and before '
        'Finish', (tester) async {
      await pumpStubbed(
        tester,
        SetupWizardMode.firstRun,
        extra: offer(Future.value(true)),
      );
      await toPhotos(tester);
      await tapStub(tester, 'stub next');
      expect(find.byType(SpeciesModelStep), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Skip'));
      await pumpWizard(tester);
      expect(find.text("You're all set"), findsOneWidget);
    });

    testWidgets('not offered, Photos goes straight to Finish', (tester) async {
      await pumpStubbed(
        tester,
        SetupWizardMode.firstRun,
        extra: offer(Future.value(false)),
      );
      await toPhotos(tester);
      await tapStub(tester, 'stub next');
      expect(find.byType(SpeciesModelStep), findsNothing);
      expect(find.text("You're all set"), findsOneWidget);
    });

    testWidgets('an offer that fails leaves the step out', (tester) async {
      await pumpStubbed(
        tester,
        SetupWizardMode.firstRun,
        extra: [
          speciesModelOfferProvider.overrideWith(
            (ref) async => throw StateError('engine gone'),
          ),
          speciesPackControllerProvider.overrideWith(_StepPackController.new),
        ],
      );
      await toPhotos(tester);
      await tapStub(tester, 'stub next');
      expect(find.byType(SpeciesModelStep), findsNothing);
      expect(find.text("You're all set"), findsOneWidget);
    });

    testWidgets('Back on the species step returns to Photos', (tester) async {
      await pumpStubbed(
        tester,
        SetupWizardMode.firstRun,
        extra: offer(Future.value(true)),
      );
      await toPhotos(tester);
      await tapStub(tester, 'stub next');
      await tester.tap(find.widgetWithText(TextButton, 'Back'));
      await pumpWizard(tester);
      expect(find.text('stub photos firstRun'), findsOneWidget);
    });

    testWidgets('the species step shares the Data dot', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pumpStubbed(
        tester,
        SetupWizardMode.firstRun,
        extra: offer(Future.value(true)),
      );
      await toPhotos(tester);
      await tapStub(tester, 'stub next');
      final indicator = tester.widget<WizardStepIndicator>(
        find.byType(WizardStepIndicator),
      );
      expect(indicator.labels, ['Profile', 'Units', 'Data', 'Done']);
      expect(indicator.currentStep, 2);
      expect(tester.takeException(), isNull);
    });

    // Starting the download turns the live offer off; the step stays in the
    // list, so Download lands on Finish and the list does not shift.
    testWidgets('Download starts it, lands on Finish and keeps the step', (
      tester,
    ) async {
      await pumpStubbed(
        tester,
        SetupWizardMode.firstRun,
        extra: offer(Future.value(true)),
      );
      await toPhotos(tester);
      await tapStub(tester, 'stub next');
      await tester.tap(
        find.widgetWithText(
          FilledButton,
          'Download (${formatBytes(633 * 1024 * 1024)})',
        ),
      );
      await pumpWizard(tester);
      expect(controller.downloads, 1);
      expect(find.text("You're all set"), findsOneWidget);
      expect(draft(tester).speciesModelOffered, isTrue);
      expect(computeSteps(draft(tester)), contains(SetupStepId.speciesModel));
    });

    // The real offer, not an override: on a cold first run nothing else has
    // asked the engine yet, so the availability check is slow. The wizard
    // must hold the offer until it answers, or Riverpod disposes it midway.
    testWidgets('a slow availability check still offers the step', (
      tester,
    ) async {
      marineLifeIdEnabled = true;
      addTearDown(resetMarineLifeIdEnabled);
      controller = _StepPackController();
      await pumpStubbed(
        tester,
        SetupWizardMode.firstRun,
        extra: [
          visionAvailabilityProvider.overrideWith(
            (ref) => Future.delayed(
              const Duration(milliseconds: 200),
              () => VisionAvailability.available,
            ),
          ),
          installedSpeciesPackProvider.overrideWith((ref) async => null),
          speciesDownloadPromptDismissedNotifierProvider.overrideWith(
            (ref) => SpeciesDownloadPromptDismissedNotifier.unstored(false),
          ),
          speciesPackControllerProvider.overrideWith(() => controller),
        ],
      );
      await toPhotos(tester);
      await tapStub(tester, 'stub next');
      expect(find.byType(SpeciesModelStep), findsOneWidget);
    });

    // Cloud sync with no diver: Finish asks for a Profile step that sits
    // after the species step. Back from it finds the step and its download.
    testWidgets('Back from a late Profile returns to the step mid-download', (
      tester,
    ) async {
      await pumpStubbed(
        tester,
        SetupWizardMode.firstRun,
        extra: offer(Future.value(true)),
      );
      await tester.tap(find.text('I have existing Submersion data'));
      await pumpWizard(tester);
      await tester.tap(find.text('Connect cloud sync'));
      await pumpWizard(tester);
      for (var i = 0; i < 4; i++) {
        await tapStub(tester, 'stub next');
      }
      await tester.tap(
        find.widgetWithText(
          FilledButton,
          'Download (${formatBytes(633 * 1024 * 1024)})',
        ),
      );
      await pumpWizard(tester);
      expect(find.text("You're all set"), findsOneWidget);

      await tester.ensureVisible(find.text('Get started'));
      await tester.pump();
      await tester.tap(find.text('Get started'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await pumpWizard(tester);
      expect(find.text('Create Your Profile'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Back'));
      await pumpWizard(tester);
      expect(find.byType(SpeciesModelStep), findsOneWidget);
      expect(
        find.text(
          'Downloading. You can follow it in Settings > Data > Photos & '
          'videos > Species identification.',
        ),
        findsOneWidget,
      );
    });

    // An offer that resolves only once the diver is on Finish would insert
    // the step behind them and shift Finish's place in the list.
    testWidgets('an offer resolving on Finish does not add the step', (
      tester,
    ) async {
      final late = Completer<bool>();
      await pumpStubbed(
        tester,
        SetupWizardMode.firstRun,
        extra: offer(late.future),
      );
      await toPhotos(tester);
      await tapStub(tester, 'stub next');
      expect(find.text("You're all set"), findsOneWidget);
      late.complete(true);
      await pumpWizard(tester);
      expect(find.text("You're all set"), findsOneWidget);
      expect(draft(tester).speciesModelOffered, isFalse);
    });
  });
}
