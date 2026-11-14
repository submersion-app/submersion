import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_notes_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tags_card_editor.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';

/// The dive's notes, edited on the Notes card.
final diveNotesField = EditField<Dive, String>(
  id: 'notes',
  cardId: DiveDetailSectionId.notes.name,
  read: (dive) => dive.notes,
  write: (dive, notes) => dive.copyWith(notes: notes),
);

/// The dive's tags, edited on the Tags card. Their order carries no
/// meaning, so the same tags in another order are not a change.
final diveTagsField = EditField<Dive, List<Tag>>(
  id: 'tags',
  cardId: DiveDetailSectionId.tags.name,
  read: (dive) => dive.tags,
  write: (dive, tags) => dive.copyWith(tags: tags),
  equals: _sameTagIds,
);

bool _sameTagIds(List<Tag> a, List<Tag> b) {
  final ids = {for (final tag in a) tag.id};
  final others = {for (final tag in b) tag.id};
  return ids.length == others.length && ids.containsAll(others);
}

/// The cards of the dive page that can be edited in place, by section. A
/// card's id is its section's `name`, so the section list, the Add strip
/// and the change log all speak of it the same way.
///
/// Sections not listed here have no in-place editor yet (issue #4527).
final Map<DiveDetailSectionId, EditCard<Dive>> diveEditCards = {
  DiveDetailSectionId.notes: EditCard<Dive>(
    id: DiveDetailSectionId.notes.name,
    title: (context) => context.l10n.diveLog_detail_section_notes,
    // The Notes card is always on the page: empty, it says there are none.
    isEmpty: (_) => false,
    editorBuilder: (context, session) => DiveNotesCardEditor(session: session),
  ),
  DiveDetailSectionId.tags: EditCard<Dive>(
    id: DiveDetailSectionId.tags.name,
    title: (context) => context.l10n.diveLog_detail_section_tags,
    isEmpty: (dive) => dive.tags.isEmpty,
    editorBuilder: (context, session) => DiveTagsCardEditor(session: session),
  ),
};
