import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/species_id/data/services/dive_species_run.dart';
import 'package:submersion/features/species_id/data/services/media_identification_service.dart';
import 'package:submersion/features/species_id/data/services/species_batch_run.dart';
import 'package:submersion/features/species_id/domain/entities/dive_species_run_state.dart';
import 'package:submersion/features/species_id/domain/entities/species_batch.dart';
import 'package:submersion/features/species_id/presentation/providers/species_batch_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/species_batch_confirm_dialog.dart';
import 'package:submersion/features/species_id/presentation/widgets/species_batch_end_notice.dart';
import 'package:submersion/features/species_id/presentation/widgets/species_batch_progress_card.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../media/presentation/support/media_widget_harness.dart';

/// A batch that records what the card asks of it.
class _SpyBatch extends SpeciesBatchRun {
  _SpyBatch()
    : super(
        runs: () => DiveSpeciesRun(
          mediaForDive: (_) async => const [],
          diveLocation: (_) async => (exists: true, site: null, entry: null),
          request: (_, _) async => RunItemOutcome.done,
          cancel: (_) {},
          applyAll: (_, _) async => 0,
          databaseGeneration: () => 0,
        ),
        databaseGeneration: () => 0,
        isReverted: (_) async => false,
        newOperationId: () => 'op',
      );

  final calls = <String>[];

  @override
  void cancel() => calls.add('cancel');

  @override
  void resume() => calls.add('resume');
}

PlannedDive _dive(String id, int items, {int? toLookAt}) =>
    PlannedDive(diveId: id, items: items, toLookAt: toLookAt ?? items);

