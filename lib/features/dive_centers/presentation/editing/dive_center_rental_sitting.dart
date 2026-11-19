import 'package:submersion/features/dive_centers/data/repositories/dive_center_gear_note_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_card_ids.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/rental_gear_note_sheet.dart'
    show RentalNoteEdit;
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

/// A dive centre's rental gear notes held in its page's sitting (issue
/// #4527, phase 3): added, edited and removed there, written at Save. Only
/// the difference is written, so a note added meanwhile (from a dive's
/// Details card, or another device) is left as it is.
final diveCenterRentalList = SittingList<DiveCenter, DiveCenterGearNote>(
  key: 'diveCenter.rentalNotes',
  cardId: DiveCenterCardId.rentalGear.name,
  read: (c) => DiveCenterGearNoteRepository().getForCenter(c.id),
  write: (c, loaded, current) async {
    final repository = DiveCenterGearNoteRepository();
    final loadedById = {for (final n in loaded) n.id: n};
    final currentIds = {for (final n in current) n.id};
    var changed = false;
    for (final note in current) {
      final before = loadedById[note.id];
      if (before == null) {
        await repository.create(note);
        changed = true;
      } else if (note != before) {
        await repository.update(note);
        changed = true;
      }
    }
    for (final note in loaded) {
      if (currentIds.contains(note.id)) continue;
      await repository.delete(note.id);
      changed = true;
    }
    return changed;
  },
);

/// [current] with [edit] made: a removal takes the note out, an edit
/// replaces it where it stands, so a note saved unchanged leaves the list as
/// it was, and a new note goes at the end.
List<DiveCenterGearNote> rentalNotesAfter(
  List<DiveCenterGearNote> current,
  RentalNoteEdit edit,
) {
  final known = current.any((n) => n.id == edit.note.id);
  return [
    for (final n in current)
      if (n.id != edit.note.id) n else if (!edit.removed) edit.note,
    if (!known && !edit.removed) edit.note,
  ];
}
