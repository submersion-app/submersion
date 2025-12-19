import 'package:equatable/equatable.dart';

/// Emergency contact information
class EmergencyContact extends Equatable {
  final String? name;
  final String? phone;
  final String? relation;

  const EmergencyContact({
    this.name,
    this.phone,
    this.relation,
  });

  bool get isComplete => name != null && name!.isNotEmpty && phone != null && phone!.isNotEmpty;

  EmergencyContact copyWith({
    String? name,
    String? phone,
    String? relation,
  }) {
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

  const DiverInsurance({
    this.provider,
    this.policyNumber,
    this.expiryDate,
  });

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
  final String medicalNotes;
  final String? bloodType;
  final String? allergies;
  final DiverInsurance insurance;
  final String notes;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Diver({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.photoPath,
    this.emergencyContact = const EmergencyContact(),
    this.medicalNotes = '',
    this.bloodType,
    this.allergies,
    this.insurance = const DiverInsurance(),
    this.notes = '',
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get initials for avatar display
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Check if diver has complete emergency info
  bool get hasEmergencyInfo => emergencyContact.isComplete;

  /// Check if diver has valid insurance
  bool get hasValidInsurance => insurance.isValid;

  /// Check if diver has medical info
  bool get hasMedicalInfo =>
      medicalNotes.isNotEmpty ||
      bloodType != null ||
      allergies != null;

  Diver copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? photoPath,
    EmergencyContact? emergencyContact,
    String? medicalNotes,
    String? bloodType,
    String? allergies,
    DiverInsurance? insurance,
    String? notes,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Diver(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoPath: photoPath ?? this.photoPath,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      medicalNotes: medicalNotes ?? this.medicalNotes,
      bloodType: bloodType ?? this.bloodType,
      allergies: allergies ?? this.allergies,
      insurance: insurance ?? this.insurance,
      notes: notes ?? this.notes,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
        medicalNotes,
        bloodType,
        allergies,
        insurance,
        notes,
        isDefault,
        createdAt,
        updatedAt,
      ];
}
