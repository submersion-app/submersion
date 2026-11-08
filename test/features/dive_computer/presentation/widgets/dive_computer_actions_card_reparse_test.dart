import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_computer/data/services/reparse_batch_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_batch_provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_actions_card.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Records what the card asked to re-parse.
class _RecordingBatch implements ReparseBatchService {
  String? askedForComputer;
  List<String>? ranDives;
  String? ranComputer;

  @override
  Future<List<String>> diveIdsForComputer(String computerId) async {
    askedForComputer = computerId;
    return ['d1', 'd2'];
  }

  @override
  Future<ReparseBatchResult> run(
    List<String> diveIds, {
    required RawDiveParseFn parseFn,
    String? computerId,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    ranDives = diveIds;
    ranComputer = computerId;
    for (var i = 0; i < diveIds.length; i++) {
      onProgress?.call(i + 1, diveIds.length);
    }
    return ReparseBatchResult(
      total: diveIds.length,
      succeeded: diveIds.length,
      skipped: 0,
      notProcessed: 0,
      profilesPreserved: 0,
      failures: const [],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'confirming re-parse all runs this computer\'s dives in the dialog',
    (tester) async {
      final batch = _RecordingBatch();
      final computer = DiveComputer(
        id: 'comp-A',
        name: 'Perdix',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            rawDataCountProvider(
              'comp-A',
            ).overrideWith((ref) async => (withRawData: 2, withoutRawData: 0)),
            reparseBatchServiceProvider.overrideWithValue(batch),
            reparseParseFnProvider.overrideWithValue(
              (vendor, product, model, raw) => throw UnimplementedError(),
            ),
          ],
          child: SingleChildScrollView(
            child: DiveComputerActionsCard(computer: computer),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Re-parse all dives'));
      await tester.pumpAndSettle();
      // The confirmation still counts this computer's stored data.
      await tester.tap(find.widgetWithText(FilledButton, 'Re-parse'));
      await tester.pumpAndSettle();

      expect(batch.askedForComputer, 'comp-A');
      expect(batch.ranDives, ['d1', 'd2']);
      expect(batch.ranComputer, 'comp-A');
      expect(find.text('Re-parse finished'), findsOneWidget);
      expect(find.text('Re-parsed 2 of 2 dives.'), findsOneWidget);
    },
  );
}
