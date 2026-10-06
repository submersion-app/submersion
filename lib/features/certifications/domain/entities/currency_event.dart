import 'package:equatable/equatable.dart';

/// What the diver did to reset a currency clock.
enum CurrencyEventType {
  refresher,
  renewal,
  revalidation,
  skillsUpdate,
  other;

  static CurrencyEventType parse(String raw) => CurrencyEventType.values
      .firstWhere((v) => v.name == raw, orElse: () => CurrencyEventType.other);
}

/// One entry in a certification's currency history: the ledger twin of a
/// gear service record.
class CurrencyEvent extends Equatable {
  final String id;
  final String certificationId;

  /// Null when the diver logged a refresher without tying it to a rule.
  final String? ruleId;

  final CurrencyEventType eventType;
  final DateTime eventDate;
  final String? provider;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CurrencyEvent({
    required this.id,
    required this.certificationId,
    this.ruleId,
    required this.eventType,
    required this.eventDate,
    this.provider,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  CurrencyEvent copyWith({
    String? id,
    String? certificationId,
    String? ruleId,
    CurrencyEventType? eventType,
    DateTime? eventDate,
    String? provider,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CurrencyEvent(
    id: id ?? this.id,
    certificationId: certificationId ?? this.certificationId,
    ruleId: ruleId ?? this.ruleId,
    eventType: eventType ?? this.eventType,
    eventDate: eventDate ?? this.eventDate,
    provider: provider ?? this.provider,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    id,
    certificationId,
    ruleId,
    eventType,
    eventDate,
    provider,
    notes,
    createdAt,
    updatedAt,
  ];
}
