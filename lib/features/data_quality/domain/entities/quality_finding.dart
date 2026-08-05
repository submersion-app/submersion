import 'package:uuid/uuid.dart';

enum QualityCategory {
  time,
  profile,
  temperature,
  pressure,
  gas,
  tank,
  source,
  duplicate,
}

enum QualitySeverity { info, warning, critical }

enum QualityStatus { open, dismissed, resolved }

/// Fixed namespace for deterministic finding ids (UUIDv5). Never change.
const String kQualityFindingNamespace = '7f9b2c9e-1d34-4b6a-9c1e-2a5d8e4f6b01';

/// Deterministic finding id: two devices scanning the same dive with the
/// same detector produce the same row id and converge under sync.
String qualityFindingId({
  required String diveId,
  required String detectorId,
  String discriminator = '',
}) => const Uuid().v5(
  kQualityFindingNamespace,
  '$diveId|$detectorId|$discriminator',
);

/// Identity for a cross-dive (pair) finding: the lexically smaller dive id
/// anchors the row so either member's scan produces the identical row.
({String diveId, String relatedDiveId, String id}) qualityPairIdentity({
  required String detectorId,
  required String a,
  required String b,
  String discriminator = '',
}) {
  final lo = a.compareTo(b) <= 0 ? a : b;
  final hi = a.compareTo(b) <= 0 ? b : a;
  return (
    diveId: lo,
    relatedDiveId: hi,
    id: qualityFindingId(
      diveId: lo,
      detectorId: detectorId,
      discriminator: discriminator.isEmpty ? hi : '$hi|$discriminator',
    ),
  );
}

class QualityFinding {
  const QualityFinding({
    required this.id,
    required this.diveId,
    this.relatedDiveId,
    this.computerId,
    required this.detectorId,
    required this.detectorVersion,
    required this.category,
    required this.severity,
    required this.status,
    this.params = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String diveId;
  final String? relatedDiveId;
  final String? computerId;
  final String detectorId;
  final int detectorVersion;
  final QualityCategory category;
  final QualitySeverity severity;
  final QualityStatus status;

  /// Numeric/boolean facts only; the UI renders localized text from these.
  final Map<String, Object?> params;
  final DateTime createdAt;
  final DateTime updatedAt;

  QualityFinding copyWith({
    String? id,
    String? diveId,
    String? relatedDiveId,
    String? computerId,
    String? detectorId,
    int? detectorVersion,
    QualityCategory? category,
    QualitySeverity? severity,
    QualityStatus? status,
    Map<String, Object?>? params,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => QualityFinding(
    id: id ?? this.id,
    diveId: diveId ?? this.diveId,
    relatedDiveId: relatedDiveId ?? this.relatedDiveId,
    computerId: computerId ?? this.computerId,
    detectorId: detectorId ?? this.detectorId,
    detectorVersion: detectorVersion ?? this.detectorVersion,
    category: category ?? this.category,
    severity: severity ?? this.severity,
    status: status ?? this.status,
    params: params ?? this.params,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
