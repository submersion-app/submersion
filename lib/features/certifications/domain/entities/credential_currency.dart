import 'package:equatable/equatable.dart';

import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';

/// Deliberately not ServiceClockSeverity's names: gear "overdue" chips sit
/// on the same strip and in the same translation files.
enum CurrencySeverity { current, dueSoon, lapsed }

/// What a clock counts from, so every surface can explain itself.
enum CurrencyAnchorOrigin {
  cardExpiry,
  cardIssue,
  ledgerEvent,
  lastDive,
  lastQualifyingDive,

  /// An activity rule matches the card but no counted dive and no logged
  /// refresher has started its clock. The status stays current and never
  /// warns; it exists so the detail page keeps the row and its actions.
  noCountedDive,
}

/// One rule evaluated against one certification.
class CredentialCurrency extends Equatable {
  final Certification certification;
  final CurrencyRule rule;
  final CurrencySeverity severity;

  /// The calendar day the clock counts from.
  final DateTime anchor;
  final CurrencyAnchorOrigin origin;

  /// The calendar day the rule lapses.
  final DateTime dueDate;
  final int lapseDays;
  final int leadDays;
  final bool muted;

  /// The event type when [origin] is [CurrencyAnchorOrigin.ledgerEvent].
  final CurrencyEventType? anchorEventType;

  const CredentialCurrency({
    required this.certification,
    required this.rule,
    required this.severity,
    required this.anchor,
    required this.origin,
    required this.dueDate,
    required this.lapseDays,
    required this.leadDays,
    this.muted = false,
    this.anchorEventType,
  });

  CredentialCurrency copyWith({
    Certification? certification,
    CurrencyRule? rule,
    CurrencySeverity? severity,
    DateTime? anchor,
    CurrencyAnchorOrigin? origin,
    DateTime? dueDate,
    int? lapseDays,
    int? leadDays,
    bool? muted,
    CurrencyEventType? anchorEventType,
  }) => CredentialCurrency(
    certification: certification ?? this.certification,
    rule: rule ?? this.rule,
    severity: severity ?? this.severity,
    anchor: anchor ?? this.anchor,
    origin: origin ?? this.origin,
    dueDate: dueDate ?? this.dueDate,
    lapseDays: lapseDays ?? this.lapseDays,
    leadDays: leadDays ?? this.leadDays,
    muted: muted ?? this.muted,
    anchorEventType: anchorEventType ?? this.anchorEventType,
  );

  /// Lapsed or due soon, and not muted: what the chip and the list scope
  /// count.
  bool get needsAttention => !muted && severity != CurrencySeverity.current;

  /// Renders through the diver's hide: a lapse on a date the diver entered
  /// (a card expiry or a logged event). An inferred lapse stays hideable.
  bool get hardened =>
      !muted &&
      severity == CurrencySeverity.lapsed &&
      (origin == CurrencyAnchorOrigin.cardExpiry ||
          origin == CurrencyAnchorOrigin.ledgerEvent);

  @override
  List<Object?> get props => [
    certification.id,
    rule.id,
    severity,
    anchor,
    origin,
    dueDate,
    lapseDays,
    leadDays,
    muted,
    anchorEventType,
  ];
}

/// Statuses sharing a rule, an anchor and an interval, shown as one row.
/// OW, AOW and Rescue from one agency share the refresher rule and the last
/// dive, so the diver sees one row, not three.
class CurrencyGroup extends Equatable {
  /// Most advanced first; never empty.
  final List<CredentialCurrency> members;

  const CurrencyGroup(this.members);

  CurrencyGroup copyWith({List<CredentialCurrency>? members}) =>
      CurrencyGroup(members ?? this.members);

  CredentialCurrency get representative => members.first;
  CurrencySeverity get severity => representative.severity;
  bool get needsAttention => representative.needsAttention;
  bool get hardened => representative.hardened;
  bool get muted => representative.muted;
  Set<String> get certificationIds => {
    for (final m in members) m.certification.id,
  };

  @override
  List<Object?> get props => [members];
}
