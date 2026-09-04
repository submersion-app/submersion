import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Emergency contact information
class EmergencyContact extends Equatable {
  final String? name;
  final String? phone;
  final String? relation;

  const EmergencyContact({this.name, this.phone, this.relation});

  bool get isComplete =>
      name != null && name!.isNotEmpty && phone != null && phone!.isNotEmpty;

  EmergencyContact copyWith({String? name, String? phone, String? relation}) {
    return EmergencyContact(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relation: relation ?? this.relation,
    );
  }

  @override
  List<Object?> get props => [name, phone, relation];
}

/// Diver insurance information
class DiverInsurance extends Equatable {
  final String? provider;
  final String? policyNumber;
  final DateTime? expiryDate;

  /// The insurer's 24-hour dive emergency assistance line. This is the number
  /// an insured diver is meant to call first: their own assistance provider
  /// authorises the evacuation and coordinates the chamber referral, which is
  /// the role the emergency card otherwise attributes to the regional diver
  /// hotline. Exposed as [assistanceLine].
  final String? emergencyPhone;

  /// The insurer's general or office line, exposed as [officeLine]. For most
  /// providers this answers during business hours only, so it is never what
  /// the emergency card leads with: an unanswered number at 2am is worse
  /// than the regional hotline, which does answer.
  final String? phone;

  const DiverInsurance({
    this.provider,
    this.policyNumber,
    this.expiryDate,
    this.emergencyPhone,
    this.phone,
  });

  /// Trims a stored value and reports a blank one as absent. An emptied text
  /// field round-trips through the database as `''` on some paths: a blank
  /// number would fail to dial silently at the very worst moment, and a blank
  /// policy number would print an empty "Policy" line on the emergency card.
  ///
  /// Every getter below goes through this, so "is it there?" gets one answer
  /// across the card, the export, and the persistence gates.
  static String? _presentOrNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// The 24-hour assistance line, ready to dial, or null if not recorded.
  /// This is the only insurer number the emergency card will lead with.
  String? get assistanceLine => _presentOrNull(emergencyPhone);

  /// The office line, ready to dial, or null if not recorded.
  String? get officeLine => _presentOrNull(phone);

  /// The insurer's name, ready to display, or null if not recorded.
  String? get providerLabel => _presentOrNull(provider);

  /// The policy number, ready to display, or null if not recorded.
  String? get policyLabel => _presentOrNull(policyNumber);

  /// An insurer number to dial at all, preferring the assistance line. Used to
  /// decide whether the insurance block has anything to show; deciding what
  /// the card *leads* with is [assistanceLine]'s job, because a number that
  /// only answers in business hours must not be presented as a first call.
  String? get callNumber => assistanceLine ?? officeLine;

  /// Whether the diver recorded any insurer number at all.
  bool get hasCallNumber => callNumber != null;

  /// Whether the diver recorded anything at all under insurance.
  ///
  /// Persistence and export must key off this rather than [provider]: a policy
  /// number or an assistance line can be saved without ever naming the
  /// insurer, and gating on the name alone silently drops the rest.
  bool get hasAnyDetail =>
      providerLabel != null ||
      policyLabel != null ||
      expiryDate != null ||
      hasCallNumber;

  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final thirtyDaysFromNow = DateTime.now().add(const Duration(days: 30));
    return expiryDate!.isBefore(thirtyDaysFromNow) && !isExpired;
  }

  /// Goes through [providerLabel] so a whitespace-only provider is "not
  /// recorded" here too. Every presence question about insurance has to give
  /// the same answer, or the dashboard calls a policy valid that the emergency
  /// card refuses to show.
  bool get isValid => providerLabel != null && !isExpired;

  DiverInsurance copyWith({
    String? provider,
    String? policyNumber,
    DateTime? expiryDate,
    String? emergencyPhone,
    String? phone,
  }) {
    return DiverInsurance(
      provider: provider ?? this.provider,
      policyNumber: policyNumber ?? this.policyNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      phone: phone ?? this.phone,
    );
  }

  @override
  List<Object?> get props => [
    provider,
    policyNumber,
    expiryDate,
    emergencyPhone,
    phone,
  ];
}

/// Diver profile entity
class Diver extends Equatable {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? photoPath;

  /// Profile photo: a 512x512 square JPEG. Supersedes [photoPath].
  final Uint8List? photo;
  final EmergencyContact emergencyContact;
  final EmergencyContact emergencyContact2;
  final String medicalNotes;
  final String? bloodType;
  final String? allergies;
  final String? medications;
  final DateTime? medicalClearanceExpiryDate;
  final DiverInsurance insurance;
  final String notes;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? priorDiveCount;
  final int? priorDiveTimeSeconds;
  final DateTime? divingSince;

  const Diver({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.photoPath,
    this.photo,
    this.emergencyContact = const EmergencyContact(),
    this.emergencyContact2 = const EmergencyContact(),
    this.medicalNotes = '',
    this.bloodType,
    this.allergies,
    this.medications,
    this.medicalClearanceExpiryDate,
    this.insurance = const DiverInsurance(),
    this.notes = '',
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
    this.priorDiveCount,
    this.priorDiveTimeSeconds,
    this.divingSince,
  });

