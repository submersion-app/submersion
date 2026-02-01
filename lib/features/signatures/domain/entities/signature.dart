import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Type of signature (instructor for training courses, buddy for dive verification)
enum SignatureType {
  instructor,
  buddy;

  String get value {
    switch (this) {
      case SignatureType.instructor:
        return 'instructor';
      case SignatureType.buddy:
        return 'buddy';
    }
  }

  static SignatureType? fromString(String? value) {
    if (value == null) return null;
    switch (value) {
      case 'instructor':
        return SignatureType.instructor;
      case 'buddy':
        return SignatureType.buddy;
      default:
        return null;
    }
  }
}

/// Represents a digital signature for a dive
class Signature extends Equatable {
  final String id;
  final String diveId;
  final Uint8List? imageData;
  final String? signerId; // Buddy ID if signer is in system
  final String signerName; // Always populated
  final DateTime signedAt;
  final SignatureType? type; // null treated as instructor for backward compat
  final String? role; // Buddy's role on this dive (for buddy signatures)

  const Signature({
    required this.id,
    required this.diveId,
    this.imageData,
    this.signerId,
    required this.signerName,
    required this.signedAt,
    this.type,
    this.role,
  });

  /// Check if signature has image data
  bool get hasImage => imageData != null;

  /// Check if signature has a linked buddy record
  bool get hasLinkedBuddy => signerId != null;

  /// Check if this is a buddy signature
  bool get isBuddySignature => type == SignatureType.buddy;

  /// Check if this is an instructor signature (or legacy null type)
  bool get isInstructorSignature =>
      type == SignatureType.instructor || type == null;

  Signature copyWith({
    String? id,
    String? diveId,
    Uint8List? imageData,
    String? signerId,
    String? signerName,
    DateTime? signedAt,
    SignatureType? type,
    String? role,
  }) {
    return Signature(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      imageData: imageData ?? this.imageData,
      signerId: signerId ?? this.signerId,
      signerName: signerName ?? this.signerName,
      signedAt: signedAt ?? this.signedAt,
      type: type ?? this.type,
      role: role ?? this.role,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diveId,
    imageData,
    signerId,
    signerName,
    signedAt,
    type,
    role,
  ];
}
