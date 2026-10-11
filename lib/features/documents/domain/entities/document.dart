import 'package:equatable/equatable.dart';

/// What a document is (issue #2613). Only [insurance], [medicalClearance]
/// and [certificationCard] carry behaviour; the rest set the icon and the
/// default title.
enum DocumentType {
  insurance,
  medicalClearance,
  certificationCard,
  permit,
  booking,
  receipt,
  manual,
  map,
  other;

  String get storage => name;

  static DocumentType fromStorage(String? value) => DocumentType.values
      .firstWhere((t) => t.name == value, orElse: () => DocumentType.other);
}

/// The kind of record a document is filed under. [personal] means no owner
/// link: the document belongs to the diver.
enum DocumentOwnerKind {
  personal,
  dive,
  site,
  trip,
  equipment,
  course,
  certification,
  buddy,
  diveCenter;

  String get storage => name;

  static DocumentOwnerKind fromStorage(String? value) =>
      DocumentOwnerKind.values.firstWhere(
        (k) => k.name == value,
        orElse: () => DocumentOwnerKind.personal,
      );
}

class DocumentOwner extends Equatable {
  final DocumentOwnerKind kind;

  /// Null exactly when [kind] is [DocumentOwnerKind.personal].
  final String? id;

  const DocumentOwner.personal() : kind = DocumentOwnerKind.personal, id = null;

  const DocumentOwner(this.kind, String this.id)
    : assert(kind != DocumentOwnerKind.personal);

  bool get isPersonal => kind == DocumentOwnerKind.personal;

  @override
  List<Object?> get props => [kind, id];
}

const Object _unset = Object();

class Document extends Equatable {
  /// Reminder lead used when [reminderLeadDays] is null.
  static const int defaultReminderLeadDays = 30;

  final String id;

  /// The diver whose library the document belongs to.
  final String diverId;
  final DocumentOwner owner;
  final DocumentType type;

  /// Empty renders as the type's localized name.
  final String title;
  final String? issuer;
  final String? referenceNumber;
  final DateTime? issueDate;
  final DateTime? expiryDate;

  /// Null means [defaultReminderLeadDays]; 0 means no lead reminder.
  final int? reminderLeadDays;

  /// Insurance only: the 24-hour assistance line and the office line.
  final String? emergencyPhone;
  final String? phone;

  /// Insurance only: the policy the emergency card and home chip use.
  final bool isPrimary;

  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Document({
    required this.id,
    required this.diverId,
    required this.owner,
    required this.type,
    this.title = '',
    this.issuer,
    this.referenceNumber,
    this.issueDate,
    this.expiryDate,
    this.reminderLeadDays,
    this.emergencyPhone,
    this.phone,
    this.isPrimary = false,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  int get effectiveReminderLeadDays =>
      reminderLeadDays ?? defaultReminderLeadDays;

  /// Whether this document takes part in chips and notifications. A card
  /// document's expiry lives on its certification (currency warnings).
  bool get remindsOnExpiry =>
      type != DocumentType.certificationCard && expiryDate != null;

  Document copyWith({
    String? id,
    String? diverId,
    DocumentOwner? owner,
    DocumentType? type,
    String? title,
    Object? issuer = _unset,
    Object? referenceNumber = _unset,
    Object? issueDate = _unset,
    Object? expiryDate = _unset,
    Object? reminderLeadDays = _unset,
    Object? emergencyPhone = _unset,
    Object? phone = _unset,
    bool? isPrimary,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    T? pick<T>(Object? value, T? current) =>
        identical(value, _unset) ? current : value as T?;
    return Document(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      owner: owner ?? this.owner,
      type: type ?? this.type,
      title: title ?? this.title,
      issuer: pick<String>(issuer, this.issuer),
      referenceNumber: pick<String>(referenceNumber, this.referenceNumber),
      issueDate: pick<DateTime>(issueDate, this.issueDate),
      expiryDate: pick<DateTime>(expiryDate, this.expiryDate),
      reminderLeadDays: pick<int>(reminderLeadDays, this.reminderLeadDays),
      emergencyPhone: pick<String>(emergencyPhone, this.emergencyPhone),
      phone: pick<String>(phone, this.phone),
      isPrimary: isPrimary ?? this.isPrimary,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    owner,
    type,
    title,
    issuer,
    referenceNumber,
    issueDate,
    expiryDate,
    reminderLeadDays,
    emergencyPhone,
    phone,
    isPrimary,
    notes,
    createdAt,
    updatedAt,
  ];
}
