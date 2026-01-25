import 'package:equatable/equatable.dart';

/// Represents an instructor signature for a training dive
class Signature extends Equatable {
  final String id;
  final String diveId;
  final String filePath;
  final String? signerId; // Buddy ID if instructor is in system
  final String signerName; // Always populated
  final DateTime signedAt;

  const Signature({
    required this.id,
    required this.diveId,
    required this.filePath,
    this.signerId,
    required this.signerName,
    required this.signedAt,
  });

  /// Check if signature has a linked buddy record
  bool get hasLinkedBuddy => signerId != null;

  Signature copyWith({
    String? id,
    String? diveId,
    String? filePath,
    String? signerId,
    String? signerName,
    DateTime? signedAt,
  }) {
    return Signature(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      filePath: filePath ?? this.filePath,
      signerId: signerId ?? this.signerId,
      signerName: signerName ?? this.signerName,
      signedAt: signedAt ?? this.signedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diveId,
    filePath,
    signerId,
    signerName,
    signedAt,
  ];
}
