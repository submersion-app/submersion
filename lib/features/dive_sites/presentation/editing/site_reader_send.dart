import 'package:flutter/material.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/shared_library/shared_site_models.dart';
import 'package:submersion/core/services/shared_library/suggestion_service.dart';
import 'package:submersion/features/dive_sites/data/services/site_edit_save_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_reader_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sitting_save.dart';
import 'package:submersion/features/dive_sites/presentation/utils/suggestion_child_fields.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

const _log = LoggerService('SiteReaderSend');

/// What a reader's Send did (issue #4527, phase 2, plan 5).
enum SiteReaderSent {
  /// A suggestion went to the library's owner.
  sent,

  /// Only the reader's own changes were written.
  savedPrivate,

  /// The reader's own changes were written, but the proposal to the owner
  /// failed: the sitting is left holding only what goes to the owner, so a
  /// Send that tries again never writes the reader's part twice.
  savedPrivateNotSent,

  /// Nothing differed from what is stored.
  nothingChanged,
}

const _sendKey = 'site.readerSend';

/// Holds that [session]'s save is a reader's Send carrying [note] to the
/// owner, as decided before it (plan 5). Kept on the sitting, so it ends
/// with it.
void holdReaderSend(EditSession<DiveSite> session, String note) =>
    session.remember(_sendKey, note);

/// Makes [session]'s save an ordinary save again.
void clearReaderSend(EditSession<DiveSite> session) =>
    session.remember(_sendKey, null);

/// The note [session]'s save sends to the owner, or null when the save is
/// not a reader's Send.
String? readerSendNote(EditSession<DiveSite> session) =>
    session.recall<String>(_sendKey);

/// The cards whose changes are the reader's own.
Set<String> _privateCards(EditSession<DiveSite> session) => {
  for (final id in session.changedCardIds)
    if (siteReaderCardRule(id) == SiteReaderCard.private) id,
};

/// Whether [session] holds a change that goes to the library's owner: a
/// field of a suggested card, or its types or tags.
bool readerSendProposes(EditSession<DiveSite> session) => session.changedCardIds
    .any((id) => siteReaderCardRule(id) == SiteReaderCard.suggested);

/// Asks for the reader's note to the owner, starting from [initial] (the
/// note of a Send that did not go through): the note, or null when the
/// diver cancels, which sends nothing.
Future<String?> askSuggestionNote(
  BuildContext context, {
  String initial = '',
}) => showDialog<String>(
  context: context,
  builder: (_) => _SuggestionNoteDialog(initial: initial),
);

/// The note dialog, owning its field's controller so the closing dialog
/// never draws a disposed one.
class _SuggestionNoteDialog extends StatefulWidget {
  const _SuggestionNoteDialog({required this.initial});

  final String initial;

  @override
  State<_SuggestionNoteDialog> createState() => _SuggestionNoteDialogState();
}

class _SuggestionNoteDialogState extends State<_SuggestionNoteDialog> {
  late final _note = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.sharedLibrary_suggest_title),
      content: TextField(
        controller: _note,
        autofocus: true,
        maxLines: 3,
        minLines: 1,
        decoration: InputDecoration(
          labelText: l10n.sharedLibrary_suggest_note_label,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_note.text),
          child: Text(l10n.sharedLibrary_suggest_send),
        ),
      ],
    );
  }
}

/// A library reader's Send: their own changes (notes, rating, their
/// attachments) written as one History entry, then, when [session] holds
/// any, the changed shared fields, types and tags proposed to the owner
/// with [note]. The library's site itself is never written. A failed
/// write throws and proposes nothing; a failed proposal throws too, unless
/// the reader's own write has committed, which is then reported as
/// [SiteReaderSent.savedPrivateNotSent] with that part taken out of
/// [session]. A sitting holding a change of the
/// library's cards is refused ([RecordSittingRefusal]) with nothing
/// written. Returns what was done, and the site as the write left it.
Future<({SiteReaderSent outcome, DiveSite? saved})> sendReaderSitting(
  EditSession<DiveSite> session, {
  required SiteEditSaveService service,
  required SuggestionService suggestions,
  required String diverId,
  required String note,
}) async {
  // Made while the profile could edit, such a change is neither the
  // reader's own nor theirs to propose: nothing is sent, rather than the
  // change dropped as the sitting ends.
  if (readerSittingHoldsLibraryChange(session)) {
    throw RecordSittingRefusal((l10n) => l10n.diveSites_edit_saveRefused);
  }
  final private = _privateCards(session);
  final written = private.isEmpty
      ? null
      : await saveSiteSitting(
          session,
          service,
          actingDiverId: diverId,
          privateCards: siteReaderPrivateCards,
        );
  if (!readerSendProposes(session)) {
    return (
      outcome: written == null
          ? SiteReaderSent.nothingChanged
          : SiteReaderSent.savedPrivate,
      saved: written?.after,
    );
  }
  final SharedSiteSuggestion? suggestion;
  try {
    suggestion = await suggestions.propose(
      proposed: session.working,
      diverId: diverId,
      note: note,
      childFields: _childFields(session),
    );
  } catch (error, stackTrace) {
    if (written == null) rethrow;
    _log.error(
      'A reader\'s suggestion on ${session.stored.id} failed after their '
      'own changes were saved',
      error: error,
      stackTrace: stackTrace,
    );
    // The reader's own part is written: the sitting keeps only what goes
    // to the owner, for a Send that proposes it again.
    session
      ..rebase(written.after)
      ..dropWrittenChanges(siteReaderPrivateCards);
    return (outcome: SiteReaderSent.savedPrivateNotSent, saved: written.after);
  }
  return (
    outcome: suggestion != null
        ? SiteReaderSent.sent
        : written != null
        ? SiteReaderSent.savedPrivate
        : SiteReaderSent.nothingChanged,
    saved: written?.after,
  );
}

/// The type and tag lists the reader changed, by name, as the owner's
/// inbox reads them.
Map<String, Object?> _childFields(EditSession<DiveSite> session) {
  final loadedTypes = siteTypesList.loaded(session) ?? const [];
  final currentTypes = siteTypesList.current(session) ?? loadedTypes;
  final loadedTags = siteTagsList.loaded(session) ?? const [];
  final currentTags = siteTagsList.current(session) ?? loadedTags;
  return suggestionChildFields(
    originalTypeIds: {for (final t in loadedTypes) t.id},
    selectedTypeIds: {for (final t in currentTypes) t.id},
    typeNames: {
      for (final t in [...loadedTypes, ...currentTypes]) t.id: t.name,
    },
    originalTagIds: {for (final t in loadedTags) t.id},
    selectedTags: [for (final t in currentTags) (id: t.id, name: t.name)],
  );
}
