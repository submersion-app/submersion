import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/services/species_batch_planner.dart';
import 'package:submersion/features/species_id/domain/entities/species_batch.dart';

/// Counting what Find species over many dives will do, before it starts
/// (issue #5127).
void main() {
  late Map<String, List<MediaItem>> media;
  late Set<String> upToDate;
  late Set<String> openSuggestions;
  late bool canApply;
  late Set<String> libraryHere;
  late List<List<String>> chunksAsked;
  late List<GeoPoint?> locationsAsked;

  MediaItem item(
    String id,
    String diveId, {
    MediaType type = MediaType.photo,
    String? path,
    String? asset,
  }) => MediaItem(
    id: id,
    diveId: diveId,
    mediaType: type,
    localPath: path,
    platformAssetId: asset,
    takenAt: DateTime.utc(2026),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  SpeciesBatchPlanner planner({int chunkSize = 250}) => SpeciesBatchPlanner(
    mediaForDives: (ids) async {
      chunksAsked.add(ids);
      return {for (final id in ids) id: media[id] ?? const []};
    },
    placesOf: (ids) async => {
      for (final id in ids)
        id: (exists: true, site: const GeoPoint(20, -87), entry: null),
    },
    upToDate: (items, locationOf) async {
      locationsAsked.addAll(items.map(locationOf));
      return {
        for (final m in items)
          if (upToDate.contains(m.id)) m.id,
      };
    },
    withOpenSuggestions: (ids) async => {
      for (final id in ids)
        if (openSuggestions.contains(id)) id,
    },
    canApply: () => canApply,
    libraryOriginalHere: (m) async => libraryHere.contains(m.id),
    fileExists: (path) => path == '/here.jpg',
    chunkSize: chunkSize,
  );

  setUp(() {
    media = {
      'd1': [
        item('a1', 'd1', path: '/here.jpg'),
        item('a2', 'd1', type: MediaType.video, path: '/gone.mp4'),
        item('a3', 'd1', type: MediaType.instructorSignature),
      ],
      'd2': [item('b1', 'd2', path: '/here.jpg')],
      'd3': [item('c1', 'd3', asset: 'PH-1'), item('c2', 'd3', asset: 'PH-2')],
      'd4': const [],
    };
    upToDate = {};
    openSuggestions = {};
    canApply = false;
    libraryHere = {'c1'};
    chunksAsked = [];
    locationsAsked = [];
  });

  test('counts photos and videos of every dive, in order', () async {
    final plan = await planner().plan(['d1', 'd2', 'd3', 'd4']).last;

    expect(plan.dives.map((d) => d.diveId), ['d1', 'd2', 'd3']);
    // A signature is neither: it is not looked at.
    expect(plan.dives.first.items, 2);
    expect(plan.toLookAt, 5);
    expect(plan.items, 5);
    expect(plan.divesAsked, 4);
    // a2's file is gone, c2's original is only in the cloud.
    expect(plan.notOnDevice, 2);
  });

  test('a dive with everything up to date is left out', () async {
    upToDate = {'b1'};

    final plan = await planner().plan(['d1', 'd2']).last;

    expect(plan.dives.map((d) => d.diveId), ['d1']);
  });

  test('up to date media are not counted as to download', () async {
    upToDate = {'a2'};

    final plan = await planner().plan(['d1']).last;

    expect(plan.dives.single.items, 2);
    expect(plan.dives.single.toLookAt, 1);
    expect(plan.notOnDevice, 0);
  });

  test('an up to date dive with open suggestions stays when the run can '
      'tag them', () async {
    upToDate = {'b1'};
    openSuggestions = {'b1'};
    canApply = true;

    final plan = await planner().plan(['d2']).last;

    expect(plan.dives.single.diveId, 'd2');
    expect(plan.dives.single.toLookAt, 0);
    expect(plan.toLookAt, 0);
    expect(plan.isEmpty, isFalse);
  });

  test('but not when auto-apply cannot tag', () async {
    upToDate = {'b1'};
    openSuggestions = {'b1'};

    final plan = await planner().plan(['d2']).last;

    expect(plan.isEmpty, isTrue);
  });

  test('asks in chunks and reports after each', () async {
    final plans = await planner(
      chunkSize: 2,
    ).plan(['d1', 'd2', 'd3', 'd4']).toList();

    expect(chunksAsked, [
      ['d1', 'd2'],
      ['d3', 'd4'],
    ]);
    expect(plans.map((p) => p.divesAsked), [2, 4]);
    expect(plans.last.dives, hasLength(3));
  });

  test('names media by their dive site', () async {
    await planner().plan(['d2']).last;

    expect(locationsAsked, [const GeoPoint(20, -87)]);
  });

  test('no dives make an empty plan', () async {
    final plan = await planner().plan(const []).last;

    expect(plan, const SpeciesBatchPlan());
  });
}
