// Issue #3482 phase 5: the steps around the replace, in the spec's order
// (section 6.4.1): the library is proven readable, a pinned backup is
// taken, photo copies are detached, the library is replaced, and only then
// is the device's photo queue and sync bookkeeping moved on. A failure
// after the detach puts the attachment back.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/sync/replace_and_join_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

/// Records every step, and fails the ones a test names.
class _Steps implements ReplaceJoinSteps {
  _Steps(this.attachState);

  final MediaStoreAttachState attachState;
  final log = <String>[];
  ReplaceJoinResult? refuse;
  Object? applyFailure;
  Object? backupFailure;
  Object? queueFailure;
  bool photosSettle = true;
  String? backupNote;

  @override
  Future<({ReplaceJoinPrepared? prepared, ReplaceJoinResult? refused})>
  prepare() async {
    log.add('prepare');
    if (refuse case final r?) return (prepared: null, refused: r);
    return (prepared: ReplaceJoinPrepared.empty(), refused: null);
  }

  @override
  Future<void> takePinnedBackup(String note) async {
    log.add('backup');
    if (backupFailure case final f?) throw f;
    backupNote = note;
  }

  @override
  Future<ReplaceJoinResult> apply(ReplaceJoinPrepared prepared) async {
    log.add('apply');
    // The photo copies are detached before the library changes.
    expect(await attachState.attachedStoreId(), isNull);
    await prepared.dispose();
    if (applyFailure case final f?) throw f;
    return const ReplaceJoinResult(ReplaceJoinOutcome.replaced);
  }

  @override
  Future<bool> settlePhotoTransfers() async {
    log.add('settle photos');
    return photosSettle;
  }

  @override
  Future<void> discardPhotoQueue() async {
    log.add('queue');
    if (queueFailure case final f?) throw f;
  }

  @override
  Future<void> forgetPhotoStore() async => log.add('forget store');

  @override
  Future<void> settleSyncState() async => log.add('settle sync');

  @override
  Future<void> realignActiveDiver() async => log.add('realign diver');
}

/// An attachment that cannot be put back.
class _StuckAttachState extends MediaStoreAttachState {
  _StuckAttachState(SharedPreferences prefs) : super(prefs: prefs);

  @override
  Future<void> restore(MediaStoreAttachSnapshot snapshot) async =>
      throw StateError('prefs unavailable');
}

void main() {
  late MediaStoreAttachState attachState;
  late _Steps steps;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    attachState = MediaStoreAttachState(
      prefs: await SharedPreferences.getInstance(),
    );
    await attachState.setAttached(
      'store-a',
      providerType: CloudProviderType.dropbox,
      accountId: 'db-row',
    );
    steps = _Steps(attachState);
  });

  ReplaceAndJoinService service() =>
      ReplaceAndJoinService(steps: steps, attachState: attachState);

  test('runs the steps in order and moves the device on', () async {
    final result = await service().run(backupNote: 'Before joining');

    expect(result.outcome, ReplaceJoinOutcome.replaced);
    expect(steps.log, [
      'prepare',
      'backup',
      'settle photos',
      'apply',
      'queue',
      'forget store',
      'settle sync',
      'realign diver',
    ]);
    expect(steps.backupNote, 'Before joining');
    expect(await attachState.attachedStoreId(), isNull);
  });

  for (final outcome in [
    ReplaceJoinOutcome.noLibrary,
    ReplaceJoinOutcome.newerSchema,
    ReplaceJoinOutcome.needsPassphrase,
  ]) {
    test(
      'a library it cannot read (${outcome.name}) changes nothing',
      () async {
        steps.refuse = ReplaceJoinResult(outcome);

        final result = await service().run(backupNote: 'Before joining');

        expect(result.outcome, outcome);
        expect(steps.log, ['prepare'], reason: 'no backup, nothing touched');
        expect(await attachState.attachedStoreId(), 'store-a');
      },
    );
  }

  test('a failed backup stops before anything changes', () async {
    steps.backupFailure = StateError('disk full');

    await expectLater(
      service().run(backupNote: 'Before joining'),
      throwsStateError,
    );

    expect(steps.log, ['prepare', 'backup']);
    expect(await attachState.attachedStoreId(), 'store-a');
  });

  test('a failed replace puts the photo copies back', () async {
    steps.applyFailure = StateError('interrupted');

    await expectLater(
      service().run(backupNote: 'Before joining'),
      throwsStateError,
    );

    expect(steps.log, ['prepare', 'backup', 'settle photos', 'apply']);
    expect(await attachState.attachedStoreId(), 'store-a');
    expect(await attachState.attachedAccountId(), 'db-row');
  });

  test('the replace waits for a sync already running', () async {
    final gate = Completer<void>();
    final order = <String>[];
    final replacing = SyncCoordinator.run(() async {
      order.add('replace started');
      await gate.future;
      order.add('replace done');
    });
    final sync = service().run(backupNote: 'Before joining').then((_) {
      order.add('second run');
    });
    await Future<void>.delayed(Duration.zero);
    expect(order, ['replace started']);

    gate.complete();
    await Future.wait([replacing, sync]);
    expect(order, ['replace started', 'replace done', 'second run']);
  });

  // Review: once the library is replaced, a failing later step must not
  // put the old photo store back or report the replace as failed.
  test('a step after the swap that fails is logged and the rest run', () async {
    steps.queueFailure = StateError('queue busy');

    final result = await service().run(backupNote: 'Before joining');

    expect(result.outcome, ReplaceJoinOutcome.replaced);
    expect(steps.log, [
      'prepare',
      'backup',
      'settle photos',
      'apply',
      'queue',
      'forget store',
      'settle sync',
      'realign diver',
    ]);
    expect(await attachState.attachedStoreId(), isNull);
  });

  test('an attachment that cannot be put back does not hide why the '
      'replace failed', () async {
    final stuck = _StuckAttachState(await SharedPreferences.getInstance());
    steps.applyFailure = StateError('interrupted');

    await expectLater(
      ReplaceAndJoinService(
        steps: steps,
        attachState: stuck,
      ).run(backupNote: 'Before joining'),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', 'interrupted'),
      ),
    );
  });

  // Copilot review: a transfer the worker handed off keeps running after
  // the detach; the swap waits for it, and gives up for now if it does not
  // finish.
  test(
    'a photo transfer that does not finish stops the replace for now',
    () async {
      steps.photosSettle = false;

      final result = await service().run(backupNote: 'Before joining');

      expect(result.outcome, ReplaceJoinOutcome.photosBusy);
      expect(steps.log, ['prepare', 'backup', 'settle photos']);
      expect(await attachState.attachedStoreId(), 'store-a');
    },
  );
}
