import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_repair_matcher.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';

MediaItem broken(
  String id, {
  String? localPath,
  String? contentHash,
  String? originalFilename,
}) => MediaItem(
  id: id,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.localFile,
  filePath: localPath ?? '/old/$id.jpg',
  localPath: localPath ?? '/old/$id.jpg',
  originalFilename: originalFilename ?? '$id.jpg',
  contentHash: contentHash,
  isOrphaned: true,
  takenAt: DateTime(2026, 6, 1),
  createdAt: DateTime(2026, 6, 1),
  updatedAt: DateTime(2026, 6, 1),
);

void main() {
  group('detectPrefixMove', () {
    test('detects a whole-tree move covering multiple files', () {
      final move = detectPrefixMove(
        brokenPaths: [
          '/old/Dives/2026/a.jpg',
          '/old/Dives/2026/b.jpg',
          '/old/Dives/misc/c.mp4',
        ],
        foundPaths: {
          '/nas/Dives/2026/a.jpg',
          '/nas/Dives/2026/b.jpg',
          '/nas/Dives/misc/c.mp4',
        },
      );
      expect(move, isNotNull);
      expect(move!.fromPrefix, '/old/Dives');
      expect(move.toPrefix, '/nas/Dives');
      expect(move.coveredCount, 3);
    });

    test('a single coincidental filename is not a move', () {
      expect(
        detectPrefixMove(
          brokenPaths: ['/old/a.jpg'],
          foundPaths: {'/nas/a.jpg'},
        ),
        isNull,
      );
    });

    test('no shared suffixes yields null', () {
      expect(
        detectPrefixMove(
          brokenPaths: ['/old/a.jpg', '/old/b.jpg'],
          foundPaths: {'/nas/x.jpg', '/nas/y.jpg'},
        ),
        isNull,
      );
    });
  });

  group('buildRepairProposals', () {
    test('hash equality is exact', () {
      final proposals = buildRepairProposals(
        brokenRows: [broken('a', contentHash: 'H1')],
        candidatesByFilename: {
          'a.jpg': [
            const RepairCandidate.file(
              path: '/nas/a.jpg',
              sizeBytes: 10,
              hash: 'H1',
            ),
          ],
        },
      );
      expect(proposals.single.confidence, RepairConfidence.exact);
      expect(proposals.single.candidate!.path, '/nas/a.jpg');
    });

    test('name and size without a computed hash is probable', () {
      final proposals = buildRepairProposals(
        brokenRows: [broken('a', contentHash: 'H1')],
        candidatesByFilename: {
          'a.jpg': [
            const RepairCandidate.file(path: '/nas/a.jpg', sizeBytes: 10),
          ],
        },
      );
      expect(proposals.single.confidence, RepairConfidence.probable);
    });

    test('name match with a differing hash is edited', () {
      final proposals = buildRepairProposals(
        brokenRows: [broken('a', contentHash: 'H1')],
        candidatesByFilename: {
          'a.jpg': [
            const RepairCandidate.file(
              path: '/nas/a.jpg',
              sizeBytes: 10,
              hash: 'OTHER',
            ),
          ],
        },
      );
      expect(proposals.single.confidence, RepairConfidence.edited);
    });

    test('no candidate is unmatched', () {
      final proposals = buildRepairProposals(
        brokenRows: [broken('a')],
        candidatesByFilename: const {},
      );
      expect(proposals.single.confidence, RepairConfidence.unmatched);
      expect(proposals.single.candidate, isNull);
    });

    test('prefix-move hits rank first and are marked viaPrefixMove', () {
      const move = PrefixMove(
        fromPrefix: '/old',
        toPrefix: '/nas',
        coveredCount: 2,
      );
      final proposals = buildRepairProposals(
        brokenRows: [broken('a', localPath: '/old/a.jpg')],
        candidatesByFilename: {
          'a.jpg': [
            const RepairCandidate.file(path: '/elsewhere/a.jpg', sizeBytes: 10),
          ],
        },
        prefixMove: move,
        foundPaths: {'/nas/a.jpg', '/elsewhere/a.jpg'},
      );
      final p = proposals.single;
      expect(p.viaPrefixMove, isTrue);
      expect(p.candidate!.path, '/nas/a.jpg');
      expect(p.confidence, RepairConfidence.probable);
    });

    test('store candidates propose cloud-backed regardless of filename', () {
      final proposals = buildRepairProposals(
        brokenRows: [broken('a', contentHash: 'H1')],
        candidatesByFilename: {
          'a.jpg': [const RepairCandidate.store(verified: true)],
        },
      );
      expect(proposals.single.confidence, RepairConfidence.exact);
      expect(proposals.single.candidate!.isStore, isTrue);
    });
  });
}
