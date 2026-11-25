import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/widgets/media_viewer_toolbar.dart';
import 'package:submersion/features/species_id/domain/entities/label_mode.dart';
import 'package:submersion/features/species_id/presentation/providers/label_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/labels_menu.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';
import '../../media/presentation/support/media_widget_harness.dart';
import 'species_id_fakes.dart';

/// The viewer's marine life labels menu (issue #4825).
void main() {
  late RecordingIdentificationService service;

  /// Whether the button stays up: the viewer hides its controls, toolbar
  /// and all, a few seconds into a playing video.
  late ValueNotifier<bool> toolbarUp;

  setUp(() {
    marineLifeIdEnabled = true;
    addTearDown(resetMarineLifeIdEnabled);
    service = RecordingIdentificationService();
    toolbarUp = ValueNotifier(true);
    addTearDown(toolbarUp.dispose);
  });

  Future<void> open(
    WidgetTester tester, {
    MediaItem? item,
    LabelMode mode = LabelMode.names,
    MediaAnalysisState state = MediaAnalysisState.analysed,
    int found = 3,
    bool busy = false,
    double? progress,
    bool warm = true,
  }) async {
    final shown = item ?? testMediaItem(id: 'm1');
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          mediaIdentificationServiceProvider.overrideWithValue(service),
          labelModeNotifierProvider.overrideWith(
            (ref) => LabelModeNotifier.unstored(mode),
          ),
          mediaAnalysisStatusProvider(AnalysisTarget(shown, null)).overrideWith(
            (ref) async {
              // Not read ahead: still loading when the menu is opened.
              if (!warm) await Future<void>.delayed(const Duration(seconds: 1));
              return (state: state, found: found);
            },
          ),
          mediaIdentificationBusyProvider(
            shown.id,
          ).overrideWith((ref) => Stream.value(busy)),
          mediaIdentificationProgressProvider(
            shown.id,
          ).overrideWith((ref) => Stream.value(progress)),
        ],
        child: ValueListenableBuilder<bool>(
          valueListenable: toolbarUp,
          builder: (context, up, _) => up
              ? Consumer(
                  builder: (context, ref, _) {
                    // The viewer's toolbar keeps these read while it shows.
                    if (warm) {
                      ref.watch(
                        mediaAnalysisStatusProvider(
                          AnalysisTarget(shown, null),
                        ),
                      );
                    }
                    ref
                      ..watch(mediaIdentificationBusyProvider(shown.id))
                      ..watch(mediaIdentificationProgressProvider(shown.id));
                    return Center(
                      child: Builder(
                        builder: (anchor) => TextButton(
                          onPressed: () => showMarineLifeLabelsMenu(
                            anchor,
                            ref,
                            item: shown,
                            location: null,
                          ),
                          child: const Text('labels'),
                        ),
                      ),
                    );
                  },
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('labels'));
    if (!warm) await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  Finder entry(String key) => find.byKey(ValueKey('labels_menu_$key'));

  bool checked(WidgetTester tester, String key) =>
      tester.widget<CheckedPopupMenuItem<Object>>(entry(key)).checked;

  testWidgets('checks the mode in force', (tester) async {
    await open(tester, mode: LabelMode.allLife);
    expect(find.text('Names'), findsOneWidget);
    expect(find.text('All life'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    expect(checked(tester, 'all_life'), isTrue);
    expect(checked(tester, 'names'), isFalse);
    expect(checked(tester, 'off'), isFalse);
  });

  testWidgets('a mode picked is the one in force', (tester) async {
    await open(tester);
    await tester.tap(entry('off'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.text('labels')),
    );
    expect(container.read(labelModeNotifierProvider), LabelMode.off);
  });

  testWidgets('an item fully analysed offers Analyse again, and asks for '
      'it from the start', (tester) async {
    await open(tester);
    expect(find.text('Analyse again'), findsOneWidget);
    expect(find.text('3 found'), findsOneWidget);
    await tester.tap(entry('analyse'));
    await tester.pumpAndSettle();
    expect(service.requested, ['m1']);
    expect(service.byHand, [true]);
    expect(service.fresh, [true]);
  });

  testWidgets('an item not fully analysed offers Analyse, by hand but not '
      'from the start', (tester) async {
    await open(tester, state: MediaAnalysisState.partial, found: 0);
    expect(find.text('Analyse'), findsOneWidget);
    expect(find.text('Partly analysed, nothing found'), findsOneWidget);
    await tester.tap(entry('analyse'));
    await tester.pumpAndSettle();
    expect(service.byHand, [true]);
    expect(service.fresh, [false]);
  });

  testWidgets('while a video is analysed the status gives the percentage, '
      'and the action waits', (tester) async {
    await open(
      tester,
      item: testMediaItem(id: 'v1', mediaType: MediaType.video),
      state: MediaAnalysisState.partial,
      busy: true,
      progress: 0.42,
    );
    expect(find.text('Analysing, 42%'), findsOneWidget);
    expect(
      tester.widget<PopupMenuItem<Object>>(entry('analyse')).enabled,
      isFalse,
    );
  });

  testWidgets('part analysed, the status says so with what was found '
      '(issue #4958)', (tester) async {
    await open(tester, state: MediaAnalysisState.partial, found: 3);
    expect(find.text('Partly analysed, 3 found'), findsOneWidget);
  });

  testWidgets('out of date, the status says what was found, not that it '
      'stopped part way (issue #4958)', (tester) async {
    await open(tester, state: MediaAnalysisState.outdated, found: 3);
    expect(find.text('3 found'), findsOneWidget);
    expect(find.text('Analyse'), findsOneWidget);
  });

  testWidgets('with no model the status says so and the action waits', (
    tester,
  ) async {
    await open(tester, state: MediaAnalysisState.noModel, found: 0);
    expect(find.text('No species model installed'), findsOneWidget);
    expect(
      tester.widget<PopupMenuItem<Object>>(entry('analyse')).enabled,
      isFalse,
    );
  });

  testWidgets('opened before the status has loaded, it waits for it', (
    tester,
  ) async {
    await open(tester, warm: false);
    expect(find.text('Analyse again'), findsOneWidget);
    expect(find.text('3 found'), findsOneWidget);
  });

  group('where the models cannot run (issue #4876)', () {
    setUp(() {
      marineLifeIdEnabled = false;
      marineLifeLabelsShown = true;
    });

    testWidgets('the modes show, and nothing offers to analyse', (
      tester,
    ) async {
      await open(tester, state: MediaAnalysisState.foundNoModel, found: 2);
      expect(entry('names'), findsOneWidget);
      expect(entry('all_life'), findsOneWidget);
      expect(entry('off'), findsOneWidget);
      expect(entry('analyse'), findsNothing);
      expect(find.text('2 found'), findsOneWidget);
    });
  });

  group('when the toolbar hides under the open menu', () {
    testWidgets('a mode picked is still the one in force', (tester) async {
      await open(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ValueListenableBuilder<bool>).first),
      );
      toolbarUp.value = false;
      await tester.pump();
      await tester.tap(entry('all_life'));
      await tester.pumpAndSettle();
      expect(container.read(labelModeNotifierProvider), LabelMode.allLife);
    });

    testWidgets('Analyse again is still asked for', (tester) async {
      await open(tester);
      toolbarUp.value = false;
      await tester.pump();
      await tester.tap(entry('analyse'));
      await tester.pumpAndSettle();
      expect(service.requested, ['m1']);
      expect(service.fresh, [true]);
    });
  });

  testWidgets('the status line cannot be picked', (tester) async {
    await open(tester);
    expect(
      tester.widget<PopupMenuItem<Object>>(entry('status')).enabled,
      isFalse,
    );
  });

  group('the toolbar action', () {
    /// What the toolbar's labels action is on [item].
    Future<
      ({
        bool offered,
        bool on,
        ToolbarRing? ring,
        ToolbarTone? tone,
        String? label,
      })
    >
    action(
      WidgetTester tester,
      MediaItem item, {
      bool busy = false,
      double? progress,
      LabelMode mode = LabelMode.names,
      MediaAnalysisState state = MediaAnalysisState.analysed,
    }) async {
      final overrides = await getBaseOverrides();
      ({
        bool offered,
        bool on,
        ToolbarRing? ring,
        ToolbarTone? tone,
        String? label,
      })?
      result;
      await tester.pumpWidget(
        testApp(
          overrides: [
            ...overrides,
            mediaIdentificationServiceProvider.overrideWithValue(service),
            labelModeNotifierProvider.overrideWith(
              (ref) => LabelModeNotifier.unstored(mode),
            ),
            mediaAnalysisStatusProvider(
              AnalysisTarget(item, null),
            ).overrideWith((ref) async => (state: state, found: 0)),
            mediaIdentificationBusyProvider(
              item.id,
            ).overrideWith((ref) => Stream.value(busy)),
            mediaIdentificationProgressProvider(
              item.id,
            ).overrideWith((ref) => Stream.value(progress)),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final labels = marineLifeLabelsAction(ref, item, null);
              final status = labels.status;
              result = (
                offered: labels.onPressed != null,
                on: labels.on,
                ring: labels.ring,
                tone: labels.tone,
                label: status == null
                    ? null
                    : labelsButtonLabel(context.l10n, status),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return result!;
    }

    /// Whether the toolbar offers the labels menu on [item].
    Future<bool> offered(WidgetTester tester, MediaItem item) async =>
        (await action(tester, item)).offered;

    final video = testMediaItem(id: 'v1', mediaType: MediaType.video);

    testWidgets('draws no ring on an item not being analysed', (tester) async {
      expect((await action(tester, video)).ring, isNull);
    });

    testWidgets('fills a video\'s ring as far as its scan has got', (
      tester,
    ) async {
      final ring = (await action(
        tester,
        video,
        busy: true,
        progress: 0.4,
      )).ring;
      expect(ring?.value, 0.4);
    });

    testWidgets('spins the ring on a photo being analysed', (tester) async {
      final ring = (await action(
        tester,
        testMediaItem(id: 'p1'),
        busy: true,
      )).ring;
      expect(ring, isNotNull);
      expect(ring!.value, isNull);
    });

    // On draws a fish, off a struck fish (issue #4926).
    for (final (mode, on) in [
      (LabelMode.names, true),
      (LabelMode.allLife, true),
      (LabelMode.off, false),
    ]) {
      testWidgets('reads labels as on in ${mode.name}: $on', (tester) async {
        expect(
          (await action(tester, testMediaItem(id: 'p1'), mode: mode)).on,
          on,
        );
      });
    }

    // Its colour says how far analysis has got (issue #4926).
    for (final (state, tone) in [
      (MediaAnalysisState.notAnalysed, null),
      (MediaAnalysisState.noModel, null),
      (MediaAnalysisState.partial, ToolbarTone.warn),
      (MediaAnalysisState.outdated, ToolbarTone.warn),
      (MediaAnalysisState.analysed, ToolbarTone.ok),
      (MediaAnalysisState.foundNoModel, ToolbarTone.ok),
      (MediaAnalysisState.partFoundNoModel, ToolbarTone.warn),
    ]) {
      testWidgets('colours the icon for ${state.name}: ${tone?.name}', (
        tester,
      ) async {
        expect(
          (await action(tester, testMediaItem(id: 'p1'), state: state)).tone,
          tone,
        );
      });
    }

    // Its tooltip says what the colour means (issue #4958).
    for (final (state, label) in [
      (MediaAnalysisState.notAnalysed, 'Species labels: not analysed'),
      (MediaAnalysisState.noModel, 'Species labels: not analysed'),
      (MediaAnalysisState.partial, 'Species labels: partly analysed'),
      (MediaAnalysisState.outdated, 'Species labels: out of date'),
      (MediaAnalysisState.analysed, 'Species labels: analysed'),
      (MediaAnalysisState.foundNoModel, 'Species labels: analysed'),
      (MediaAnalysisState.partFoundNoModel, 'Species labels: partly analysed'),
    ]) {
      testWidgets('names the state for ${state.name}: $label', (tester) async {
        expect(
          (await action(tester, testMediaItem(id: 'p1'), state: state)).label,
          label,
        );
      });
    }

    testWidgets('names the state as analysing while it is analysed', (
      tester,
    ) async {
      expect(
        (await action(
          tester,
          testMediaItem(id: 'p1'),
          busy: true,
          state: MediaAnalysisState.partial,
        )).label,
        'Species labels: analysing',
      );
    });

    testWidgets('colours the icon as under way while it is analysed', (
      tester,
    ) async {
      expect(
        (await action(
          tester,
          testMediaItem(id: 'p1'),
          busy: true,
          state: MediaAnalysisState.notAnalysed,
        )).tone,
        ToolbarTone.active,
      );
    });

    testWidgets('changes colour when the status does', (tester) async {
      final item = testMediaItem(id: 'p1');
      final status = mediaAnalysisStatusProvider(AnalysisTarget(item, null));
      var stored = MediaAnalysisState.notAnalysed;
      ToolbarTone? tone;
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        testApp(
          overrides: [
            ...overrides,
            mediaIdentificationServiceProvider.overrideWithValue(service),
            status.overrideWith((ref) async => (state: stored, found: 0)),
            mediaIdentificationBusyProvider(
              item.id,
            ).overrideWith((ref) => Stream.value(false)),
            mediaIdentificationProgressProvider(
              item.id,
            ).overrideWith((ref) => Stream.value(null)),
          ],
          child: Consumer(
            key: const ValueKey('labels_action_host'),
            builder: (context, ref, _) {
              tone = marineLifeLabelsAction(ref, item, null).tone;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tone, isNull);
      stored = MediaAnalysisState.analysed;
      ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('labels_action_host'))),
      ).invalidate(status);
      await tester.pumpAndSettle();
      expect(tone, ToolbarTone.ok);
    });

    testWidgets('is offered on a photo', (tester) async {
      expect(await offered(tester, testMediaItem(id: 'p1')), isTrue);
    });

    testWidgets('is offered on a video', (tester) async {
      expect(
        await offered(
          tester,
          testMediaItem(id: 'v1', mediaType: MediaType.video),
        ),
        isTrue,
      );
    });

    testWidgets('is not offered on a Lightroom-linked video: only its '
        'poster is on the device, so it can never be scanned', (tester) async {
      expect(
        await offered(
          tester,
          testMediaItem(
            id: 'v1',
            mediaType: MediaType.video,
            sourceType: MediaSourceType.serviceConnector,
          ),
        ),
        isFalse,
      );
    });

    testWidgets('keeps the status read, and is not rebuilt as it reloads', (
      tester,
    ) async {
      final item = testMediaItem(id: 'p1');
      final status = mediaAnalysisStatusProvider(AnalysisTarget(item, null));
      final overrides = await getBaseOverrides();
      var builds = 0;
      await tester.pumpWidget(
        testApp(
          overrides: [
            ...overrides,
            mediaIdentificationServiceProvider.overrideWithValue(service),
            status.overrideWith(
              (ref) async => (state: MediaAnalysisState.analysed, found: 0),
            ),
            mediaIdentificationBusyProvider(
              item.id,
            ).overrideWith((ref) => Stream.value(false)),
            mediaIdentificationProgressProvider(
              item.id,
            ).overrideWith((ref) => Stream.value(null)),
          ],
          child: Consumer(
            key: const ValueKey('labels_action_host'),
            builder: (context, ref, _) {
              builds++;
              marineLifeLabelsAction(ref, item, null);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('labels_action_host'))),
      );
      expect(container.read(status).value?.state, MediaAnalysisState.analysed);
      final before = builds;
      container.invalidate(status);
      await tester.pumpAndSettle();
      expect(container.exists(status), isTrue);
      expect(builds, before);
    });

    testWidgets('is offered on a Lightroom-linked photo', (tester) async {
      expect(
        await offered(
          tester,
          testMediaItem(id: 'p1', sourceType: MediaSourceType.serviceConnector),
        ),
        isTrue,
      );
    });
  });
}
