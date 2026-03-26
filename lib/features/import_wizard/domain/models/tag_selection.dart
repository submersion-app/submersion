import 'package:equatable/equatable.dart';

/// A tag selected by the user during import review.
///
/// Can represent either an existing tag (with [existingTagId]) or a new tag
/// to be created (when [existingTagId] is null).
class TagSelection extends Equatable {
  /// Non-null when selecting an existing tag from the database.
  final String? existingTagId;

  /// Display name for both new and existing tags.
  final String name;

  const TagSelection({this.existingTagId, required this.name});

  /// True if this represents a new tag to be created.
  bool get isNew => existingTagId == null;

  @override
  List<Object?> get props => [existingTagId, name];
}
