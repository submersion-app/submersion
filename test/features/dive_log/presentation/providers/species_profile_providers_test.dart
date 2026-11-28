import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/domain/services/profile_depth_at.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/species_profile_providers.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';

/// The species highlighted on a dive's profile (issue #5092).
void main() {
  List<DiveProfilePoint> ramp(double perSecond) => [
    for (var t = 0; t <= 600; t += 10)
      DiveProfilePoint(timestamp: t, depth: t * perSecond),
  ];

  final dive = Dive(
    id: 'd1',
    dateTime: DateTime.utc(2026, 11, 27),
    profile: ramp(0.01),
  );

  const shark = Sighting(
    id: 's1',
    diveId: 'd1',
    speciesId: 'shark',
    speciesName: 'Grey reef shark',
    speciesCategory: SpeciesCategory.shark,
    seenAtSeconds: 300,
  );

  const DiveSpeciesMediaInputs noMedia = (
    media: [],
    tagsByMedia: {},
    identificationsByMedia: {},
  );

  late WidgetRef capturedRef;
  SpeciesProfileHighlight? lastHighlight;

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    List<Sighting> sightings = const [shark],
    SourceProfile? activeSource,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diveSightingsProvider('d1').overrideWith((ref) async => sightings),
          diveSpeciesMediaInputsProvider(
            'd1',
          ).overrideWith((ref) async => noMedia),
          activeSourceProfileProvider('d1').overrideWith((ref) => activeSource),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              lastHighlight = watchSpeciesHighlight(
                ref,
                dive,
                brightness: Brightness.light,
              );
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(SizedBox)));
  }

  testWidgets('toggling a species selects it, then clears it', (tester) async {
    final container = await pump(tester);
    toggleProfileSpecies(capturedRef, 'd1', 'shark');
    expect(container.read(selectedProfileSpeciesProvider('d1')), 'shark');
    toggleProfileSpecies(capturedRef, 'd1', 'shark');
    expect(container.read(selectedProfileSpeciesProvider('d1')), isNull);
  });

  testWidgets('selecting a species clears the selected safety finding', (
    tester,
  ) async {
    final container = await pump(tester);
    container
        .read(selectedSafetyFindingProvider('d1').notifier)
        .state = SafetyFinding(
      id: 'f1',
      diveId: 'd1',
      ruleId: SafetyRuleId.rapidAscent,
      severity: SafetySeverity.caution,
      startTimestamp: 60,
      engineVersion: 1,
      createdAt: DateTime.utc(2026, 11, 27),
    );
    toggleProfileSpecies(capturedRef, 'd1', 'shark');
    expect(container.read(selectedSafetyFindingProvider('d1')), isNull);
  });

  testWidgets('nothing selected gives no highlight', (tester) async {
    await pump(tester);
    expect(lastHighlight, isNull);
  });

  testWidgets('the highlight places the species on the dive profile', (
    tester,
  ) async {
    final container = await pump(tester);
    container.read(selectedProfileSpeciesProvider('d1').notifier).state =
        'shark';
    await tester.pumpAndSettle();
    expect(lastHighlight!.positions.moments.single, (
      seconds: 300,
      depthMeters: profileDepthAt(dive.profile, 300)!,
    ));
    expect(lastHighlight!.color, isNot(Colors.transparent));
  });

  testWidgets('the highlight is the same object while nothing changed', (
    tester,
  ) async {
    // The pinned strip reuses its layer data only for identical inputs, and
    // it rebuilds on every scroll frame.
    final container = await pump(tester);
    container.read(selectedProfileSpeciesProvider('d1').notifier).state =
        'shark';
    await tester.pumpAndSettle();
    final first = lastHighlight;
    expect(
      identical(
        watchSpeciesHighlight(capturedRef, dive, brightness: Brightness.light),
        first,
      ),
      isTrue,
    );
  });

  testWidgets('the highlight uses the active source profile', (tester) async {
    final other = ramp(0.05);
    final container = await pump(
      tester,
      activeSource: SourceProfile(
        sourceId: 'src2',
        computerId: 'c2',
        isEdited: false,
        points: other,
      ),
    );
    container.read(selectedProfileSpeciesProvider('d1').notifier).state =
        'shark';
    await tester.pumpAndSettle();
    expect(
      lastHighlight!.positions.moments.single.depthMeters,
      profileDepthAt(other, 300),
    );
  });

  testWidgets('a selected species with no positions gives no highlight', (
    tester,
  ) async {
    final container = await pump(
      tester,
      sightings: [shark.copyWith(clearSeenAt: true)],
    );
    container.read(selectedProfileSpeciesProvider('d1').notifier).state =
        'shark';
    await tester.pumpAndSettle();
    expect(lastHighlight, isNull);
  });

  testWidgets('a dive with no sightings never loads its media inputs', (
    tester,
  ) async {
    var reads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diveSightingsProvider('d1').overrideWith((ref) async => []),
          diveSpeciesMediaInputsProvider('d1').overrideWith((ref) async {
            reads++;
            return noMedia;
          }),
          activeSourceProfileProvider('d1').overrideWith((ref) => null),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              expect(watchSpeciesPositions(ref, dive), isEmpty);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(reads, 0);
  });

  testWidgets('a rebuilt inputs record with the same contents keeps the '
      'positions object', (tester) async {
    // Records have no guaranteed identity, so the memo compares their parts.
    final media = <MediaItem>[];
    final tags = <String, List<MediaSpeciesTag>>{};
    final ids = <String, List<MediaIdentification>>{};
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diveSightingsProvider('d1').overrideWith((ref) async => [shark]),
          diveSpeciesMediaInputsProvider('d1').overrideWith(
            (ref) async =>
                (media: media, tagsByMedia: tags, identificationsByMedia: ids),
          ),
          activeSourceProfileProvider('d1').overrideWith((ref) => null),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              ref.watch(diveSightingsProvider('d1'));
              ref.watch(diveSpeciesMediaInputsProvider('d1'));
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final first = watchSpeciesPositions(capturedRef, dive);
    expect(first['shark'], isNotNull);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SizedBox)),
    );
    container.invalidate(diveSpeciesMediaInputsProvider('d1'));
    await tester.pumpAndSettle();
    expect(identical(watchSpeciesPositions(capturedRef, dive), first), isTrue);
  });
}
