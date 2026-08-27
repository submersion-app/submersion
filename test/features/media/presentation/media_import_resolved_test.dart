import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/import_candidate.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/pages/media_import_view.dart';

AssetInfo asset(String id) => AssetInfo(
  id: id,
  type: AssetType.image,
  createDateTime: DateTime(2026, 6, 12, 10),
  width: 100,
  height: 100,
  filename: '$id.jpg',
);

MediaItem imported(String assetId) => MediaItem(
  id: 'row-$assetId',
  mediaType: MediaType.photo,
  takenAt: DateTime(2026, 6, 12, 10),
  createdAt: DateTime(2026, 6, 12),
  updatedAt: DateTime(2026, 6, 12),
);

/// Records every call and can be told to throw for one dive or site.
class _FakeImportService implements MediaImportService {
  final List<(String diveId, List<String> assetIds)> diveCalls = [];
  final List<(String siteId, List<String> assetIds)> siteCalls = [];
  String? throwForDive;
  String? throwForSite;
  Map<String, String> perAssetFailures = const {};

  @override
  Future<ImportResult> importPhotosForDive({
    required List<AssetInfo> selectedAssets,
    required Dive dive,
  }) async {
    diveCalls.add((dive.id, [for (final a in selectedAssets) a.id]));
    if (dive.id == throwForDive) throw StateError('dive import blew up');
    return ImportResult(
      imported: [
        for (final a in selectedAssets)
          if (!perAssetFailures.containsKey(a.id)) imported(a.id),
      ],
      failures: {
        for (final a in selectedAssets)
          if (perAssetFailures.containsKey(a.id)) a.id: perAssetFailures[a.id]!,
      },
      skippedDuplicates: 0,
    );
  }

  @override
  Future<ImportResult> importPhotosForSite({
    required List<AssetInfo> selectedAssets,
    required String siteId,
  }) async {
    siteCalls.add((siteId, [for (final a in selectedAssets) a.id]));
    if (siteId == throwForSite) throw StateError('site import blew up');
    return ImportResult(
      imported: [for (final a in selectedAssets) imported(a.id)],
      failures: const {},
      skippedDuplicates: 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDiveRepo implements DiveRepository {
  _FakeDiveRepo(this.known);
  final Set<String> known;

  @override
  Future<Dive?> getDiveById(String id) async =>
      known.contains(id) ? Dive(id: id, dateTime: DateTime(2026, 6, 12)) : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeImportService service;

  setUp(() => service = _FakeImportService());

  Future<ImportReviewResult> run(
    List<AssetInfo> assets,
    Map<String, MediaAttachTarget> targets, {
    Set<String> dives = const {'d1', 'd2'},
  }) {
    return MediaImportView.importResolved(
      service: service,
      diveRepository: _FakeDiveRepo(dives),
      assets: assets,
      targets: targets,
    );
  }

  test('groups assets by dive and by site, one service call each', () async {
    final out = await run(
      [asset('a'), asset('b'), asset('c'), asset('d')],
      {
        'a': const DiveAttachTarget('d1'),
        'b': const DiveAttachTarget('d1'),
        'c': const SiteAttachTarget('s1'),
        // 'd' left unresolved: skipped, never imported.
      },
    );

    // Records compare their fields with ==, and List == is identity, so
    // the call tuples are asserted field by field.
    expect(service.diveCalls.single.$1, 'd1');
    expect(service.diveCalls.single.$2, ['a', 'b']);
    expect(service.siteCalls.single.$1, 's1');
    expect(service.siteCalls.single.$2, ['c']);
    expect(out.linked, 3);
    expect(out.skipped, 1);
    expect(out.failures, isEmpty);
  });

  test(
    'a dive that no longer exists fails its assets and nothing else',
    () async {
      final out = await run(
        [asset('a'), asset('b')],
        {
          'a': const DiveAttachTarget('gone'),
          'b': const DiveAttachTarget('d1'),
        },
      );

      expect(out.failures.keys, ['a']);
      expect(out.failures['a'], contains('gone'));
      expect(service.diveCalls.single.$1, 'd1');
      expect(service.diveCalls.single.$2, ['b']);
      expect(out.linked, 1);
    },
  );

  test('a throwing group is recorded and the loop keeps going', () async {
    service.throwForDive = 'd1';
    service.throwForSite = 's1';

    final out = await run(
      [asset('a'), asset('b'), asset('c'), asset('d')],
      {
        'a': const DiveAttachTarget('d1'),
        'b': const DiveAttachTarget('d2'),
        'c': const SiteAttachTarget('s1'),
        'd': const SiteAttachTarget('s2'),
      },
    );

    // Every group was attempted despite the first dive and first site
    // throwing.
    expect(service.diveCalls.map((c) => c.$1), ['d1', 'd2']);
    expect(service.siteCalls.map((c) => c.$1), ['s1', 's2']);
    expect(out.failures.keys.toSet(), {'a', 'c'});
    expect(out.failures['a'], contains('dive import blew up'));
    expect(out.failures['c'], contains('site import blew up'));
    expect(out.linked, 2);
  });

  test('per-asset failures reported by the service ride the result', () async {
    service.perAssetFailures = {'b': 'unreadable'};

    final out = await run(
      [asset('a'), asset('b')],
      {'a': const DiveAttachTarget('d1'), 'b': const DiveAttachTarget('d1')},
    );

    expect(out.linked, 1);
    expect(out.failures, {'b': 'unreadable'});
  });

  test('a target whose asset is not in the batch is ignored', () async {
    final out = await run(
      [asset('a')],
      {'a': const DiveAttachTarget('d1'), 'zzz': const DiveAttachTarget('d1')},
    );

    expect(service.diveCalls.single.$1, 'd1');
    expect(service.diveCalls.single.$2, ['a']);
    expect(out.linked, 1);
  });
}
