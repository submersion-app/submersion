import 'package:equatable/equatable.dart';

/// A certification agency a diver added (issue #690). Built-in agencies are
/// the CertificationAgency enum and never take this shape.
class CustomCertificationAgency extends Equatable {
  final String id;

  /// The owner. Only the owner edits, shares or deletes the agency.
  final String diverId;
  final String name;

  /// Primary e-card colour (ARGB). The gradient's second colour is derived.
  final int colorArgb;

  /// Visible to every diver profile when true.
  final bool isShared;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomCertificationAgency({
    required this.id,
    required this.diverId,
    required this.name,
    required this.colorArgb,
    this.isShared = false,
    required this.createdAt,
    required this.updatedAt,
  });

  CustomCertificationAgency copyWith({
    String? id,
    String? diverId,
    String? name,
    int? colorArgb,
    bool? isShared,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CustomCertificationAgency(
    id: id ?? this.id,
    diverId: diverId ?? this.diverId,
    name: name ?? this.name,
    colorArgb: colorArgb ?? this.colorArgb,
    isShared: isShared ?? this.isShared,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    id,
    diverId,
    name,
    colorArgb,
    isShared,
    createdAt,
    updatedAt,
  ];
}
