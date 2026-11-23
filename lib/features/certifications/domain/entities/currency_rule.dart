import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/currency_scope.dart';

/// What a currency clock counts from.
enum CurrencyClockKind {
  /// Counts from a date on the card: its expiry, a ledger event, or the
  /// issue date plus the interval.
  date,

  /// Counts from the last qualifying dive, or a ledger event.
  activity;

  static CurrencyClockKind parse(String raw) =>
      CurrencyClockKind.values.firstWhere(
        (v) => v.name == raw,
        orElse: () => CurrencyClockKind.activity,
      );
}

/// One rule in the certification currency catalog (issue #2267).
///
/// Built-in rules are immutable reference data. Editing one creates a custom
/// rule whose [supersedesRuleId] names it, because built-in rows never sync
/// and an in-place edit would stay on one device.
class CurrencyRule extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final CurrencyClockKind clockKind;

  /// Empty means "any". Never null.
  final List<CertificationAgency> agencies;
  final List<CertificationLevel> levels;

  /// At or past this many days since the anchor the rule is lapsed.
  final int lapseDays;

  /// How many days before [lapseDays] the rule turns due soon.
  final int leadDays;

  /// Activity clocks only. Empty means any dive counts.
  final List<String> countedDiveTypeIds;
  final List<DiveMode> countedDiveModes;

  /// Built-ins name an l10n key resolved at render time; custom rules carry
  /// the diver's own text, which is never translated.
  final String? advisoryKey;
  final String? advisoryText;

  final String? supersedesRuleId;
  final bool isBuiltIn;

  /// True when a stored scope or mapping array names nothing this build
  /// knows, or is malformed (a rule written by a newer build, or a corrupt
  /// row). Decoding it would read as "any" and widen the rule, so the
  /// engine matches such a rule to nothing.
  final bool unreadableScope;

  /// The scope arrays exactly as stored, set when the rule is read from the
  /// database or a backup; null for a rule built in memory. The JSON
  /// getters write them back while the lists above still hold the same
  /// values, so a value this build cannot read survives a save, a backup
  /// and a restore (issue #4942). A storage detail, so not part of
  /// equality.
  final CurrencyScopeJson? storedScope;

  /// The clock kind exactly as stored, which may name one this build does
  /// not know ([clockKind] then reads activity). [clockKindJson] writes it
  /// back while [clockKind] is unchanged. Not part of equality.
  final String? storedClockKind;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CurrencyRule({
    required this.id,
    this.diverId,
    required this.name,
    required this.clockKind,
    this.agencies = const [],
    this.levels = const [],
    required this.lapseDays,
    required this.leadDays,
    this.countedDiveTypeIds = const [],
    this.countedDiveModes = const [],
    this.advisoryKey,
    this.advisoryText,
    this.supersedesRuleId,
    this.isBuiltIn = false,
    this.unreadableScope = false,
    this.storedScope,
    this.storedClockKind,
    required this.createdAt,
    required this.updatedAt,
  });

  CurrencyRule copyWith({
    String? id,
    String? diverId,
    String? name,
    CurrencyClockKind? clockKind,
    List<CertificationAgency>? agencies,
    List<CertificationLevel>? levels,
    int? lapseDays,
    int? leadDays,
    List<String>? countedDiveTypeIds,
    List<DiveMode>? countedDiveModes,
    String? advisoryKey,
    String? advisoryText,
    String? supersedesRuleId,
    bool? isBuiltIn,
    bool? unreadableScope,
    CurrencyScopeJson? storedScope,
    String? storedClockKind,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CurrencyRule(
    id: id ?? this.id,
    diverId: diverId ?? this.diverId,
    name: name ?? this.name,
    clockKind: clockKind ?? this.clockKind,
    agencies: agencies ?? this.agencies,
    levels: levels ?? this.levels,
    lapseDays: lapseDays ?? this.lapseDays,
    leadDays: leadDays ?? this.leadDays,
    countedDiveTypeIds: countedDiveTypeIds ?? this.countedDiveTypeIds,
    countedDiveModes: countedDiveModes ?? this.countedDiveModes,
    advisoryKey: advisoryKey ?? this.advisoryKey,
    advisoryText: advisoryText ?? this.advisoryText,
    supersedesRuleId: supersedesRuleId ?? this.supersedesRuleId,
    isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    unreadableScope: unreadableScope ?? this.unreadableScope,
    storedScope: storedScope ?? this.storedScope,
    storedClockKind: storedClockKind ?? this.storedClockKind,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// The clock kind as it is stored: [storedClockKind] while it still reads
  /// as [clockKind], else [clockKind]'s name.
  String get clockKindJson =>
      storedClockKind != null &&
          CurrencyClockKind.parse(storedClockKind!) == clockKind
      ? storedClockKind!
      : clockKind.name;

  /// Scope arrays as they are stored: [storedScope]'s while the lists hold
  /// the same values, else the lists encoded.
  String get agenciesJson => CurrencyScopeCodec.keepIfUnchanged(
    stored: storedScope?.agencies,
    next: CurrencyScopeCodec.encode([for (final a in agencies) a.name]),
    names: CurrencyScopeCodec.agencyNames,
  );
  String get levelsJson => CurrencyScopeCodec.keepIfUnchanged(
    stored: storedScope?.levels,
    next: CurrencyScopeCodec.encode([for (final l in levels) l.name]),
    names: CurrencyScopeCodec.levelNames,
  );
  String get diveTypesJson => _mappingJson.types!;
  String get diveModesJson => _mappingJson.modes!;

  CurrencyMappingJson get _mappingJson =>
      CurrencyScopeCodec.keepMappingIfUnchanged(
        stored: storedScope == null
            ? null
            : (types: storedScope!.types, modes: storedScope!.modes),
        next: encodedMapping,
      );

  /// The mapping lists encoded, whatever is stored: as an edit set them.
  CurrencyMappingJson get encodedMapping => (
    types: CurrencyScopeCodec.encode(countedDiveTypeIds),
    modes: CurrencyScopeCodec.encode([
      for (final m in countedDiveModes) m.name,
    ]),
  );

  @override
  List<Object?> get props => [
    id,
    diverId,
    name,
    clockKind,
    agencies,
    levels,
    lapseDays,
    leadDays,
    countedDiveTypeIds,
    countedDiveModes,
    advisoryKey,
    advisoryText,
    supersedesRuleId,
    isBuiltIn,
    unreadableScope,
    createdAt,
    updatedAt,
  ];
}
