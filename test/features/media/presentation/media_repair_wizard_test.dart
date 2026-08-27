import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/repair/media_repair_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';
import 'package:submersion/features/media/presentation/pages/media_repair_wizard_page.dart';
import 'package:submersion/features/media/presentation/providers/media_repair_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

MediaItem broken(String id) => MediaItem(
  id: id,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.localFile,
  originalFilename: '$id.jpg',
  isOrphaned: true,
  takenAt: DateTime(2026, 6, 1),
  createdAt: DateTime(2026, 6, 1),
  updatedAt: DateTime(2026, 6, 1),
);

class _SeededWizardNotifier extends RepairWizardNotifier {
  _SeededWizardNotifier(
    RepairWizardState seeded, {
    Set<String> checked = const {},
  }) : super(
         loadMissingRows: () async => const [],
         buildSources: (_) => const [],
         newVolumeProbe: () =>
             (_) async => true,
         applyProposals: (_) async => const RepairApplyReport(
           relinked: 0,
           cloudBacked: 0,
           reuploadsQueued: 0,
           failed: 0,
           skipped: 0,
         ),
       ) {
    for (final id in checked) {
      toggleProposal(id);
    }
    state = seeded;
  }

  int applyCalls = 0;

  @override
  Future<void> applyChecked() async {
    applyCalls++;
  }
}

void main() {
  Widget host(_SeededWizardNotifier notifier) {
    return ProviderScope(
      overrides: [repairWizardProvider.overrideWith((ref) => notifier)],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaRepairWizardPage(),
      ),
    );
  }

  testWidgets('idle state renders the scope pane with source toggles', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(_SeededWizardNotifier(const RepairWizardIdle())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add folder...'), findsOneWidget);
    expect(find.text('Search photo library'), findsOneWidget);
    expect(find.text('Use cloud media store'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
  });

  testWidgets('review groups by confidence, pre-checks per ladder, and '
      'shows the prefix callout', (tester) async {
    final notifier = _SeededWizardNotifier(
      RepairWizardReview(
        proposals: [
          RepairProposal(
            item: broken('a'),
            confidence: RepairConfidence.exact,
            candidate: const RepairCandidate.file(
              path: '/nas/a.jpg',
              sizeBytes: 4,
            ),
          ),
          RepairProposal(
            item: broken('b'),
            confidence: RepairConfidence.edited,
            candidate: const RepairCandidate.file(
              path: '/nas/b.jpg',
              sizeBytes: 4,
              hash: 'X',
            ),
          ),
          RepairProposal(
            item: broken('c'),
            confidence: RepairConfidence.unmatched,
          ),
        ],
        prefixMove: const PrefixMove(
          fromPrefix: '/old',
          toPrefix: '/nas',
          coveredCount: 2,
        ),
      ),
      checked: {'a'},
    );
    await tester.pumpWidget(host(notifier));
    await tester.pumpAndSettle();

    expect(find.text('Exact'), findsOneWidget);
    expect(find.text('Edited file'), findsOneWidget);
    expect(find.text('No candidate'), findsOneWidget);
    expect(
      find.text('Folder move detected: /old to /nas covers 2 files'),
      findsOneWidget,
    );
    expect(find.text('Re-link 1 files'), findsOneWidget);

    await tester.tap(find.text('Re-link 1 files'));
    expect(notifier.applyCalls, 1);
  });

  testWidgets('done state renders the summary', (tester) async {
    await tester.pumpWidget(
      host(
        _SeededWizardNotifier(
          const RepairWizardDone(
            report: RepairApplyReport(
              relinked: 3,
              cloudBacked: 2,
              reuploadsQueued: 1,
              failed: 0,
              skipped: 4,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        '3 re-linked, 2 cloud-backed, 1 re-uploads queued, 0 failed, '
        '4 skipped',
      ),
      findsOneWidget,
    );
  });

  testWidgets('error state shows a localized message, not the exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        _SeededWizardNotifier(
          RepairWizardError(
            Exception('/Users/someone/Secret Folder key=abc123'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('Secret Folder'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
  });
}
