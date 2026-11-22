import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/byte_format.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/species_model_step.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_downloader.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/presentation/providers/species_download_prompt_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_pack_controller.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A controller held at [_fixed] that records what the step asks of it.
/// [download] never completes, like a real 633 MB download in a test.
class _RecordingPackController extends SpeciesPackController {
  _RecordingPackController(
    this._fixed, {
    this.fetchesEngine = false,
    this.refreshDone,
    this.engineAnswer,
    this.engineThrows = false,
  });
  final SpeciesPackState _fixed;
  final bool fetchesEngine;

  /// When given, refresh() waits on it, as a manifest fetch would.
  final Future<void>? refreshDone;

  /// When given, the hardware engine question waits on it, as the Windows
  /// ML catalogue would.
  final Future<bool>? engineAnswer;

  /// The engine question fails, as an unreachable catalogue would.
  final bool engineThrows;
  var refreshes = 0;
  var downloads = 0;

  @override
  SpeciesPackState build() => _fixed;

  @override
  Future<void> refresh() async {
    refreshes++;
    await refreshDone;
  }

  @override
  Future<void> download() {
    downloads++;
    return Completer<void>().future;
  }

  @override
  Future<bool> downloadFetchesHardwareEngine() async {
    if (engineThrows) throw StateError('catalogue unreachable');
    return await engineAnswer ?? fetchesEngine;
  }
}

