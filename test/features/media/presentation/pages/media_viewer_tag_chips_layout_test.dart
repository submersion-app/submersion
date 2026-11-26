import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/mini_dive_profile_overlay.dart';
import 'package:submersion/features/media/presentation/widgets/viewer_tag_chips.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';
import 'video_viewer_test_harness.dart';

/// A photo whose file cannot be found: the viewer still draws its panel.
class _UnavailableResolver implements MediaSourceResolver {
  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async =>
      const UnavailableData(kind: UnavailableKind.notFound);
  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

/// The tag chips in the viewer's bottom panel against the mini dive
/// profile chart in the corner (issue #4921): compact, translucent, and
/// never over the chart.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(tearDownTestDatabase);

  // Short names, as the test font draws every letter a full square wide:
  // the rows fill to within a chip of their end, so they would reach the
  // chart were nothing holding them back.
  final manyTags = [
    for (var i = 0; i < 40; i++)
      SpeciesTagChip(
        speciesId: 'sp_$i',
        storedName: 'S$i',
        category: SpeciesCategory.fish,
        isBuiltIn: false,
      ),
  ];

  MediaPersonChip person(String id, String name) => MediaPersonChip(
    tag: MediaPersonTag(
      id: id,
      mediaId: 'v1',
      buddyId: 'b_$id',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    ),
    buddyName: name,
  );

  final people = [for (var i = 0; i < 24; i++) person('p$i', 'P$i')];

  final dive = domain.Dive(
    id: 'd1',
    dateTime: DateTime.utc(2026, 7, 1, 9, 30),
    profile: const [
      domain.DiveProfilePoint(timestamp: 0, depth: 0),
      domain.DiveProfilePoint(timestamp: 600, depth: 18),
      domain.DiveProfilePoint(timestamp: 1800, depth: 12),
      domain.DiveProfilePoint(timestamp: 3000, depth: 0),
    ],
  );

  /// The video, positioned in [dive] so the chart shows.
  MediaItem positioned() => video('v1').copyWith(
    diveId: 'd1',
    enrichment: MediaEnrichment(
      id: 'e-v1',
      mediaId: 'v1',
      diveId: 'd1',
      elapsedSeconds: 1800,
      depthMeters: 12,
      matchConfidence: MatchConfidence.exact,
      createdAt: DateTime.utc(2026, 7, 1),
    ),
  );

  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    bool chart = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpVideoViewer(
      tester,
      prefs,
      overrides: [
        mediaTagChipsProvider('v1').overrideWith((ref) async => manyTags),
        mediaPeopleChipsProvider('v1').overrideWith((ref) async => people),
        if (chart) ...[
          diveProvider('d1').overrideWith((ref) async => dive),
          mediaByIdProvider('v1').overrideWith((ref) async => positioned()),
        ],
      ],
    );
    await tester.pump();
  }

  /// Every chip in the panel, people and species alike.
  Iterable<Rect> chipRects(WidgetTester tester) => [
    for (final chip in find.byType(ActionChip).evaluate())
      tester.getRect(find.byWidget(chip.widget)),
  ];

  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('desktop', const Size(1280, 800)),
  ]) {
    testWidgets('on a $name no chip runs over the mini profile chart', (
      tester,
    ) async {
      await pumpAt(tester, size);

      final chart = tester.getRect(find.byType(MiniDiveProfileOverlay));
      final rects = chipRects(tester);
      // The people chips and the species chips with their "+N" count.
      expect(rects.length, greaterThan(people.length));
      expect(find.byKey(const ValueKey('media_species_more')), findsOneWidget);
      // The depth and time readings under the chips as well.
      final readings = [
        find.byIcon(Icons.arrow_downward),
        find.text('+30:00'),
      ].map(tester.getRect);
      for (final rect in [...rects, ...readings]) {
        expect(
          rect.right <= chart.left || rect.bottom <= chart.top,
          isTrue,
          reason: '$rect clears the chart $chart',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  /// A photo positioned in [dive], so the chart shows, in [locale].
  Future<void> pumpPhoto(WidgetTester tester, Locale locale) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final photo = MediaItem(
      id: 'm1',
      diveId: 'd1',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.platformGallery,
      takenAt: DateTime.utc(2026, 7, 1, 10),
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
      enrichment: MediaEnrichment(
        id: 'e-m1',
        mediaId: 'm1',
        diveId: 'd1',
        elapsedSeconds: 1800,
        depthMeters: 12,
        matchConfidence: MatchConfidence.exact,
        createdAt: DateTime.utc(2026, 7, 1),
      ),
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            mediaSourceResolverRegistryProvider.overrideWithValue(
              MediaSourceResolverRegistry({
                MediaSourceType.platformGallery: _UnavailableResolver(),
              }),
            ),
            diveProvider('d1').overrideWith((ref) async => dive),
            mediaByIdProvider('m1').overrideWith((ref) async => photo),
            mediaTagChipsProvider('m1').overrideWith((ref) async => manyTags),
            mediaPeopleChipsProvider('m1').overrideWith((ref) async => people),
          ],
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaViewerPage(mediaList: [photo], initialMediaId: 'm1'),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });
  }

  // A photo's panel has no scrub bar above it; right to left, the chips
  // start at the right edge, beside the chart, so the inset must stay on
  // the right whichever way the text runs.
  for (final locale in [const Locale('en'), const Locale('he')]) {
    testWidgets('on a photo in ${locale.languageCode} no chip or reading '
        'runs over the mini profile chart', (tester) async {
      await pumpPhoto(tester, locale);

      final chart = tester.getRect(find.byType(MiniDiveProfileOverlay));
      final rects = [
        ...chipRects(tester),
        tester.getRect(find.byIcon(Icons.arrow_downward)),
        tester.getRect(find.byIcon(Icons.timer_outlined)),
      ];
      expect(rects.length, greaterThan(people.length));
      for (final rect in rects) {
        expect(
          rect.right <= chart.left || rect.bottom <= chart.top,
          isTrue,
          reason: '$rect clears the chart $chart',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('without the chart the chips keep the full width', (
    tester,
  ) async {
    await pumpAt(tester, const Size(1280, 800), chart: false);

    expect(find.byType(MiniDiveProfileOverlay), findsNothing);
    final rightmost = chipRects(
      tester,
    ).map((r) => r.right).reduce((a, b) => a > b ? a : b);
    // Out past where the chart's left edge would be.
    expect(rightmost, greaterThan(1280 - PositionedMiniProfileOverlay.span));
  });

  testWidgets('the chips are compact and translucent over the picture', (
    tester,
  ) async {
    await pumpAt(tester, const Size(1280, 800));

    for (final label in ['P0', 'S0']) {
      final style = tester
          .widget<DefaultTextStyle>(
            find
                .ancestor(
                  of: find.text(label),
                  matching: find.byType(DefaultTextStyle),
                )
                .first,
          )
          .style;
      expect(style.fontSize, ViewerTagChips.fontSize, reason: label);
      expect(style.color, ViewerTagChips.foreground, reason: label);

      final chip = find.ancestor(
        of: find.text(label),
        matching: find.byType(ActionChip),
      );
      final theme = ChipTheme.of(tester.element(chip));
      expect(theme.color?.resolve(const {}), ViewerTagChips.fill);
      // 34 px before issue #4921; a chip draws no shorter than 24, plus
      // its hairline.
      expect(tester.getSize(chip).height, lessThanOrEqualTo(25), reason: label);
    }
  });
}
