import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The files still linked to a gear item by the older attachment card,
/// unlinked in its page's sitting (issue #4527, phase 3, plan 6) and written
/// at Save, as the Photos card's unlinks are: a row nothing else needs
/// leaves the library, its remote copy's delete held for the commit.

const String _key = 'equipment.legacyFiles';
const String _writersNote = 'equipment.legacyFiles.writers';
const String _unlinkedNote = 'equipment.legacyFiles.unlinked';
const String _afterNote = 'equipment.legacyFiles.after';

/// Keeps the writers the legacy files' held unlink uses: the page's, which
/// outlive it.
void holdLegacyFiles(
  EditSession<EquipmentItem> session,
  SittingMediaWriters writers,
) => session.remember(_writersNote, writers);

/// The legacy files the sitting has unlinked.
Set<String> heldLegacyFileUnlinks(EditSession<EquipmentItem> session) =>
    (session.isDisposed ? null : session.recall<Set<String>>(_unlinkedNote)) ??
    const {};

/// Unlinks the legacy file [id] in the sitting, written at Save. Does
/// nothing before [holdLegacyFiles], or on a sitting being written or
/// ended.
void unlinkLegacyFileInSitting(EditSession<EquipmentItem> session, String id) {
  if (session.isDisposed || session.isFrozen) return;
  final writers = session.recall<SittingMediaWriters>(_writersNote);
  if (writers == null) return;
  final ids = {...heldLegacyFileUnlinks(session), id};
  session
    ..remember(_unlinkedNote, ids)
    ..holdChange(
      _key,
      cardId: GearItemCardId.legacyFiles.name,
      write: () async {
        session.remember(_afterNote, null);
        await writers.unlink(ids.toList());
        session.remember(_afterNote, writers.drainDeletes);
      },
    );
}

/// [stored] as the sitting has it: the files it unlinked gone.
List<MediaItem> legacyFilesInSitting(
  EditSession<EquipmentItem> session,
  List<MediaItem> stored,
) {
  final unlinked = heldLegacyFileUnlinks(session);
  if (unlinked.isEmpty) return stored;
  return [
    for (final m in stored)
      if (!unlinked.contains(m.id)) m,
  ];
}

/// What must happen once the sitting's write has committed: the remote
/// deletes the legacy files' unlinks held. Empty before a write went
/// through.
List<Future<void> Function()> legacyFilesAfterCommit(
  EditSession<EquipmentItem> session,
) => [?session.recall<Future<void> Function()>(_afterNote)];
