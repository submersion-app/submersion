import 'package:equatable/equatable.dart';

/// One selectable profile history entry.
///
/// History is metadata-only: the profile samples remain stored once in
/// `dive_profile_series`, and this row links revisions by parent id.
class ProfileSeriesRevision extends Equatable {
  const ProfileSeriesRevision({
    required this.seriesId,
    required this.diveId,
    required this.parentSeriesId,
    required this.rootSeriesId,
    required this.contentHash,
    required this.revisionKind,
    required this.createdAt,
    required this.isActive,
  });

  final String seriesId;
  final String diveId;
  final String? parentSeriesId;
  final String rootSeriesId;
  final String contentHash;
  final String revisionKind;
  final int createdAt;
  final bool isActive;

  @override
  List<Object?> get props => [
    seriesId,
    diveId,
    parentSeriesId,
    rootSeriesId,
    contentHash,
    revisionKind,
    createdAt,
    isActive,
  ];
}
