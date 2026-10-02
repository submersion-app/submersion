import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_merge_builder.dart';

/// A computer tissue snapshot is a start/end pair, so a sequential merge
/// takes the start from the earliest segment and the end from the latest.
void main() {
  const builder = DiveMergeBuilder();

  Dive segment(String id, int hour, {ComputerTissueSnapshot? tissue}) => Dive(
    id: id,
    diverId: 'diver1',
    dateTime: DateTime.utc(2026, 7, 1, hour),
    entryTime: DateTime.utc(2026, 7, 1, hour),
    runtime: const Duration(minutes: 30),
    computerTissue: tissue,
  );

  ComputerTissueSnapshot snapshot(double start, double end) =>
      ComputerTissueSnapshot(
        algorithm: 'zhl_16c',
        start: ComputerTissueState(n2LoadPercent: start),
        end: ComputerTissueState(n2LoadPercent: end),
      );

  test('takes the start from the earliest segment and the end from the '
      'latest', () {
    final merged = builder.build([
      segment('b', 10, tissue: snapshot(40, 55)),
      segment('a', 9, tissue: snapshot(5, 30)),
    ]).mergedDive;

    expect(
      merged.computerTissue,
      const ComputerTissueSnapshot(
        algorithm: 'zhl_16c',
        start: ComputerTissueState(n2LoadPercent: 5),
        end: ComputerTissueState(n2LoadPercent: 55),
      ),
    );
  });

  test('never stores a middle segment\'s state as the combined end', () {
    final merged = builder.build([
      segment('a', 9, tissue: snapshot(5, 30)),
      segment('b', 10),
    ]).mergedDive;

    expect(merged.computerTissue!.start!.n2LoadPercent, 5);
    expect(merged.computerTissue!.end, isNull);
  });

  test('never stores a later segment\'s state as the combined start', () {
    final merged = builder.build([
      segment('a', 9),
      segment('b', 10, tissue: snapshot(40, 55)),
    ]).mergedDive;

    expect(merged.computerTissue!.start, isNull);
    expect(merged.computerTissue!.end!.n2LoadPercent, 55);
    expect(merged.computerTissue!.algorithm, 'zhl_16c');
  });

  test('has no snapshot when neither end segment has one', () {
    final merged = builder.build([
      segment('a', 9),
      segment('b', 10, tissue: snapshot(40, 55)),
      segment('c', 11),
    ]).mergedDive;

    expect(merged.computerTissue, isNull);
  });
}
