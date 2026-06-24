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

  const DiverInsurance({this.provider, this.policyNumber, this.expiryDate});

  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final thirtyDaysFromNow = DateTime.now().add(const Duration(days: 30));
    return expiryDate!.isBefore(thirtyDaysFromNow) && !isExpired;
  }

  bool get isValid => provider != null && provider!.isNotEmpty && !isExpired;

  DiverInsurance copyWith({
    String? provider,
    String? policyNumber,
    DateTime? expiryDate,
  }) {
    return DiverInsurance(
      provider: provider ?? this.provider,
      policyNumber: policyNumber ?? this.policyNumber,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }

  @override
  List<Object?> get props => [provider, policyNumber, expiryDate];
}

/// Diver profile entity
class Diver extends Equatable {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? photoPath;
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
