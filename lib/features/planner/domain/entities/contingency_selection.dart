import 'package:flutter/foundation.dart';

/// Which contingency toggles are on: +depth, +time and any set of lost
/// cylinders, all independent of each other. Transient UI state, never
/// saved with the plan.
@immutable
class ContingencySelection {
  final bool deeper;
  final bool longer;
  final Set<String> lostTankIds;

  const ContingencySelection({
    this.deeper = false,
    this.longer = false,
    this.lostTankIds = const {},
  });

  static const none = ContingencySelection();

  bool get isEmpty => !deeper && !longer && lostTankIds.isEmpty;

  /// The slate deviation the +depth / +time toggles amount to ('deeper',
  /// 'longer' or 'both'), or null when neither is on.
  String? get deviationKey => switch ((deeper, longer)) {
    (true, true) => 'both',
    (true, false) => 'deeper',
    (false, true) => 'longer',
    (false, false) => null,
  };

  ContingencySelection copyWith({
    bool? deeper,
    bool? longer,
    Set<String>? lostTankIds,
  }) => ContingencySelection(
    deeper: deeper ?? this.deeper,
    longer: longer ?? this.longer,
    lostTankIds: lostTankIds ?? this.lostTankIds,
  );

  @override
  bool operator ==(Object other) =>
      other is ContingencySelection &&
      other.deeper == deeper &&
      other.longer == longer &&
      setEquals(other.lostTankIds, lostTankIds);

  @override
  int get hashCode =>
      Object.hash(deeper, longer, Object.hashAllUnordered(lostTankIds));

  @override
  String toString() =>
      'ContingencySelection(deeper: $deeper, longer: $longer, '
      'lostTankIds: $lostTankIds)';
}