  /// Get initials for avatar display
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Check if diver has complete emergency info (at least one contact)
  bool get hasEmergencyInfo =>
      emergencyContact.isComplete || emergencyContact2.isComplete;

  /// Check if diver has valid insurance
  bool get hasValidInsurance => insurance.isValid;

  /// Check if diver has medical info
  bool get hasMedicalInfo =>
      medicalNotes.isNotEmpty ||
      bloodType != null ||
      allergies != null ||
      medications != null;

  /// Check if medical clearance is expired
  bool get isMedicalClearanceExpired {
    if (medicalClearanceExpiryDate == null) return false;
    return DateTime.now().isAfter(medicalClearanceExpiryDate!);
  }

  /// Check if medical clearance is expiring within 30 days
  bool get isMedicalClearanceExpiringSoon {
    if (medicalClearanceExpiryDate == null) return false;
    final thirtyDaysFromNow = DateTime.now().add(const Duration(days: 30));
    return medicalClearanceExpiryDate!.isBefore(thirtyDaysFromNow) &&
        !isMedicalClearanceExpired;
  }

  /// Check if medical clearance is valid (set and not expired)
  bool get hasMedicalClearance =>
      medicalClearanceExpiryDate != null && !isMedicalClearanceExpired;

  /// Sentinel marking a `copyWith` parameter as "not provided". Lets callers
  /// distinguish omitting a nullable field (keep the current value) from
  /// passing `null` (clear it) — plain `value ?? this.value` cannot express a
  /// clear. Nullable fields take `Object?` params defaulting to [_unset];
  /// [_resolve] routes them to keep / clear / set accordingly.
  static const Object _unset = Object();

  /// Resolves a sentinel-defaulted `copyWith` parameter: [current] when the
  /// field was omitted ([value] is [_unset]), otherwise the new [value].
  /// Because `Object?` params give up compile-time type checking, this asserts
  /// the runtime type in debug builds (the `as T` cast still guards release).
  static T _resolve<T>(Object? value, T current, String field) {
    if (identical(value, _unset)) return current;
    assert(
      value is T,
      'Diver.copyWith($field) expected $T or omission, got ${value.runtimeType}',
    );
    return value as T;
  }

  Diver copyWith({
    String? id,
    String? name,
    Object? email = _unset,
    Object? phone = _unset,
    Object? photoPath = _unset,
    Object? photo = _unset,
    EmergencyContact? emergencyContact,
    EmergencyContact? emergencyContact2,
    String? medicalNotes,
    Object? bloodType = _unset,
    Object? allergies = _unset,
    Object? medications = _unset,
    Object? medicalClearanceExpiryDate = _unset,
    DiverInsurance? insurance,
    String? notes,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? priorDiveCount = _unset,
    Object? priorDiveTimeSeconds = _unset,
    Object? divingSince = _unset,
  }) {
    return Diver(
      id: id ?? this.id,
      name: name ?? this.name,
      email: _resolve<String?>(email, this.email, 'email'),
      phone: _resolve<String?>(phone, this.phone, 'phone'),
      photoPath: _resolve<String?>(photoPath, this.photoPath, 'photoPath'),
      photo: _resolve<Uint8List?>(photo, this.photo, 'photo'),
      emergencyContact: emergencyContact ?? this.emergencyContact,
      emergencyContact2: emergencyContact2 ?? this.emergencyContact2,
      medicalNotes: medicalNotes ?? this.medicalNotes,
      bloodType: _resolve<String?>(bloodType, this.bloodType, 'bloodType'),
      allergies: _resolve<String?>(allergies, this.allergies, 'allergies'),
      medications: _resolve<String?>(
        medications,
        this.medications,
        'medications',
      ),
      medicalClearanceExpiryDate: _resolve<DateTime?>(
        medicalClearanceExpiryDate,
        this.medicalClearanceExpiryDate,
        'medicalClearanceExpiryDate',
      ),
      insurance: insurance ?? this.insurance,
      notes: notes ?? this.notes,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      priorDiveCount: _resolve<int?>(
        priorDiveCount,
        this.priorDiveCount,
        'priorDiveCount',
      ),
      priorDiveTimeSeconds: _resolve<int?>(
        priorDiveTimeSeconds,
        this.priorDiveTimeSeconds,
        'priorDiveTimeSeconds',
      ),
      divingSince: _resolve<DateTime?>(
        divingSince,
        this.divingSince,
        'divingSince',
      ),
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    phone,
    photoPath,
    photo,
    emergencyContact,
    emergencyContact2,
    medicalNotes,
    bloodType,
    allergies,
    medications,
    medicalClearanceExpiryDate,
    insurance,
    notes,
    isDefault,
    createdAt,
    updatedAt,
    priorDiveCount,
    priorDiveTimeSeconds,
    divingSince,
  ];
}
