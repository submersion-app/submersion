import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/data/services/linked_gallery_assets.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// A gallery asset as this device's photo library reports it: LOCAL capture
/// time, this device's own local identifier.
AssetInfo _asset(String id, {int second = 5, int width = 4032}) => AssetInfo(
  id: id,
  type: AssetType.image,
  createDateTime: DateTime(2026, 7, 18, 10, 0, second),
  width: width,
  height: 3024,
);

/// A linked row as it arrives through sync: the other device's asset id and
/// a capture time stored as wall-clock UTC (the digits of the local time).
MediaItem _row(
  String id, {
  String? platformAssetId,
  int second = 5,
  int width = 4032,
}) => MediaItem(
  id: id,
  diveId: 'dive-1',
  platformAssetId: platformAssetId ?? 'iphone-$id',
  mediaType: MediaType.photo,
  takenAt: DateTime.utc(2026, 7, 18, 10, 0, second),
  width: width,
  height: 3024,
  createdAt: DateTime.utc(2026, 7, 18),
  updatedAt: DateTime.utc(2026, 7, 18),
);

/// Resolver double standing in for [AssetResolutionService.resolveAssetId],
/// whose real implementation needs PhotoKit. Unlisted rows are unavailable.
class _FakeResolver {
  _FakeResolver([this.answers = const {}]);

  final Map<String, ResolutionResult> answers;
  final Set<String> throwingFor = {};
  final List<String> calls = [];

  Future<ResolutionResult> call(MediaItem item) async {
    calls.add(item.id);
    if (throwingFor.contains(item.id)) {
      throw StateError('photo library unavailable');
    }
    return answers[item.id] ??
        const ResolutionResult(status: ResolutionStatus.unavailable);
  }
}

ResolutionResult _resolvedTo(String localId) =>
    ResolutionResult(localAssetId: localId, status: ResolutionStatus.resolved);

List<String> _ids(List<AssetInfo> assets) => assets.map((a) => a.id).toList();

