import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/repair/media_repair_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';
import 'package:submersion/features/media/presentation/providers/media_repair_providers.dart';

MediaItem broken(String id, {String? localPath}) => MediaItem(
  id: id,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.localFile,
  filePath: localPath ?? '/gone/$id.jpg',
  localPath: localPath ?? '/gone/$id.jpg',
  originalFilename: '$id.jpg',
  isOrphaned: true,
  takenAt: DateTime(2026, 6, 1),
  createdAt: DateTime(2026, 6, 1),
  updatedAt: DateTime(2026, 6, 1),
);

class _FakeSource implements CandidateSource {
  _FakeSource(this.harvestResult);
  final CandidateHarvest harvestResult;

  @override
  Future<CandidateHarvest> harvest(List<MediaItem> brokenRows) async =>
      harvestResult;
}

void main() {
  late List<RepairProposal>? appliedProposals;

  RepairWizardNotifier notifier({
    required List<MediaItem> missingRows,
    required CandidateHarvest harvest,
    Set<String> offlinePaths = const {},
    RepairApplyReport? report,
  }) {
    appliedProposals = null;
    return RepairWizardNotifier(
      loadMissingRows: () async => missingRows,
      buildSources: (config) => [_FakeSource(harvest)],
      newVolumeProbe: () =>
          (path) async => !offlinePaths.contains(path),
      applyProposals: (proposals) async {
        appliedProposals = proposals;
        return report ??
            const RepairApplyReport(
              relinked: 0,
              cloudBacked: 0,
              reuploadsQueued: 0,
              failed: 0,
              skipped: 0,
            );
      },
    );
  }

  test('harvest produces review with exact and probable pre-checked', () async {
    final n = notifier(
      missingRows: [broken('a'), broken('b'), broken('c')],
      harvest: const CandidateHarvest(
        byFilename: {
          'a.jpg': [
            RepairCandidate.file(path: '/nas/a.jpg', sizeBytes: 4, hash: null),
          ],
          'b.jpg': [RepairCandidate.store(verified: true)],
        },
      ),
    );

    await n.harvest(const RepairWizardConfig());

    final state = n.state as RepairWizardReview;
    expect(state.proposals, hasLength(3));
    expect(n.isChecked('a'), isTrue); // probable
    expect(n.isChecked('b'), isTrue); // exact (store)
    expect(n.isChecked('c'), isFalse); // unmatched
  });

  test('volume-offline rows are excluded from the wizard', () async {
    final n = notifier(
      missingRows: [
        broken('a'),
        broken('off', localPath: '/nas/off.jpg'),
      ],
      harvest: const CandidateHarvest(byFilename: {}),
      offlinePaths: {'/nas/off.jpg'},
    );

    await n.harvest(const RepairWizardConfig());

    final state = n.state as RepairWizardReview;
    expect(state.proposals.map((p) => p.item.id), ['a']);
  });

  test('each harvest builds exactly one volume probe', () async {
    // The probe memoizes per mount root, so one per pass keeps an
    // unreachable share to a single stat however many rows sit on it -
    // while a rescan still re-reads mount state.
    var probesBuilt = 0;
    final n = RepairWizardNotifier(
      loadMissingRows: () async => [
        broken('a', localPath: '/nas/a.jpg'),
        broken('b', localPath: '/nas/b.jpg'),
        broken('c', localPath: '/nas/c.jpg'),
      ],
      buildSources: (_) => const [],
      newVolumeProbe: () {
        probesBuilt++;
        return (_) async => true;
      },
      applyProposals: (_) async => const RepairApplyReport(
        relinked: 0,
        cloudBacked: 0,
        reuploadsQueued: 0,
        failed: 0,
        skipped: 0,
      ),
    );

    await n.harvest(const RepairWizardConfig());
    expect(probesBuilt, 1);

    await n.harvest(const RepairWizardConfig());
    expect(probesBuilt, 2);
  });

  test(
    'applyChecked forwards only checked proposals and reaches done',
    () async {
      final n = notifier(
        missingRows: [broken('a'), broken('c')],
        harvest: const CandidateHarvest(
          byFilename: {
            'a.jpg': [RepairCandidate.file(path: '/nas/a.jpg', sizeBytes: 4)],
          },
        ),
        report: const RepairApplyReport(
          relinked: 1,
          cloudBacked: 0,
          reuploadsQueued: 0,
          failed: 0,
          skipped: 0,
        ),
      );

      await n.harvest(const RepairWizardConfig());
      await n.applyChecked();

      expect(appliedProposals!.map((p) => p.item.id), ['a']);
      final done = n.state as RepairWizardDone;
      expect(done.report.relinked, 1);
    },
  );

  test('toggleProposal flips membership', () async {
    final n = notifier(
      missingRows: [broken('a')],
      harvest: const CandidateHarvest(
        byFilename: {
          'a.jpg': [RepairCandidate.file(path: '/nas/a.jpg', sizeBytes: 4)],
        },
      ),
    );
    await n.harvest(const RepairWizardConfig());
    expect(n.isChecked('a'), isTrue);
    n.toggleProposal('a');
    expect(n.isChecked('a'), isFalse);
  });
}
