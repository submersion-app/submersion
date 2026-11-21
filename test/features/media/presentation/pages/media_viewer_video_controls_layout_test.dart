import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/mini_dive_profile_overlay.dart';
import 'package:submersion/features/media/presentation/widgets/video_controls_bar.dart';
import 'package:submersion/features/species_id/presentation/widgets/video_identification_layer.dart';

import '../../../../helpers/test_database.dart';
import 'video_viewer_test_harness.dart';

/// Where a video's scrub bar sits against the tag panel under it (issue
/// #4762): however many tags the video has, the bar stays reachable.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(tearDownTestDatabase);

  /// Enough species tags to wrap the panel's species row over several
  /// lines on a phone.
  final manyTags = [
    for (var i = 0; i < 16; i++)
      SpeciesTagChip(
        speciesId: 'sp_$i',
        storedName: 'Striped species $i',
        category: SpeciesCategory.fish,
        isBuiltIn: false,
      ),
  ];

  /// A phone-sized view, put back when the test ends.
  void usePhoneView(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpTagged(WidgetTester tester) async {
    usePhoneView(tester);
    await pumpVideoViewer(
      tester,
      prefs,
      overrides: [
        mediaTagChipsProvider('v1').overrideWith((ref) async => manyTags),
      ],
    );
    await tester.pump();
  }

  /// Whether a touch at [position] reaches [target]'s render object.
  bool touchReaches(WidgetTester tester, Offset position, Finder target) {
    final result = HitTestResult();
    tester.binding.hitTestInView(result, position, tester.view.viewId);
    final box = tester.renderObject(target);
    return result.path.any((entry) => entry.target == box);
  }

  testWidgets('a touch on the scrub bar reaches it under many tags', (
    tester,
  ) async {
    await pumpTagged(tester);

    final track = find.byKey(VideoControlsBar.trackKey);
    expect(track, findsOneWidget);
    final rect = tester.getRect(track);
    for (final dx in [0.1, 0.5, 0.9]) {
      final point = Offset(rect.left + rect.width * dx, rect.center.dy);
      expect(
        touchReaches(tester, point, track),
        isTrue,
        reason: 'a touch ${(dx * 100).round()}% along the bar is taken',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the scrub bar sits above every tag, not among them', (
    tester,
  ) async {
    await pumpTagged(tester);

    final track = tester.getRect(find.byKey(VideoControlsBar.trackKey));
    final chips = find.byType(ActionChip);
    expect(chips, findsWidgets);
    for (final chip in chips.evaluate()) {
      final box = chip.renderObject! as RenderBox;
      final top = box.localToGlobal(Offset.zero).dy;
      expect(track.bottom, lessThanOrEqualTo(top + 0.5));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('many species stay on one line, so the scrub bar does not '
      'climb the picture (issue #4825)', (tester) async {
    await pumpTagged(tester);
    final tops = {
      for (final chip in find.byType(ActionChip).evaluate())
        (chip.renderObject! as RenderBox).localToGlobal(Offset.zero).dy,
    };
    expect(tops, hasLength(1));
    expect(find.byKey(const ValueKey('media_species_more')), findsOneWidget);
    // The bar sits in the lower part of the phone, under the picture.
    final track = tester.getRect(find.byKey(VideoControlsBar.trackKey));
    expect(track.top, greaterThan(844 * 0.75));
  });

  testWidgets('the scrub bar clears the mini profile chart in the corner', (
    tester,
  ) async {
    usePhoneView(tester);
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
    final positioned = video('v1').copyWith(
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
    await pumpVideoViewer(
      tester,
      prefs,
      overrides: [
        diveProvider('d1').overrideWith((ref) async => dive),
        mediaByIdProvider('v1').overrideWith((ref) async => positioned),
      ],
    );
    await tester.pump();

    final chart = find.byType(MiniDiveProfileOverlay);
    expect(chart, findsOneWidget);
    final track = tester.getRect(find.byKey(VideoControlsBar.trackKey));
    expect(track.bottom, lessThanOrEqualTo(tester.getRect(chart).top));
    expect(
      touchReaches(
        tester,
        track.centerRight - const Offset(8, 0),
        find.byKey(VideoControlsBar.trackKey),
      ),
      isTrue,
      reason: 'the chart does not take the end of the bar',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the fish labels keep above the panel and its scrub bar', (
    tester,
  ) async {
    marineLifeIdEnabled = true;
    addTearDown(resetMarineLifeIdEnabled);
    await pumpTagged(tester);

    final layer = tester.widget<VideoIdentificationLayer>(
      find.byType(VideoIdentificationLayer),
    );
    final layerRect = tester.getRect(find.byType(VideoIdentificationLayer));
    final track = tester.getRect(find.byKey(VideoControlsBar.trackKey));
    // Up from the layer's bottom edge at least as far as the bar's top.
    expect(
      layer.bottomInset,
      greaterThanOrEqualTo(layerRect.bottom - track.top),
    );
    expect(tester.takeException(), isNull);
  });
}
