import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_chips_row.dart';
import 'package:submersion/features/media/presentation/widgets/viewer_tag_chips.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/presentation/providers/recorded_nearby_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../species_id/presentation/species_id_fakes.dart';
import '../support/media_widget_harness.dart';

const _tang = SpeciesTagChip(
  speciesId: 'sp_blue_tang',
  storedName: 'Blue Tang',
  category: SpeciesCategory.fish,
  isBuiltIn: true,
);

void main() {
  late List<NearbyListRequest> nearbyAsked;

  /// The colour the chip draws the label starting with [prefix] in.
  Color? labelColor(WidgetTester tester, String prefix) => tester
      .widget<DefaultTextStyle>(
        find
            .ancestor(
              of: find.textContaining(prefix),
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      )
      .style
      .color;

  setUp(() {
    marineLifeIdEnabled = true;
    nearbyAsked = [];
  });
  tearDown(resetMarineLifeIdEnabled);

  Future<void> pump(
    WidgetTester tester, {
    List<SpeciesTagChip> chips = const [_tang],
    List<SpeciesSuggestion> suggestions = const [],
    VoidCallback? onSuggestionTap,
    double? progress,
    bool settle = true,
    MediaItem? item,
    NearbySpecies? nearby,
    Completer<NearbySpecies?>? pending,
  }) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          mediaTagChipsProvider('p1').overrideWith((ref) async => chips),
          mediaSuggestionsProvider(
            'p1',
          ).overrideWith((ref) async => suggestions),
          mediaIdentificationProgressProvider(
            'p1',
          ).overrideWith((ref) => Stream.value(progress)),
          recordedNearbyListProvider.overrideWith((ref, request) {
            nearbyAsked.add(request);
            return pending?.future ?? Future.value(nearby);
          }),
        ],
        child: MediaSpeciesChipsRow(
          mediaId: 'p1',
          onSuggestionTap: onSuggestionTap,
          item: item,
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // A progress ring never settles.
      await tester.pump();
      await tester.pump();
    }
  }

  testWidgets('no scan progress is drawn in the row: it is on the scrub bar '
      'and the labels button (issue #4825)', (tester) async {
    await pump(tester, progress: 0.4, settle: false);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('40%'), findsNothing);
  });

  testWidgets('a scan with nothing found yet draws no row', (tester) async {
    await pump(tester, chips: const [], progress: 0.1, settle: false);
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('with no suggestions the row is as before', (tester) async {
    await pump(tester);
    expect(find.byType(ActionChip), findsOneWidget);
    expect(find.text('Blue Tang'), findsOneWidget);
  });

  testWidgets('suggestions follow the tags, with their scores', (tester) async {
    // Wide enough for all three on the one line, in the tests' square font.
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      suggestions: [
        suggestion(parrotfish, score: 0.92),
        suggestion(chromis, score: 0.71, cropId: 'i2'),
      ],
    );
    expect(find.text('Queen Parrotfish 92%'), findsOneWidget);
    expect(find.text('Brown Chromis 71%'), findsOneWidget);
    final first = tester.widgetList<ActionChip>(find.byType(ActionChip)).first;
    expect((first.label as Text).data, 'Blue Tang');
    expect(
      find.byKey(const ValueKey('media_suggested_chip_1')),
      findsOneWidget,
    );
  });

  testWidgets('a tap opens the sheet through the callback', (tester) async {
    var taps = 0;
    await pump(
      tester,
      suggestions: [suggestion(parrotfish)],
      onSuggestionTap: () => taps++,
    );
    await tester.tap(find.byKey(const ValueKey('media_suggested_chip_1')));
    expect(taps, 1);
  });

  testWidgets('with no callback a suggestion is shown but does nothing', (
    tester,
  ) async {
    await pump(tester, suggestions: [suggestion(parrotfish)]);
    // A plain chip, with nothing to press: a disabled ActionChip would fade
    // its label to 38%, unreadable over the picture (issue #4921).
    final chip = find.byKey(const ValueKey('media_suggested_chip_1'));
    expect(tester.widget(chip), isA<Chip>());
    expect(find.byType(ActionChip), findsOneWidget, reason: 'only the tag');
    // As legible as a live one: on a locked photo, as the viewer opens,
    // every suggestion is inert (issue #4921).
    expect(labelColor(tester, 'Queen Parrotfish'), ViewerTagChips.foreground);
  });

  testWidgets('on a locked photo an unconfirmed tag and the count are plain '
      'chips, never faded disabled ones (issue #4921)', (tester) async {
    tester.view.physicalSize = const Size(320, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      chips: [
        const SpeciesTagChip(
          speciesId: 'sp_app',
          storedName: 'Queen Parrotfish',
          category: SpeciesCategory.fish,
          isBuiltIn: true,
          unconfirmed: true,
        ),
        // More of the app's tags than fit, so the count shows; the
        // diver's own would come first and push the one above out.
        for (var i = 0; i < 8; i++)
          SpeciesTagChip(
            speciesId: 'sp_$i',
            storedName: 'Species $i',
            category: SpeciesCategory.fish,
            isBuiltIn: false,
            unconfirmed: true,
          ),
      ],
    );
    for (final key in ['media_unconfirmed_chip_sp_app', 'media_species_more']) {
      final holder = find.byKey(ValueKey(key));
      expect(holder, findsOneWidget, reason: key);
      expect(
        find.descendant(of: holder, matching: find.byType(Chip)),
        findsOneWidget,
        reason: key,
      );
      expect(
        find.descendant(of: holder, matching: find.byType(ActionChip)),
        findsNothing,
        reason: key,
      );
    }
  });

  testWidgets('in the viewer tags and suggestions alike carry the dark '
      'wash, over a clear canvas the picture shows through (issue #4921)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      suggestions: [suggestion(parrotfish)],
      onSuggestionTap: () {},
    );
    for (final chip in [
      find.ancestor(
        of: find.text('Blue Tang'),
        matching: find.byType(ActionChip),
      ),
      find.byKey(const ValueKey('media_suggested_chip_1')),
    ]) {
      expect(tester.widget<ActionChip>(chip).color, isNull);
      expect(
        ChipTheme.of(tester.element(chip)).color?.resolve(const {}),
        ViewerTagChips.fill,
      );
      // The chip paints its fill over a Material of its own, in the
      // canvas colour: white there turned the wash an opaque grey and an
      // unfilled chip a white bar its label vanished into.
      final material = tester.widget<Material>(
        find.descendant(of: chip, matching: find.byType(Material)).first,
      );
      expect(material.color, isNull);
      expect(material.type, MaterialType.canvas);
      expect(
        Theme.of(tester.element(chip)).canvasColor.a,
        0,
        reason: 'the picture shows through the chip',
      );
    }
    expect(labelColor(tester, 'Queen Parrotfish'), ViewerTagChips.foreground);
  });

  testWidgets('a suggestion already shown as a tag is hidden', (tester) async {
    await pump(
      tester,
      chips: const [
        SpeciesTagChip(
          speciesId: 'sp_queen_parrotfish',
          storedName: 'Queen Parrotfish',
          category: SpeciesCategory.fish,
          isBuiltIn: true,
        ),
      ],
      suggestions: [suggestion(parrotfish)],
    );
    expect(find.byKey(const ValueKey('media_suggested_chip_1')), findsNothing);
  });

  testWidgets('switched off, nothing is suggested', (tester) async {
    marineLifeIdEnabled = false;
    await pump(tester, suggestions: [suggestion(parrotfish)]);
    expect(find.byKey(const ValueKey('media_suggested_chip_1')), findsNothing);
  });

  group('Recorded nearby (issue #4668)', () {
    const request = (diveId: 'd1', photo: null);
    Finder pin(int key) => find.descendant(
      of: find.byKey(ValueKey('media_suggested_chip_$key')),
      matching: find.byKey(const ValueKey('recorded_nearby_pin')),
    );

    Future<void> pumpBoth(
      WidgetTester tester, {
      bool withItem = true,
      NearbySpecies? nearby,
      Completer<NearbySpecies?>? pending,
    }) async {
      // Wide enough for every chip on the one line.
      tester.view.physicalSize = const Size(1600, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(
        tester,
        suggestions: [
          suggestion(parrotfish, score: 0.92),
          suggestion(chromis, score: 0.71, cropId: 'i2'),
        ],
        item: withItem ? testMediaItem(id: 'p1', diveId: 'd1') : null,
        nearby: nearby,
        pending: pending,
      );
    }

    testWidgets('a suggestion recorded nearby carries a pin', (tester) async {
      await pumpBoth(tester, nearby: const NearbySpecies(speciesKeys: {1}));
      expect(pin(1), findsOneWidget);
      expect(pin(2), findsNothing);
      expect(nearbyAsked.toSet(), {request});
    });

    testWidgets('the pin is read out with the chip', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpBoth(tester, nearby: const NearbySpecies(speciesKeys: {1}));
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('media_suggested_chip_1')))
            .label,
        contains('Recorded nearby'),
      );
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('media_suggested_chip_2')))
            .label,
        isNot(contains('Recorded nearby')),
      );
      semantics.dispose();
    });

    testWidgets('a catalogue species matches by its id', (tester) async {
      await pumpBoth(
        tester,
        nearby: const NearbySpecies(
          matched: [
            MatchedNearbySpecies(
              speciesId: 'sp_queen_parrotfish',
              occurrenceCount: 4,
            ),
          ],
        ),
      );
      expect(pin(1), findsOneWidget);
      expect(pin(2), findsNothing);
    });

    testWidgets('no pin while the list loads, then it appears', (tester) async {
      final pending = Completer<NearbySpecies?>();
      await pumpBoth(tester, pending: pending);
      expect(pin(1), findsNothing);
      expect(find.text('Queen Parrotfish 92%'), findsOneWidget);
      pending.complete(const NearbySpecies(speciesKeys: {1}));
      await tester.pumpAndSettle();
      expect(pin(1), findsOneWidget);
    });

    testWidgets('no pin when the list cannot be had', (tester) async {
      await pumpBoth(tester);
      expect(pin(1), findsNothing);
      expect(pin(2), findsNothing);
    });

    testWidgets('with no photo given, no list is asked for', (tester) async {
      await pumpBoth(
        tester,
        withItem: false,
        nearby: const NearbySpecies(speciesKeys: {1}),
      );
      expect(pin(1), findsNothing);
      expect(nearbyAsked, isEmpty);
    });
  });
}
