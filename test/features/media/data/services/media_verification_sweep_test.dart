import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_item_verifier.dart';
import 'package:submersion/features/media/data/services/media_verification_sweep.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

class _StubRepository implements MediaRepository {
  _StubRepository(this.items);

  final List<MediaItem> items;
  final List<Set<MediaSourceType>?> asked = [];

  @override
  Future<List<MediaItem>> getAllBySourceTypes(
    Set<MediaSourceType>? sourceTypes,
  ) async {
    asked.add(sourceTypes);
    if (sourceTypes == null) return items;
    return items.where((i) => sourceTypes.contains(i.sourceType)).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not stubbed');
}

/// Answers per media id, and throws for any id in [throwFor].
class _StubVerifier implements MediaItemVerifier {
  _StubVerifier(this.results, {this.throwFor = const {}});

  final Map<String, VerifyResult> results;
  final Set<String> throwFor;
  final List<String> verified = [];

  @override
  Future<VerifyResult> verify(MediaItem item) async {
    verified.add(item.id);
    if (throwFor.contains(item.id)) throw StateError('bad row');
    return results[item.id] ?? VerifyResult.available;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not stubbed');
}

MediaItem _item(
  String id, {
  MediaSourceType sourceType = MediaSourceType.platformGallery,
  bool isOrphaned = false,
}) => MediaItem(
  id: id,
  mediaType: MediaType.photo,
  sourceType: sourceType,
  isOrphaned: isOrphaned,
  takenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  test('sweeps every source type when unfiltered', () async {
    // The whole point of this class. The sweep it replaces asked for
    // localFile only, so a gallery library was never verified at all.
    final repository = _StubRepository([
      _item('gallery'),
      _item('url', sourceType: MediaSourceType.networkUrl),
      _item('local', sourceType: MediaSourceType.localFile),
    ]);
    final verifier = _StubVerifier(const {});
    final sweep = MediaVerificationSweep(
      repository: repository,
      verifier: verifier,
    );

    final outcome = await sweep.run();

    expect(outcome.processed, 3);
    expect(verifier.verified, ['gallery', 'url', 'local']);
    expect(repository.asked.single, isNull);
  });

  test('a filtered sweep asks only for those source types', () async {
    final repository = _StubRepository([
      _item('gallery'),
      _item('local', sourceType: MediaSourceType.localFile),
    ]);
    final sweep = MediaVerificationSweep(
      repository: repository,
      verifier: _StubVerifier(const {}),
    );

    final outcome = await sweep.run(sourceTypes: {MediaSourceType.localFile});

    expect(outcome.processed, 1);
    expect(repository.asked.single, {MediaSourceType.localFile});
  });

  test('counts a row whose orphan flag changed as flipped', () async {
    final repository = _StubRepository([_item('a', isOrphaned: false)]);
    final sweep = MediaVerificationSweep(
      repository: repository,
      verifier: _StubVerifier(const {'a': VerifyResult.notFound}),
    );

    final outcome = await sweep.run();

    expect(outcome.flipped, 1);
    expect(outcome.inconclusive, 0);
  });

  test('a row that was already orphaned and still is does not count', () async {
    final repository = _StubRepository([_item('a', isOrphaned: true)]);
    final sweep = MediaVerificationSweep(
      repository: repository,
      verifier: _StubVerifier(const {'a': VerifyResult.notFound}),
    );

    expect((await sweep.run()).flipped, 0);
  });

  group('inconclusive results are reported, not counted as clean', () {
    // A pass that could not read the photo library checked nothing. Reporting
    // "0 items updated" would read as a clean bill of health for a library
    // nobody looked at.
    // Must stay in step with MediaItemVerifier: anything it declines to act
    // on is a row this pass did not verify, and counting it as flipped would
    // report work that never happened.
    for (final result in const [
      VerifyResult.accessDenied,
      VerifyResult.volumeOffline,
      VerifyResult.transientError,
      VerifyResult.unauthenticated,
      VerifyResult.fromOtherDevice,
    ]) {
      test('$result counts as inconclusive and never as flipped', () async {
        final repository = _StubRepository([_item('a', isOrphaned: false)]);
        final sweep = MediaVerificationSweep(
          repository: repository,
          verifier: _StubVerifier({'a': result}),
        );

        final outcome = await sweep.run();

        expect(outcome.inconclusive, 1);
        expect(outcome.flipped, 0);
      });
    }
  });

  test('one throwing row does not abort the sweep', () async {
    final repository = _StubRepository([_item('bad'), _item('good')]);
    final verifier = _StubVerifier(const {}, throwFor: {'bad'});
    final sweep = MediaVerificationSweep(
      repository: repository,
      verifier: verifier,
    );

    final outcome = await sweep.run();

    expect(outcome.failed, 1);
    expect(outcome.processed, 2);
    expect(verifier.verified, ['bad', 'good']);
  });

  test('reports progress per row', () async {
    final repository = _StubRepository([_item('a'), _item('b')]);
    final sweep = MediaVerificationSweep(
      repository: repository,
      verifier: _StubVerifier(const {}),
    );

    final seen = <(int, int)>[];
    await sweep.run(onProgress: (done, total) => seen.add((done, total)));

    expect(seen, [(1, 2), (2, 2)]);
  });

  test('an empty library is a valid, clean pass', () async {
    final sweep = MediaVerificationSweep(
      repository: _StubRepository([]),
      verifier: _StubVerifier(const {}),
    );

    final outcome = await sweep.run();

    expect(outcome.processed, 0);
    expect(outcome.flipped, 0);
    expect(outcome.inconclusive, 0);
    expect(outcome.failed, 0);
  });
}
