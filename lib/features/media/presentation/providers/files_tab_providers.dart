import 'package:equatable/equatable.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/value_objects/extracted_file.dart';
import 'package:submersion/features/media/domain/value_objects/matched_selection.dart';

/// State for the Files tab in the photo picker.
///
/// Holds the picked + EXIF-extracted files, the matcher's assignment of
/// each to a dive (or unmatched), the auto-match toggle preference, and
/// extraction progress for the UI's progress indicator.
class FilesTabState extends Equatable {
  final List<ExtractedFile> files;
  final bool autoMatchByDate;
  final bool isExtracting;
  final int extractedCount;
  final int totalToExtract;
  final MatchedSelection match;

  const FilesTabState({
    required this.files,
    required this.autoMatchByDate,
    required this.isExtracting,
    required this.extractedCount,
    required this.totalToExtract,
    required this.match,
  });

  factory FilesTabState.initial() => FilesTabState(
    files: const [],
    autoMatchByDate: true,
    isExtracting: false,
    extractedCount: 0,
    totalToExtract: 0,
    match: MatchedSelection.empty(),
  );

  FilesTabState copyWith({
    List<ExtractedFile>? files,
    bool? autoMatchByDate,
    bool? isExtracting,
    int? extractedCount,
    int? totalToExtract,
    MatchedSelection? match,
  }) => FilesTabState(
    files: files ?? this.files,
    autoMatchByDate: autoMatchByDate ?? this.autoMatchByDate,
    isExtracting: isExtracting ?? this.isExtracting,
    extractedCount: extractedCount ?? this.extractedCount,
    totalToExtract: totalToExtract ?? this.totalToExtract,
    match: match ?? this.match,
  );

  @override
  List<Object?> get props => [
    files,
    autoMatchByDate,
    isExtracting,
    extractedCount,
    totalToExtract,
    match,
  ];
}

/// Notifier for the Files tab.
///
/// Phase 2 actions: [toggleAutoMatch], [clear], [setFiles],
/// [setExtractionProgress], [removeFile]. The commit action (insert
/// MediaItem rows + undo) lands in Task 13.
class FilesTabNotifier extends StateNotifier<FilesTabState> {
  FilesTabNotifier() : super(FilesTabState.initial());

  void toggleAutoMatch() {
    state = state.copyWith(autoMatchByDate: !state.autoMatchByDate);
  }

  void clear() {
    state = FilesTabState.initial();
  }

  void setFiles(List<ExtractedFile> files, {required MatchedSelection match}) {
    state = state.copyWith(files: files, match: match);
  }

  void setExtractionProgress({required int done, required int total}) {
    state = state.copyWith(
      isExtracting: total > 0 && done < total,
      extractedCount: done,
      totalToExtract: total,
    );
  }

  void removeFile(String sourcePath) {
    final remaining = state.files
        .where((f) => f.sourcePath != sourcePath)
        .toList();
    state = state.copyWith(files: remaining);
  }
}

final filesTabNotifierProvider =
    StateNotifierProvider<FilesTabNotifier, FilesTabState>(
      (ref) => FilesTabNotifier(),
    );
