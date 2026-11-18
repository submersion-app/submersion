import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_sitting_follow_up.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_annotations_provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';

/// What a saved sitting owes once its write has committed, for the cards
/// plan 6 brought in (issue #4527).
void main() {
  final before = Dive(id: 'dive-1', dateTime: DateTime.utc(2026));
  final after = before.copyWith(notes: 'saved');

  late ProviderContainer container;
  late List<(String, String?)> adopted;
  late Map<String, int> builds;
  late List<String> refreshed;
  late List<Dive> tides;
  late List<(String, GeoPoint)> altitudeLookups;

  setUp(() {
    adopted = [];
    builds = {};
    refreshed = [];
    tides = [];
    altitudeLookups = [];
    int count(String name) => builds[name] = (builds[name] ?? 0) + 1;
    container = ProviderContainer(
      overrides: [
        unitFormatterProvider.overrideWithValue(
          const UnitFormatter(AppSettings()),
        ),
        diveGearRefreshProvider.overrideWithValue(refreshed.add),
        diveTideRecordProvider.overrideWithValue(
          (dive) async => tides.add(dive),
        ),
        diveSiteAltitudeFillProvider.overrideWithValue(
          (siteId, point) async => altitudeLookups.add((siteId, point)),
        ),
        divePlanLinkAdoptProvider.overrideWithValue(
          (planId, diveId) => adopted.add((planId, diveId)),
        ),
        diveAnnotationsProvider.overrideWith((ref, id) async {
          count('annotations');
          return const [];
        }),
        diveSightingsProvider.overrideWith((ref, id) async {
          count('sightings');
          return const [];
        }),
        mediaForDiveProvider.overrideWith((ref, id) async {
          count('media');
          return const [];
        }),
      ],
    );
    addTearDown(container.dispose);
    for (final p in [
      diveAnnotationsProvider(before.id),
      diveSightingsProvider(before.id),
      mediaForDiveProvider(before.id),
    ]) {
      container.listen(p, (_, _) {}, fireImmediately: true);
    }
  });

  Future<DiveSittingFollowUp> followUp(WidgetTester tester) async {
    late DiveSittingFollowUp made;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                made = DiveSittingFollowUp.read(context, ref);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return made;
  }

  Future<void> run(
    WidgetTester tester,
    DiveSittingFollowUp f, {
    required Set<String> changed,
    List<Future<void> Function()> mediaAfterCommit = const [],
    List<(String, String?)> planLinksAdopted = const [],
  }) async {
    await f.run(
      before: before,
      after: after,
      tripDateStretches: const [],
      changedCardIds: changed,
      mediaAfterCommit: mediaAfterCommit,
      planLinksAdopted: planLinksAdopted,
    );
    await tester.pump();
  }

  testWidgets('a media upload queue that throws after the write is not a '
      'failed save; the rest still run', (tester) async {
    final f = await followUp(tester);
    final ran = <int>[];
    await run(
      tester,
      f,
      changed: {'media'},
      mediaAfterCommit: [
        () async => throw StateError('queue closed'),
        () async => ran.add(2),
      ],
    );
    expect(ran, [2]);
    expect(builds['media'], 2);
  });

  testWidgets("each card's providers are invalidated only when it changed", (
    tester,
  ) async {
    final f = await followUp(tester);
    await run(tester, f, changed: {'sightings'});
    expect(builds['sightings'], 2);
    expect(builds['annotations'], 1);
    expect(builds['media'], 1);

    await run(tester, f, changed: {'notes'});
    expect(builds['annotations'], 2);
    expect(builds['sightings'], 2);
  });

  testWidgets('the plan link is adopted after a Compare change', (
    tester,
  ) async {
    final f = await followUp(tester);
    await run(
      tester,
      f,
      changed: {'diveLab'},
      planLinksAdopted: const [('plan-1', 'dive-1'), ('plan-0', null)],
    );
    expect(adopted, [('plan-1', 'dive-1'), ('plan-0', null)]);

    adopted.clear();
    await run(
      tester,
      f,
      changed: {'notes'},
      planLinksAdopted: const [('plan-1', 'dive-1')],
    );
    expect(adopted, isEmpty);
  });

  // The dive form scans, and works out gas use and gear hours again, after
  // every save. A sitting does it when a card that feeds them changed: the
  // cylinders, gear and weights, and the header, whose times, depths and
  // site the findings and gas use are worked out from (issue #4527).
  testWidgets('a header change refreshes what the dive\'s values feed', (
    tester,
  ) async {
    final f = await followUp(tester);
    await run(tester, f, changed: {'header'});
    expect(refreshed, ['dive-1']);

    await run(tester, f, changed: {'notes'});
    expect(refreshed, ['dive-1']);
  });

  // The dive form records the tide after a save, at the site and time the
  // dive was saved with. A sitting does it when what the tide is worked out
  // from moved: the site, the entry time, or the water type.
  group('the tide', () {
    const reef = DiveSite(
      id: 'reef',
      name: 'Reef',
      location: GeoPoint(-16.5, 145.8),
    );
    final atReef = before.copyWith(site: reef);

    Future<void> save(WidgetTester tester, Dive was, Dive now) async {
      final f = await followUp(tester);
      await f.run(
        before: was,
        after: now,
        tripDateStretches: const [],
        changedCardIds: const {'header'},
        mediaAfterCommit: const [],
      );
      await tester.pump();
    }

    testWidgets('is recorded for a dive moved to a site', (tester) async {
      await save(tester, before, atReef);
      expect(tides, [atReef]);
    });

    testWidgets('is recorded for a dive moved to another time', (tester) async {
      final later = atReef.copyWith(entryTime: DateTime.utc(2026, 1, 1, 9));
      await save(tester, atReef, later);
      expect(tides, [later]);
    });

    testWidgets('is recorded for a dive given another water type', (
      tester,
    ) async {
      final salt = atReef.copyWith(waterType: WaterType.salt);
      await save(tester, atReef, salt);
      expect(tides, [salt]);
    });

    testWidgets('is not recorded when none of those moved', (tester) async {
      await save(tester, atReef, atReef.copyWith(notes: 'saved'));
      expect(tides, isEmpty);
    });
  });

  // A location added from the site suggestion is written at Save, inside
  // its transaction, which notes the site. Its altitude is looked up once
  // the write has committed, as the immediate path does after its own
  // (`SiteMatchingService.applyConfirmed`), never inside it (issue #4527).
  testWidgets("a site the save gave a location has its altitude looked up", (
    tester,
  ) async {
    const point = GeoPoint(-16.5, 145.8);
    final f = await followUp(tester);
    await f.run(
      before: before,
      after: after,
      tripDateStretches: const [],
      changedCardIds: const {'header'},
      mediaAfterCommit: const [],
      sitesLocated: const {'reef': point},
    );
    await tester.pump();

    expect(altitudeLookups, [('reef', point)]);
  });

  testWidgets('no site given a location, no altitude looked up', (
    tester,
  ) async {
    await run(tester, await followUp(tester), changed: const {'header'});
    expect(altitudeLookups, isEmpty);
  });
  // The save's `after` is the sitting's copy, whose site has no location
  // yet when the location was a held write: the tide is worked out at the
  // point the save gave the site.
  testWidgets('the tide is recorded at the location the save gave the site', (
    tester,
  ) async {
    const point = GeoPoint(-16.5, 145.8);
    const bare = DiveSite(id: 'reef', name: 'Reef');
    final atBare = before.copyWith(site: bare);
    final f = await followUp(tester);
    await f.run(
      before: atBare,
      after: atBare.copyWith(notes: 'saved'),
      tripDateStretches: const [],
      changedCardIds: const {'header'},
      mediaAfterCommit: const [],
      sitesLocated: const {'reef': point},
    );
    await tester.pump();

    expect(tides.map((d) => d.site?.location), [point]);
  });
}
