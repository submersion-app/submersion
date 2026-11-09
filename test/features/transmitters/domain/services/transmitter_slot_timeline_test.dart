import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/transmitters/domain/services/transmitter_slot_timeline.dart';

/// Which transmitter held a computer's slot on a date (issue #4347).
void main() {
  SlotObservation seen(
    String serial,
    DateTime date, {
    String computer = 'perdix',
    int slot = 1,
  }) => SlotObservation(
    computerId: computer,
    slot: slot,
    date: date,
    serial: serial,
  );

  final mar = DateTime.utc(2026, 3, 12, 9);
  final jun = DateTime.utc(2026, 6, 1, 9);
  final timeline = TransmitterSlotTimeline([
    seen('111', mar),
    seen('111', DateTime.utc(2026, 4, 2, 9)),
    seen('222', jun),
  ]);

  test('a dive between two downloads with the same serial takes it', () {
    final r = timeline.resolve('perdix', 1, DateTime.utc(2026, 3, 20));
    expect(r.serial, '111');
    expect(r.changedHands, isFalse);
    expect(r.olderThanFirstDownload, isFalse);
  });

  test('a dive between downloads with different serials is skipped', () {
    final r = timeline.resolve('perdix', 1, DateTime.utc(2026, 5, 1));
    expect(r.serial, isNull);
    expect(r.changedHands, isTrue);
  });

  test('a dive after every download takes the latest pairing', () {
    final r = timeline.resolve('perdix', 1, DateTime.utc(2026, 8, 1));
    expect(r.serial, '222');
    expect(r.olderThanFirstDownload, isFalse);
  });

  test('a dive before every download takes the earliest pairing, flagged '
      'with that download date', () {
    final r = timeline.resolve('perdix', 1, DateTime.utc(2025, 11, 1));
    expect(r.serial, '111');
    expect(r.olderThanFirstDownload, isTrue);
    expect(r.firstDownload, mar);
  });

  test('a dive at the moment of a download resolves to it, even when the '
      'slot changed hands there', () {
    final r = timeline.resolve('perdix', 1, jun);
    expect(r.serial, '222');
    expect(r.changedHands, isFalse);
  });

  test('a dive earlier on the day of a download that shows a new serial '
      'counts as changed hands: the swap could have been that morning', () {
    final r = timeline.resolve('perdix', 1, DateTime.utc(2026, 6, 1, 7));
    expect(r.changedHands, isTrue);
    expect(r.serial, isNull);
  });

  test('another computer or slot has its own timeline', () {
    expect(timeline.resolve('petrel', 1, mar).serial, isNull);
    expect(timeline.resolve('perdix', 2, mar).serial, isNull);
    final both = TransmitterSlotTimeline([
      seen('111', mar),
      seen('999', mar, computer: 'petrel'),
    ]);
    expect(both.resolve('perdix', 1, jun).serial, '111');
    expect(both.resolve('petrel', 1, jun).serial, '999');
  });

  test('serials compare in canonical form', () {
    final t = TransmitterSlotTimeline([seen(' 111 ', mar), seen('111', jun)]);
    final r = t.resolve('perdix', 1, DateTime.utc(2026, 4, 1));
    expect(r.changedHands, isFalse);
    expect(r.serial, '111');
  });

  test('no observations resolve to nothing', () {
    final r = TransmitterSlotTimeline(const []).resolve('perdix', 0, mar);
    expect(r.serial, isNull);
    expect(r.changedHands, isFalse);
    expect(r.olderThanFirstDownload, isFalse);
  });
}