void main() {
  group('LinkedGalleryAssets.withoutLinked', () {
    test('drops a candidate whose id is a linked row synced id', () async {
      final dedupe = LinkedGalleryAssets(resolve: _FakeResolver().call);

      final result = await dedupe.withoutLinked(
        candidates: [_asset('a'), _asset('b', second: 30)],
        linked: [_row('m1', platformAssetId: 'a')],
      );

      expect(_ids(result), ['b']);
    });

    test(
      'drops a candidate that a linked row resolves to on this device',
      () async {
        final dedupe = LinkedGalleryAssets(
          resolve: _FakeResolver({'m1': _resolvedTo('mac-1')}).call,
        );

        final result = await dedupe.withoutLinked(
          candidates: [_asset('mac-1'), _asset('mac-2', second: 30)],
          linked: [_row('m1')],
        );

        expect(_ids(result), ['mac-2']);
      },
    );

    test(
      'does not resolve a row whose synced id is already a candidate',
      () async {
        final resolver = _FakeResolver();
        final dedupe = LinkedGalleryAssets(resolve: resolver.call);

        await dedupe.withoutLinked(
          candidates: [_asset('a'), _asset('b', second: 30)],
          linked: [
            _row('m1', platformAssetId: 'a'),
            _row('m2', second: 50),
          ],
        );

        expect(resolver.calls, ['m2']);
      },
    );

    test(
      'skips resolution entirely once every candidate is accounted for',
      () async {
        final resolver = _FakeResolver();
        final dedupe = LinkedGalleryAssets(resolve: resolver.call);

        final result = await dedupe.withoutLinked(
          candidates: [_asset('a')],
          linked: [
            _row('m1', platformAssetId: 'a'),
            _row('m2', second: 50),
          ],
        );

        expect(result, isEmpty);
        expect(resolver.calls, isEmpty);
      },
    );

    test('treats a burst the resolver cannot split as already linked when '
        'at least as many unresolved rows share its second and size', () async {
      // Two frames in the same second with the same dimensions: the
      // resolver refuses to guess which row is which, but both are linked.
      final dedupe = LinkedGalleryAssets(resolve: _FakeResolver().call);

      final result = await dedupe.withoutLinked(
        candidates: [
          _asset('mac-1'),
          _asset('mac-2'),
          _asset('mac-3', second: 30),
        ],
        linked: [_row('m1'), _row('m2')],
      );

      expect(_ids(result), ['mac-3']);
    });

    test('offers every frame of a burst that has more frames than unresolved '
        'rows, since it cannot tell which ones are new', () async {
      final dedupe = LinkedGalleryAssets(resolve: _FakeResolver().call);

      final result = await dedupe.withoutLinked(
        candidates: [_asset('mac-1'), _asset('mac-2')],
        linked: [_row('m1')],
      );

      expect(_ids(result), ['mac-1', 'mac-2']);
    });

    test('does not count a row towards two frames one UTC offset apart, '
        'so neither is hidden on its account', () async {
      // A stored time has two readings (wall-clock digits restated as local,
      // and the raw instant for rows written before that convention). With a
      // candidate at each, the row cannot be attributed to either.
      // On a host running at UTC the readings coincide and this degenerates
      // to a two-frame burst with one row, which is offered either way.
      final row = _row('m1');
      final atRestated = _asset('mac-1');
      final atRawInstant = AssetInfo(
        id: 'mac-2',
        type: AssetType.image,
        createDateTime: row.takenAt.toLocal(),
        width: 4032,
        height: 3024,
      );
      final dedupe = LinkedGalleryAssets(resolve: _FakeResolver().call);

      final result = await dedupe.withoutLinked(
        candidates: [atRestated, atRawInstant],
        linked: [row],
      );

      expect(_ids(result), ['mac-1', 'mac-2']);
    });

    test('ignores a different size in the same second', () async {
      final dedupe = LinkedGalleryAssets(resolve: _FakeResolver().call);

      final result = await dedupe.withoutLinked(
        candidates: [_asset('mac-1', width: 1920)],
        linked: [_row('m1')],
      );

      expect(_ids(result), ['mac-1']);
    });

    test('counts a row resolved to an asset this scan did not return, since '
        'that cached id cannot be verified here', () async {
      // The resolver trusts its cache without re-proving it, so a stale entry
      // (the library reassigned the photo's local id) resolves to an id that
      // is gone. The photo's real asset is a candidate at the row's exact
      // second and size; if the cached id were live it would be a candidate
      // too.
      final dedupe = LinkedGalleryAssets(
        resolve: _FakeResolver({'m1': _resolvedTo('stale')}).call,
      );

      final result = await dedupe.withoutLinked(
        candidates: [_asset('mac-1')],
        linked: [_row('m1')],
      );

      expect(result, isEmpty);
    });

    test(
      'does not count a row the gallery could not be consulted for',
      () async {
        final dedupe = LinkedGalleryAssets(
          resolve: _FakeResolver({
            'm1': const ResolutionResult(status: ResolutionStatus.accessDenied),
          }).call,
        );

        final result = await dedupe.withoutLinked(
          candidates: [_asset('mac-1')],
          linked: [_row('m1')],
        );

        expect(_ids(result), ['mac-1']);
      },
    );

    test('with no resolver, only synced ids count', () async {
      const dedupe = LinkedGalleryAssets();

      final result = await dedupe.withoutLinked(
        candidates: [_asset('a'), _asset('mac-1')],
        linked: [
          _row('m1', platformAssetId: 'a'),
          _row('m2'),
        ],
      );

      // m2 shares mac-1's second and size, but nothing resolved it.
      expect(_ids(result), ['mac-1']);
    });

    test('ignores rows with no gallery asset id', () async {
      final dedupe = LinkedGalleryAssets(resolve: _FakeResolver().call);
      final localFile = MediaItem(
        id: 'm1',
        diveId: 'dive-1',
        mediaType: MediaType.photo,
        takenAt: DateTime.utc(2026, 7, 18, 10, 0, 5),
        width: 4032,
        height: 3024,
        createdAt: DateTime.utc(2026, 7, 18),
        updatedAt: DateTime.utc(2026, 7, 18),
      );

      final result = await dedupe.withoutLinked(
        candidates: [_asset('mac-1')],
        linked: [localFile],
      );

      expect(_ids(result), ['mac-1']);
    });

    test('a row whose resolution throws claims nothing and does not abort '
        'the others', () async {
      final resolver = _FakeResolver({'m2': _resolvedTo('mac-2')})
        ..throwingFor.add('m1');
      final dedupe = LinkedGalleryAssets(resolve: resolver.call);

      final result = await dedupe.withoutLinked(
        candidates: [_asset('mac-1'), _asset('mac-2', second: 30)],
        linked: [_row('m1'), _row('m2', second: 30)],
      );

      // Nothing was learned about m1, so its same-second frame stays offered.
      expect(_ids(result), ['mac-1']);
    });
  });

  group('LinkedGalleryAssets.idsOnThisDevice', () {
    test('returns each synced id plus the id it resolves to here', () async {
      final dedupe = LinkedGalleryAssets(
        resolve: _FakeResolver({'m1': _resolvedTo('mac-1')}).call,
      );

      final ids = await dedupe.idsOnThisDevice([
        _row('m1'),
        _row('m2'),
        _row('m3', platformAssetId: 'same'),
      ]);

      expect(ids, {'iphone-m1', 'mac-1', 'iphone-m2', 'same'});
    });

    test('keeps the synced id when resolution throws', () async {
      final resolver = _FakeResolver()..throwingFor.add('m1');
      final dedupe = LinkedGalleryAssets(resolve: resolver.call);

      final ids = await dedupe.idsOnThisDevice([_row('m1')]);

      expect(ids, {'iphone-m1'});
    });

    test('returns only synced ids when no resolver is supplied', () async {
      const dedupe = LinkedGalleryAssets();

      final ids = await dedupe.idsOnThisDevice([_row('m1')]);

      expect(ids, {'iphone-m1'});
    });
  });
}
