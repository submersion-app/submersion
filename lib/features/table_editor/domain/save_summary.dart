import 'package:flutter/foundation.dart';

import 'package:submersion/features/table_editor/domain/paste_planner.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// What Save all is about to do (#3422), shown before it does it. The
/// overwrite count matters most: filling blanks is low risk, replacing
/// values is not.
@immutable
class SaveSummary {
  /// Drafts that will be written.
  final int changed;

  /// Flagged drafts, left out of the save.
  final int needsAttention;

  /// Written drafts that replace a non-empty value.
  final int overwrites;

  /// The part of [needsAttention] that changed elsewhere since drafting.
  final int changedElsewhere;

  final List<PasteSkip> skipped;
  final PasteMatching? matching;
  final List<String> notes;

  const SaveSummary({
    required this.changed,
    required this.needsAttention,
    required this.overwrites,
    required this.changedElsewhere,
    this.skipped = const [],
    this.matching,
    this.notes = const [],
  });

  static SaveSummary from(
    List<TableDraft> drafts, {
    PastePlan<EntityField>? lastPaste,
    List<String> notes = const [],
  }) {
    final saveable = drafts.where((d) => d.isSaveable);
    return SaveSummary(
      changed: saveable.length,
      needsAttention: drafts.length - saveable.length,
      overwrites: saveable.where((d) => d.overwrites).length,
      changedElsewhere: drafts
          .where((d) => d.flag == TableDraftFlag.changedElsewhere)
          .length,
      skipped: lastPaste?.skipped ?? const [],
      matching: lastPaste?.matching,
      notes: notes,
    );
  }
}
