import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';

SetUpInputs _inputs({
  bool accountHere = false,
  bool syncEstablished = false,
  bool customFolder = false,
  bool backupsAuto = false,
  bool backupOffDevice = false,
  bool photosAttached = false,
  bool photosSkipped = false,
  bool hidden = false,
}) => SetUpInputs(
  accountHere: accountHere,
  syncEstablished: syncEstablished,
  customFolder: customFolder,
  backupsAuto: backupsAuto,
  backupOffDevice: backupOffDevice,
  photosAttached: photosAttached,
  photosSkipped: photosSkipped,
  hidden: hidden,
);

const _d = SetUpMark.done;
const _n = SetUpMark.next;
const _y = SetUpMark.notYet;
const _s = SetUpMark.skipped;

void main() {
  final rows =
      <
        ({
          String name,
          SetUpInputs inputs,
          List<SetUpMark> marks,
          int settled,
          SetUpStep? next,
          bool anyDone,
          bool showsSteps,
        })
      >[
        (
          name: 'nothing set up',
          inputs: _inputs(),
          marks: [_n, _y, _y, _y],
          settled: 0,
          next: SetUpStep.account,
          anyDone: false,
          showsSteps: true,
        ),
        (
          name: 'an account only',
          inputs: _inputs(accountHere: true),
          marks: [_d, _n, _y, _y],
          settled: 1,
          next: SetUpStep.sync,
          anyDone: true,
          showsSteps: true,
        ),
        (
          name: 'a custom database folder settles account and sync',
          inputs: _inputs(customFolder: true),
          marks: [_d, _d, _n, _y],
          settled: 2,
          next: SetUpStep.backups,
          anyDone: true,
          showsSteps: true,
        ),
        (
          name: 'sync done, backups without a copy off this device',
          inputs: _inputs(
            accountHere: true,
            syncEstablished: true,
            backupsAuto: true,
          ),
          marks: [_d, _d, _n, _y],
          settled: 2,
          next: SetUpStep.backups,
          anyDone: true,
          showsSteps: true,
        ),
        (
          name: 'a copy off this device without automatic backups',
          inputs: _inputs(
            accountHere: true,
            syncEstablished: true,
            backupOffDevice: true,
          ),
          marks: [_d, _d, _n, _y],
          settled: 2,
          next: SetUpStep.backups,
          anyDone: true,
          showsSteps: true,
        ),
        (
          name: 'everything done',
          inputs: _inputs(
            accountHere: true,
            syncEstablished: true,
            backupsAuto: true,
            backupOffDevice: true,
            photosAttached: true,
          ),
          marks: [_d, _d, _d, _d],
          settled: 4,
          next: null,
          anyDone: true,
          showsSteps: false,
        ),
        (
          name: 'photos skipped and the rest done is complete',
          inputs: _inputs(
            accountHere: true,
            syncEstablished: true,
            backupsAuto: true,
            backupOffDevice: true,
            photosSkipped: true,
          ),
          marks: [_d, _d, _d, _s],
          settled: 4,
          next: null,
          anyDone: true,
          showsSteps: false,
        ),
        (
          name: 'photos attached wins over skipped',
          inputs: _inputs(photosAttached: true, photosSkipped: true),
          marks: [_n, _y, _y, _d],
          settled: 1,
          next: SetUpStep.account,
          anyDone: true,
          showsSteps: true,
        ),
        (
          name: 'skipped photos alone is not a done step',
          inputs: _inputs(photosSkipped: true),
          marks: [_n, _y, _y, _s],
          settled: 1,
          next: SetUpStep.account,
          anyDone: false,
          showsSteps: true,
        ),
        (
          name: 'hidden keeps the next step but shows no steps',
          inputs: _inputs(accountHere: true, hidden: true),
          marks: [_d, _n, _y, _y],
          settled: 1,
          next: SetUpStep.sync,
          anyDone: true,
          showsSteps: false,
        ),
      ];

  for (final row in rows) {
    test(row.name, () {
      final progress = setUpProgress(row.inputs);
      expect([
        for (final step in SetUpStep.values) progress.marks[step],
      ], row.marks);
      expect(progress.settled, row.settled);
      expect(progress.next, row.next);
      expect(progress.anyDone, row.anyDone);
      expect(progress.showsSteps, row.showsSteps);
    });
  }

  // Issue #3482 review: the same facts give an equal progress, so a no-op
  // reload upstream notifies no one.
  test('the same inputs give an equal progress', () {
    expect(
      setUpProgress(_inputs(accountHere: true)),
      setUpProgress(_inputs(accountHere: true)),
    );
    expect(
      setUpProgress(_inputs(accountHere: true)),
      isNot(setUpProgress(_inputs(accountHere: true, hidden: true))),
    );
  });
}