/// Find species over many dives: its confirmation, its progress, and how
/// its end is told (issue #5127).
void main() {
  group('confirmation', () {
    late StreamController<SpeciesBatchPlan> plans;
    SpeciesBatchChoice? chosen;
    var popped = false;

    Future<void> open(WidgetTester tester, {int diveCount = 3}) async {
      plans = StreamController<SpeciesBatchPlan>();
      chosen = null;
      popped = false;
      await tester.pumpWidget(
        await mediaTestApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                chosen = await showDialog<SpeciesBatchChoice>(
                  context: context,
                  builder: (_) => SpeciesBatchConfirmDialog(
                    plans: plans.stream,
                    diveCount: diveCount,
                  ),
                );
                popped = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
    }

    testWidgets('counts first, then says what it will do', (tester) async {
      await open(tester);
      expect(
        find.byKey(const ValueKey('species_batch_counting')),
        findsOneWidget,
      );
      expect(find.text('Counting photos and videos: 0 of 3 dives'), findsOne);

      plans.add(SpeciesBatchPlan(dives: [_dive('d1', 4)], divesAsked: 2));
      await tester.pump();
      expect(find.text('Counting photos and videos: 2 of 3 dives'), findsOne);
      final start = tester.widget<FilledButton>(
        find.byKey(const ValueKey('species_batch_start')),
      );
      expect(start.onPressed, isNull);

      plans.add(
        SpeciesBatchPlan(
          dives: [_dive('d1', 4), _dive('d3', 2)],
          divesAsked: 3,
        ),
      );
      await plans.close();
      await tester.pump();
      expect(find.text('2 dives, 6 photos and videos to look at.'), findsOne);

      await tester.tap(find.byKey(const ValueKey('species_batch_start')));
      await tester.pumpAndSettle();
      expect(popped, isTrue);
      expect(chosen!.plan.dives, hasLength(2));
      expect(chosen!.onDeviceOnly, isFalse);
    });

    testWidgets('offers looking only at what is on this device', (
      tester,
    ) async {
      await open(tester, diveCount: 1);
      plans.add(
        SpeciesBatchPlan(
          dives: [_dive('d1', 4)],
          notOnDevice: 3,
          divesAsked: 1,
        ),
      );
      await plans.close();
      await tester.pump();

      expect(find.text('3 of them are not on this device.'), findsOne);
      await tester.tap(
        find.byKey(const ValueKey('species_batch_on_device_only')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('species_batch_start')));
      await tester.pumpAndSettle();

      expect(chosen!.onDeviceOnly, isTrue);
    });

    testWidgets('no download choice when everything is here', (tester) async {
      await open(tester, diveCount: 1);
      plans.add(SpeciesBatchPlan(dives: [_dive('d1', 4)], divesAsked: 1));
      await plans.close();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('species_batch_on_device_only')),
        findsNothing,
      );
    });

    testWidgets('nothing to do offers only OK', (tester) async {
      await open(tester, diveCount: 2);
      plans.add(const SpeciesBatchPlan(divesAsked: 2));
      await plans.close();
      await tester.pump();

      expect(
        find.text('All photos and videos of these dives are already checked.'),
        findsOne,
      );
      expect(find.byKey(const ValueKey('species_batch_start')), findsNothing);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(chosen, isNull);
    });

    testWidgets('dives with only matches to tag say so', (tester) async {
      await open(tester, diveCount: 1);
      plans.add(
        SpeciesBatchPlan(dives: [_dive('d1', 4, toLookAt: 0)], divesAsked: 1),
      );
      await plans.close();
      await tester.pump();

      expect(
        find.textContaining('Nothing new to look at. Confident matches'),
        findsOne,
      );
      final start = tester.widget<FilledButton>(
        find.byKey(const ValueKey('species_batch_start')),
      );
      expect(start.onPressed, isNotNull);
    });

    testWidgets('a long run says it takes a while', (tester) async {
      await open(tester, diveCount: 1);
      plans.add(
        SpeciesBatchPlan(
          dives: [_dive('d1', kSpeciesBatchLongRun + 1)],
          divesAsked: 1,
        ),
      );
      await plans.close();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('species_batch_takes_a_while')),
        findsOne,
      );
    });

    testWidgets('a failed count says so and offers OK', (tester) async {
      await open(tester, diveCount: 1);
      plans.addError(StateError('boom'));
      await plans.close();
      await tester.pump();

      expect(
        find.text('The photos and videos could not be counted.'),
        findsOne,
      );
      expect(find.byKey(const ValueKey('species_batch_start')), findsNothing);
    });

    testWidgets('cancel while counting stops the count', (tester) async {
      await open(tester);
      var cancelled = false;
      plans.onCancel = () => cancelled = true;

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(chosen, isNull);
      expect(cancelled, isTrue);
    });
  });

  group('progress card', () {
    Future<_SpyBatch> pump(
      WidgetTester tester,
      SpeciesBatchProgress? progress,
    ) async {
      final batch = _SpyBatch();
      await tester.pumpWidget(
        await mediaTestApp(
          overrides: [
            speciesBatchRunProvider.overrideWith((ref) => batch),
            speciesBatchProgressProvider.overrideWithValue(progress),
          ],
          home: const Scaffold(body: SpeciesBatchProgressCard()),
        ),
      );
      await tester.pump();
      return batch;
    }

    testWidgets('draws nothing with no run going', (tester) async {
      await pump(tester, null);
      expect(
        find.byKey(const ValueKey('species_batch_progress')),
        findsNothing,
      );
    });

    testWidgets('shows the dive and the photos done', (tester) async {
      final batch = await pump(
        tester,
        const SpeciesBatchProgress(
          diveNumber: 3,
          diveCount: 40,
          itemsDone: 120,
          itemsTotal: 900,
        ),
      );

      expect(find.text('Finding species'), findsOne);
      expect(
        find.text('Dive 3 of 40 · 120 of 900 photos and videos'),
        findsOne,
      );
      expect(find.byKey(const ValueKey('species_batch_resume')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('species_batch_cancel')));
      expect(batch.calls, ['cancel']);
    });

    testWidgets('a pause says why and offers Resume', (tester) async {
      final batch = await pump(
        tester,
        const SpeciesBatchProgress(
          diveNumber: 1,
          diveCount: 2,
          itemsDone: 0,
          itemsTotal: 5,
          paused: true,
          pauseReason: DiveRunPause.background,
        ),
      );

      expect(find.text('Paused while the app is in the background'), findsOne);
      await tester.tap(find.byKey(const ValueKey('species_batch_resume')));
      expect(batch.calls, ['resume']);
    });

    testWidgets('a long run fits a phone width', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(
        tester,
        const SpeciesBatchProgress(
          diveNumber: 12345,
          diveCount: 15000,
          itemsDone: 48000,
          itemsTotal: 52000,
          paused: true,
          pauseReason: DiveRunPause.tooHot,
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('end notice', () {
    final l10n = AppLocalizationsEn();
    const ran = SpeciesBatchRunState(diveCount: 2, itemsPlanned: 3);

    test('tells only a batch that was running and ended', () {
      final ended = ran.copyWith(phase: SpeciesBatchPhase.finished);
      expect(speciesBatchEnded(ran, ended), isTrue);
      expect(speciesBatchEnded(null, ended), isFalse);
      expect(speciesBatchEnded(ended, ended), isFalse);
      expect(speciesBatchEnded(ran, ran), isFalse);
    });

    test('says what it looked at, and what it left out', () {
      final ended = ran.copyWith(
        phase: SpeciesBatchPhase.finished,
        summary: const DiveRunSummary(
          photos: 3,
          speciesTagged: 2,
          unreadable: 1,
          notOnDevice: 4,
        ),
      );

      final text = speciesBatchEndText(l10n, ended, toReview: 5);

      expect(text, contains('5 to review'));
      expect(text, contains('1 could not be opened.'));
      expect(text, contains('4 not on this device were left out.'));
      expect(text, isNot(contains('stopped')));
    });

    test('a cancelled batch says it stopped', () {
      final ended = ran.copyWith(phase: SpeciesBatchPhase.cancelled);

      expect(
        speciesBatchEndText(l10n, ended, toReview: 0),
        startsWith('Species search stopped.'),
      );
    });

    test('Review only when there is something to review', () {
      final ended = ran.copyWith(phase: SpeciesBatchPhase.finished);
      expect(
        speciesBatchEndSnackBar(
          l10n,
          ended,
          toReview: 0,
          onReview: () {},
        ).action,
        isNull,
      );
      expect(
        speciesBatchEndSnackBar(
          l10n,
          ended,
          toReview: 2,
          onReview: () {},
        ).action,
        isNotNull,
      );
    });
  });
}
