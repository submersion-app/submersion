import 'dart:math';

import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// How a diver is doing with naming one species (issue #5027): a Leitner
/// box from 1 to 5 and when it is next due.
class PracticeState extends Equatable {
  const PracticeState({
    required this.speciesId,
    required this.box,
    required this.dueAt,
    this.rightCount = 0,
    this.wrongCount = 0,
    this.lastPractisedAt,
  });

  /// A species never practised: box 1, due now.
  factory PracticeState.fresh(String speciesId, DateTime now) =>
      PracticeState(speciesId: speciesId, box: 1, dueAt: now);

  final String speciesId;
  final int box;
  final DateTime dueAt;
  final int rightCount;
  final int wrongCount;
  final DateTime? lastPractisedAt;

  PracticeState copyWith({
    String? speciesId,
    int? box,
    DateTime? dueAt,
    int? rightCount,
    int? wrongCount,
    DateTime? lastPractisedAt,
  }) => PracticeState(
    speciesId: speciesId ?? this.speciesId,
    box: box ?? this.box,
    dueAt: dueAt ?? this.dueAt,
    rightCount: rightCount ?? this.rightCount,
    wrongCount: wrongCount ?? this.wrongCount,
    lastPractisedAt: lastPractisedAt ?? this.lastPractisedAt,
  );

  @override
  List<Object?> get props => [
    speciesId,
    box,
    dueAt,
    rightCount,
    wrongCount,
    lastPractisedAt,
  ];
}

/// The highest box.
const kLeitnerTopBox = 5;

/// How long a species rests after a right answer lands it in each box.
const kLeitnerDelays = {
  2: Duration(days: 1),
  3: Duration(days: 3),
  4: Duration(days: 7),
  5: Duration(days: 21),
};

/// [state] after one answer at [now]: right moves it up a box and rests it,
/// wrong sends it back to box 1, due at once.
PracticeState applyAnswer(
  PracticeState state, {
  required bool correct,
  required DateTime now,
}) {
  if (!correct) {
    return state.copyWith(
      box: 1,
      dueAt: now,
      wrongCount: state.wrongCount + 1,
      lastPractisedAt: now,
    );
  }
  final box = min(state.box + 1, kLeitnerTopBox);
  return state.copyWith(
    box: box,
    dueAt: now.add(kLeitnerDelays[box]!),
    rightCount: state.rightCount + 1,
    lastPractisedAt: now,
  );
}

/// The species of one session from [pool]: those due (lowest box first,
/// then the longest overdue), then those never practised, then the rest, at
/// most [size] and none twice.
List<String> pickPracticeSession({
  required List<String> pool,
  required Map<String, PracticeState> states,
  required DateTime now,
  required Random random,
  int size = 10,
}) {
  final unique = pool.toSet().toList();
  final due = <PracticeState>[];
  final fresh = <String>[];
  final rest = <String>[];
  for (final id in unique) {
    final state = states[id];
    if (state == null) {
      fresh.add(id);
    } else if (!state.dueAt.isAfter(now)) {
      due.add(state);
    } else {
      rest.add(id);
    }
  }
  due.sort((a, b) {
    final byBox = a.box.compareTo(b.box);
    if (byBox != 0) return byBox;
    return a.dueAt.compareTo(b.dueAt);
  });
  return [
    for (final s in due) s.speciesId,
    ...(fresh..shuffle(random)),
    ...(rest..shuffle(random)),
  ].take(size).toList();
}

/// [count] wrong names to offer beside [answer]: from its own category
/// first, so the choice is not trivial, then from any other species.
List<String> pickDistractors({
  required String answer,
  required Map<String, SpeciesCategory> categoryOf,
  required Random random,
  int count = 3,
}) {
  final category = categoryOf[answer];
  final same = <String>[];
  final other = <String>[];
  for (final entry in categoryOf.entries) {
    if (entry.key == answer) continue;
    (entry.value == category ? same : other).add(entry.key);
  }
  return [
    ...(same..shuffle(random)),
    ...(other..shuffle(random)),
  ].take(count).toList();
}
