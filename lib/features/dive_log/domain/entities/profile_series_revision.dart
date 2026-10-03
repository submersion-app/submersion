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

  /// Pass [clearParentSeriesId] to make the copy a root revision; a null
  /// [parentSeriesId] alone keeps the current parent.
  ProfileSeriesRevision copyWith({
    String? seriesId,
    String? diveId,
    String? parentSeriesId,
    bool clearParentSeriesId = false,
    String? rootSeriesId,
    String? contentHash,
    String? revisionKind,
    int? createdAt,
    bool? isActive,
  }) {
    return ProfileSeriesRevision(
      seriesId: seriesId ?? this.seriesId,
      diveId: diveId ?? this.diveId,
      parentSeriesId: clearParentSeriesId
          ? null
          : (parentSeriesId ?? this.parentSeriesId),
      rootSeriesId: rootSeriesId ?? this.rootSeriesId,
      contentHash: contentHash ?? this.contentHash,
      revisionKind: revisionKind ?? this.revisionKind,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

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
