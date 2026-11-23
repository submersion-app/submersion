import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/currency_scope.dart';

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

  /// True when a stored mapping array is malformed or names only dive modes
  /// this build does not know (issue #4942). It decodes to an empty list,
  /// which would read as "any dive", so the engine applies the rule's own
  /// mapping instead. The repository keeps the stored value on a save that
  /// leaves the mapping alone.
  final bool unreadableMapping;

  /// The mapping exactly as stored, set when the pref is read from the
  /// database or a backup; null for one built in memory. [mappingJson]
  /// writes it back while the lists still hold the same values, so a
  /// mapping this build cannot read survives a save, a backup and a
  /// restore (issue #4942). A storage detail, so not part of equality.
  final CurrencyMappingJson? storedMapping;

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
    this.unreadableMapping = false,
    this.storedMapping,
    this.muted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// True when the rule's own mapping applies: neither half is overridden,
  /// or the override is one this build cannot read.
  bool get inheritsMapping =>
      unreadableMapping ||
      (countedDiveTypeIds == null && countedDiveModes == null);

  /// The mapping as it is stored: [storedMapping] while the lists hold the
  /// same values, else the lists encoded, NULL where a half inherits.
  CurrencyMappingJson get mappingJson =>
      CurrencyScopeCodec.keepMappingIfUnchanged(
        stored: storedMapping,
        next: encodedMapping,
      );

  /// The lists encoded, whatever is stored: the mapping as a diver set it.
  CurrencyMappingJson get encodedMapping => (
    types: countedDiveTypeIds == null
        ? null
        : CurrencyScopeCodec.encode(countedDiveTypeIds!),
    modes: countedDiveModes == null
        ? null
        : CurrencyScopeCodec.encode([
            for (final m in countedDiveModes!) m.name,
          ]),
  );

  CurrencyPref copyWith({
    String? id,
    String? certificationId,
    String? ruleId,
    int? lapseDaysOverride,
    int? leadDaysOverride,
    List<String>? countedDiveTypeIds,
    List<DiveMode>? countedDiveModes,
    bool? unreadableMapping,
    CurrencyMappingJson? storedMapping,
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
    unreadableMapping: unreadableMapping ?? this.unreadableMapping,
    storedMapping: storedMapping ?? this.storedMapping,
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
    unreadableMapping,
    muted,
    createdAt,
    updatedAt,
  ];
}
