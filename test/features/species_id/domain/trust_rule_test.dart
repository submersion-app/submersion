import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/pack_versions.dart';
import 'package:submersion/features/species_id/domain/services/video_identification_rules.dart';

import '../data/identification_fixtures.dart';

/// A device trusts results made on another one (issue #4876): it analyses
/// them again only when its own models are newer (Review Focus 1).
void main() {
  group('comparePackVersions', () {
    test('orders by each number in turn', () {
      expect(comparePackVersions('2026.11.18.0356', '2026.11.18.0356'), 0);
      expect(comparePackVersions('2026.11.18.0400', '2026.11.18.0356'), 1);
      expect(comparePackVersions('2026.12.1', '2026.11.18.0356'), 1);
      expect(comparePackVersions('2026.11.2', '2026.11.10'), -1);
      expect(comparePackVersions('2026.11', '2026.11.1'), -1);
    });

    test('falls back to the text for a part that is not a number', () {
      expect(comparePackVersions('2026.11.b', '2026.11.a'), 1);
    });
  });

  // The fixture run: pack 2026.11.1, detector det, classifier clf, cell
  // 1462, made elsewhere.
  final elsewhere = run();

  RefreshAction photo({
    String pack = '2026.11.1',
    String detector = 'det',
    String classifier = 'clf',
    int? cell = 1462,
  }) => decideRefresh(
    run: elsewhere,
    packVersion: pack,
    detectorId: detector,
    classifierId: classifier,
    cell: cell,
    cropsPresent: false,
    embeddingsPresent: false,
    madeHere: false,
  );

  VideoRefreshAction video({
    String pack = '2026.11.1',
    String detector = 'det',
    bool complete = false,
  }) => decideVideoRefresh(
    run: complete
        ? elsewhere.copyWith(videoDurationMs: () => 1000, scannedMs: () => 1000)
        : elsewhere.copyWith(
            videoDurationMs: () => 9000,
            scannedMs: () => 1000,
          ),
    packVersion: pack,
    detectorId: detector,
    classifierId: 'clf',
    cell: 1462,
    cropsPresent: false,
    embeddingsPresent: false,
    madeHere: false,
  );

  group('a photo made elsewhere', () {
    test('is left alone with its crops and embeddings missing', () {
      expect(photo(), RefreshAction.none);
    });

    test('is left alone by an older pack', () {
      expect(photo(pack: '2026.10.1', detector: 'old'), RefreshAction.none);
    });

    test('is left alone by a later pack with the same models', () {
      expect(photo(pack: '2026.12.1'), RefreshAction.none);
    });

    test('is analysed by a later pack with a new detector or classifier', () {
      expect(photo(pack: '2026.12.1', detector: 'det2'), RefreshAction.analyse);
      expect(
        photo(pack: '2026.12.1', classifier: 'clf2'),
        RefreshAction.analyse,
      );
    });

    test('is left alone in another region cell', () {
      expect(photo(cell: 9), RefreshAction.none);
    });
  });

  group('a video made elsewhere', () {
    test('is never resumed, finished or not', () {
      expect(video(), VideoRefreshAction.none);
      expect(video(complete: true), VideoRefreshAction.none);
    });

    test('is scanned again only by newer models', () {
      expect(video(pack: '2026.12.1'), VideoRefreshAction.none);
      expect(
        video(pack: '2026.12.1', detector: 'det#tracker9'),
        VideoRefreshAction.rescan,
      );
    });
  });

  test('a run made here is decided exactly as before', () {
    expect(
      decideRefresh(
        run: elsewhere,
        packVersion: '2026.11.1',
        detectorId: 'det',
        classifierId: 'clf',
        cell: 1462,
        cropsPresent: false,
        embeddingsPresent: false,
      ),
      RefreshAction.analyse,
    );
  });
}
