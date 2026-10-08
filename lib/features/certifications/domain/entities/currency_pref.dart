import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// A diver's override of one currency rule for one certification. An absent
/// row means "inherit everything", so rules apply by default with nothing
/// seeded per card.
///
/// `copyWith` cannot clear a nullable field back to null, so the repository
/// writes a pref by full value, and "go back to inheriting" is expressed by
/// building a new pref, not by nulling fields through `copyWith`.
class CurrencyPref extends Equatable {
  final String id;
  final String certificationId;
  final String ruleId;
  final int? lapseDaysOverride;
  final int? leadDaysOverride;

  /// NULL inherits the rule's mapping. An EMPTY list is the diver saying
  /// "any dive counts". The two are different answers and must not be
  /// collapsed.
  final List<String>? countedDiveTypeIds;
  final List<DiveMode>? countedDiveModes;

  final bool muted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CurrencyPref({
    required this.id,
    required this.certificationId,
    required this.ruleId,
    this.lapseDaysOverride,
    this.leadDaysOverride,
    this.countedDiveTypeIds,
    this.countedDiveModes,
    this.muted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// True when neither mapping is overridden, so the rule's own applies.
  bool get inheritsMapping =>
      countedDiveTypeIds == null && countedDiveModes == null;

  CurrencyPref copyWith({
    String? id,
    String? certificationId,
    String? ruleId,
    int? lapseDaysOverride,
    int? leadDaysOverride,
    List<String>? countedDiveTypeIds,
    List<DiveMode>? countedDiveModes,
    bool? muted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CurrencyPref(
    id: id ?? this.id,
    certificationId: certificationId ?? this.certificationId,
    ruleId: ruleId ?? this.ruleId,
    lapseDaysOverride: lapseDaysOverride ?? this.lapseDaysOverride,
    leadDaysOverride: leadDaysOverride ?? this.leadDaysOverride,
    countedDiveTypeIds: countedDiveTypeIds ?? this.countedDiveTypeIds,
    countedDiveModes: countedDiveModes ?? this.countedDiveModes,
    muted: muted ?? this.muted,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    id,
    certificationId,
    ruleId,
    lapseDaysOverride,
    leadDaysOverride,
    countedDiveTypeIds,
    countedDiveModes,
    muted,
    createdAt,
    updatedAt,
  ];
}
