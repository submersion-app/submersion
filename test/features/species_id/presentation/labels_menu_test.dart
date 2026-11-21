import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/domain/entities/label_mode.dart';
import 'package:submersion/features/species_id/presentation/providers/label_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/labels_menu.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';
import '../../media/presentation/support/media_widget_harness.dart';
import 'species_id_fakes.dart';

/// The viewer's marine life labels menu (issue #4825).
void main() {
  late RecordingIdentificationService service;

  setUp(() {
    marineLifeIdEnabled = true;
    addTearDown(resetMarineLifeIdEnabled);
    service = RecordingIdentificationService();
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
          labelModeProvider.overrideWith(
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
        child: Consumer(
          builder: (context, ref, _) {
            // The viewer's toolbar keeps these read while it shows.
            if (warm) {
              ref.watch(
                mediaAnalysisStatusProvider(AnalysisTarget(shown, null)),
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
    expect(container.read(labelModeProvider), LabelMode.off);
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
    expect(find.text('Not analysed yet'), findsOneWidget);
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

  testWidgets('the status line cannot be picked', (tester) async {
    await open(tester);
    expect(
      tester.widget<PopupMenuItem<Object>>(entry('status')).enabled,
      isFalse,
    );
  });
}
