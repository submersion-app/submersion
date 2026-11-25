import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/presentation/pages/data_quality_inbox_actions.dart';
import 'package:submersion/features/data_quality/presentation/providers/data_quality_providers.dart';
import 'package:submersion/features/dive_log/data/services/dive_source_removal_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

import '../../../helpers/test_app.dart';

class _FakeRemoval implements DiveSourceRemovalService {
  final removed = <String>[];

  @override
  Future<bool> sharesComputer({
    required String diveId,
    required String sourceId,
  }) async => false;

  @override
  Future<SourceRemoval> remove({
    required String diveId,
    required String sourceId,
  }) async {
    removed.add(sourceId);
    return const SourceRemoval(operationId: 'op-1');
  }
}

class _FakeFindings extends Fake implements QualityFindingsRepository {
  final statuses = <String, QualityStatus>{};

  @override
  Future<void> setStatus(String id, QualityStatus status) async =>
      statuses[id] = status;
}

/// The inbox's Remove source (issue #4393) refreshes what shows the dive as
/// the dive page's menu does (issue #4972): a dive page left open under the
/// inbox stops showing or overlaying the source that is gone.
void main() {
  final finding = QualityFinding(
    id: 'f1',
    diveId: 'd1',
    detectorId: 'conflicting_sources',
    detectorVersion: 1,
    category: QualityCategory.values.first,
    severity: QualitySeverity.info,
    status: QualityStatus.open,
    params: const {},
    createdAt: DateTime.utc(2026, 11, 1),
    updatedAt: DateTime.utc(2026, 11, 1),
  );

  testWidgets('stops showing and overlaying the removed source', (
    tester,
  ) async {
    final removal = _FakeRemoval();
    final findings = _FakeFindings();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          diveSourceRemovalServiceProvider.overrideWithValue(removal),
          qualityFindingsRepositoryProvider.overrideWithValue(findings),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final viewing = ref.watch(activeDiveSourceProvider('d1'));
            final overlays = ref.watch(overlaySourcesProvider('d1'));
            return Column(
              children: [
                Text('viewing ${viewing ?? 'none'}'),
                Text('overlays ${(overlays.toList()..sort()).join(',')}'),
                TextButton(
                  onPressed: () {
                    ref.read(activeDiveSourceProvider('d1').notifier).state =
                        's2';
                    ref.read(overlaySourcesProvider('d1').notifier).state = {
                      's2',
                      's3',
                    };
                  },
                  child: const Text('view'),
                ),
                TextButton(
                  onPressed: () => runRemoveSource(
                    context,
                    ref,
                    finding: finding,
                    diveId: 'd1',
                    sourceId: 's2',
                    sourceName: 'Perdix 2',
                  ),
                  child: const Text('remove'),
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('view'));
    await tester.pump();
    expect(find.text('viewing s2'), findsOneWidget);

    await tester.tap(find.text('remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(removal.removed, ['s2']);
    expect(findings.statuses, {'f1': QualityStatus.resolved});
    expect(find.text('viewing none'), findsOneWidget);
    expect(find.text('overlays s3'), findsOneWidget);
  });
}
