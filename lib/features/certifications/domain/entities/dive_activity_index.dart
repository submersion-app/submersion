import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// When the diver last dived, overall, per dive type and per dive mode, as
/// calendar days (issue #2267). Built from three GROUP BY aggregates, never
/// one query per certification.
class DiveActivityIndex extends Equatable {
  final DateTime? lastDiveAt;
  final Map<String, DateTime> lastDiveByTypeId;
  final Map<DiveMode, DateTime> lastDiveByMode;

  const DiveActivityIndex({
    this.lastDiveAt,
    this.lastDiveByTypeId = const {},
    this.lastDiveByMode = const {},
  });

  static const empty = DiveActivityIndex();

  DiveActivityIndex copyWith({
    DateTime? lastDiveAt,
    Map<String, DateTime>? lastDiveByTypeId,
    Map<DiveMode, DateTime>? lastDiveByMode,
  }) => DiveActivityIndex(
    lastDiveAt: lastDiveAt ?? this.lastDiveAt,
    lastDiveByTypeId: lastDiveByTypeId ?? this.lastDiveByTypeId,
    lastDiveByMode: lastDiveByMode ?? this.lastDiveByMode,
  );

  @override
  List<Object?> get props => [lastDiveAt, lastDiveByTypeId, lastDiveByMode];
}