/// The species model step of the setup wizard (issue #4881).
void main() {
  const bytes = 633 * 1024 * 1024;
  final l10n = lookupAppLocalizations(const Locale('en'));
  final size = formatBytes(bytes);

  setUp(() {
    marineLifeIdEnabled = true;
    addTearDown(resetMarineLifeIdEnabled);
  });

  late _RecordingPackController controller;
  late int nexts;

  Future<ProviderContainer> pumpStep(
    WidgetTester tester,
    SpeciesPackState state, {
    bool fetchesEngine = false,
    Future<void>? refreshDone,
    Future<bool>? engineAnswer,
    bool engineThrows = false,
  }) async {
    controller = _RecordingPackController(
      state,
      fetchesEngine: fetchesEngine,
      refreshDone: refreshDone,
      engineAnswer: engineAnswer,
      engineThrows: engineThrows,
    );
    nexts = 0;
    final overrides = <Override>[
      speciesPackControllerProvider.overrideWith(() => controller),
      speciesDownloadPromptDismissedNotifierProvider.overrideWith(
        (ref) => SpeciesDownloadPromptDismissedNotifier.unstored(false),
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        // A fresh scope every pump: an updated overrideWith does not replace
        // a controller already built, so a loop would keep the first one.
        key: UniqueKey(),
        overrides: overrides,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SpeciesModelStep(onNext: () => nexts++, onBack: () {}),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return ProviderScope.containerOf(
      tester.element(find.byType(SpeciesModelStep)),
    );
  }

  final download = find.widgetWithText(
    FilledButton,
    l10n.settings_speciesId_download(size),
  );
  final next = find.widgetWithText(
    FilledButton,
    l10n.settings_setUpDevice_next,
  );
  final skip = find.widgetWithText(TextButton, l10n.settings_setUpDevice_skip);

  testWidgets('offers the download with its size, and Skip', (tester) async {
    await pumpStep(
      tester,
      const PackNotInstalled(bytes: bytes, resumable: false),
    );
    expect(find.text(l10n.setup_speciesModel_title), findsOneWidget);
    expect(find.text(l10n.setup_speciesModel_size(size)), findsOneWidget);
    expect(download, findsOneWidget);
    expect(skip, findsOneWidget);
    expect(find.text(l10n.setup_speciesModel_wifi), findsNothing);
    expect(find.text(l10n.setup_speciesModel_hardware), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a partly downloaded pack offers to continue', (tester) async {
    await pumpStep(
      tester,
      const PackNotInstalled(bytes: bytes, resumable: true),
    );
    await tester.tap(
      find.widgetWithText(FilledButton, l10n.settings_speciesId_resume(size)),
    );
    await tester.pump();
    expect(controller.downloads, 1);
  });

  testWidgets(
    'says Wi-Fi is recommended on a phone',
    (tester) async {
      await pumpStep(
        tester,
        const PackNotInstalled(bytes: bytes, resumable: false),
      );
      expect(find.text(l10n.setup_speciesModel_wifi), findsOneWidget);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets('says when Windows may also fetch an engine', (tester) async {
    await pumpStep(
      tester,
      const PackNotInstalled(bytes: bytes, resumable: false),
      fetchesEngine: true,
    );
    expect(find.text(l10n.setup_speciesModel_hardware), findsOneWidget);
  });

  testWidgets('asks the controller where the pack stands once', (tester) async {
    await pumpStep(tester, const PackChecking());
    expect(controller.refreshes, 1);
  });

  testWidgets('Download starts the download and moves on without waiting', (
    tester,
  ) async {
    await pumpStep(
      tester,
      const PackNotInstalled(bytes: bytes, resumable: false),
    );
    await tester.tap(download);
    await tester.pump();
    expect(controller.downloads, 1);
    expect(nexts, 1);
  });

  testWidgets('Skip moves on and leaves the offers alone', (tester) async {
    final container = await pumpStep(
      tester,
      const PackNotInstalled(bytes: bytes, resumable: false),
    );
    await tester.tap(skip);
    await tester.pump();
    expect(nexts, 1);
    expect(controller.downloads, 0);
    expect(
      container.read(speciesDownloadPromptDismissedNotifierProvider),
      isFalse,
    );
  });

  testWidgets('offline, it points at Settings and moves on with Next', (
    tester,
  ) async {
    await pumpStep(
      tester,
      const PackFailed(reason: PackDownloadFailure.network, bytes: 0),
    );
    expect(find.text(l10n.setup_speciesModel_later), findsOneWidget);
    expect(download, findsNothing);
    await tester.tap(next);
    expect(nexts, 1);
  });

  testWidgets('a pack that cannot be had points at Settings too', (
    tester,
  ) async {
    for (final state in const <SpeciesPackState>[
      PackNotPublished(),
      PackNotForThisDevice(),
      PackNeedsAppUpdate(),
      PackUnsupported(VisionAvailability.deviceNotEligible),
    ]) {
      final container = await pumpStep(tester, state);
      expect(
        container.read(speciesPackControllerProvider),
        same(state),
        reason: '${state.runtimeType}',
      );
      expect(
        find.text(l10n.setup_speciesModel_later),
        findsOneWidget,
        reason: '${state.runtimeType}',
      );
      expect(next, findsOneWidget, reason: '${state.runtimeType}');
    }
  });

  testWidgets('while it downloads or installs, it says where to follow it', (
    tester,
  ) async {
    for (final state in const <SpeciesPackState>[
      PackDownloading(received: 1, total: bytes),
      PackInstalling(),
    ]) {
      final container = await pumpStep(tester, state);
      expect(
        container.read(speciesPackControllerProvider),
        same(state),
        reason: '${state.runtimeType}',
      );
      expect(
        find.text(l10n.setup_speciesModel_downloading),
        findsOneWidget,
        reason: '${state.runtimeType}',
      );
      expect(next, findsOneWidget, reason: '${state.runtimeType}');
    }
  });

  testWidgets('once installed, it says so and moves on with Next', (
    tester,
  ) async {
    await pumpStep(tester, const PackInstalled(version: '1', bytes: bytes));
    expect(find.text(l10n.setup_speciesModel_installed), findsOneWidget);
    expect(next, findsOneWidget);
  });

  // A state left from an earlier visit to Settings may be stale: Download
  // waits for the step's own check, which a download it started would
  // otherwise have overwritten.
  testWidgets('Download waits for the step\'s own check to answer', (
    tester,
  ) async {
    final done = Completer<void>();
    await pumpStep(
      tester,
      const PackNotInstalled(bytes: bytes, resumable: false),
      refreshDone: done.future,
    );
    // Until it answers, the step shows it is checking, not a dead button.
    expect(download, findsNothing);
    expect(find.text(l10n.setup_speciesModel_size(size)), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, l10n.setup_speciesModel_download),
          )
          .onPressed,
      isNull,
    );
    done.complete();
    await tester.pump();
    await tester.pump();
    expect(tester.widget<FilledButton>(download).onPressed, isNotNull);
  });

  // A failure left in the controller by an earlier visit to Settings may be
  // stale: the step shows its own check, not "can't reach", until it answers.
  testWidgets('a failure left from Settings waits for the step\'s own check', (
    tester,
  ) async {
    final done = Completer<void>();
    await pumpStep(
      tester,
      const PackFailed(reason: PackDownloadFailure.network, bytes: 0),
      refreshDone: done.future,
    );
    expect(find.text(l10n.setup_speciesModel_later), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(next, findsNothing);
    done.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.setup_speciesModel_later), findsOneWidget);
  });

  // The Windows ML line is the confirmation that an engine comes too: no
  // Download before the engine question has answered.
  testWidgets('Download waits for the hardware engine question too', (
    tester,
  ) async {
    final engine = Completer<bool>();
    await pumpStep(
      tester,
      const PackNotInstalled(bytes: bytes, resumable: false),
      engineAnswer: engine.future,
    );
    expect(download, findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    engine.complete(true);
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.setup_speciesModel_hardware), findsOneWidget);
    expect(tester.widget<FilledButton>(download).onPressed, isNotNull);
  });

  testWidgets('a failed engine question counts as no engine', (tester) async {
    await pumpStep(
      tester,
      const PackNotInstalled(bytes: bytes, resumable: false),
      engineThrows: true,
    );
    expect(find.text(l10n.setup_speciesModel_hardware), findsNothing);
    expect(tester.widget<FilledButton>(download).onPressed, isNotNull);
  });

  testWidgets('while checking, Download waits for the size', (tester) async {
    await pumpStep(tester, const PackChecking());
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text(l10n.setup_speciesModel_download),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(skip, findsOneWidget);
  });
}
