import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_card_editors.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_card_ids.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_edit_fields.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_currency_section.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';

/// The certification page's cards that can be edited in place (issue
/// #4527, phase 3), by card id, in page order.
final Map<CertificationCardId, EditCard<Certification>> certificationEditCards =
    {
      CertificationCardId.details: EditCard<Certification>(
        id: CertificationCardId.details.name,
        title: (context) =>
            CertificationCardId.details.localizedDisplayName(context.l10n),
        isEmpty: (_) => false,
        // A title or a level, as the form's validator has it.
        isValid: (session) => certificationHasTitleOrLevel(session.working),
        editorBuilder: (context, session) =>
            CertificationDetailsCardEditor(session: session),
      ),
      CertificationCardId.dates: EditCard<Certification>(
        id: CertificationCardId.dates.name,
        title: (context) =>
            CertificationCardId.dates.localizedDisplayName(context.l10n),
        // Always shown: with no expiry it says the card does not expire.
        isEmpty: (_) => false,
        editorBuilder: (context, session) =>
            CertificationDatesCardEditor(session: session),
      ),
      CertificationCardId.currency: EditCard<Certification>(
        id: CertificationCardId.currency.name,
        title: (context) =>
            CertificationCardId.currency.localizedDisplayName(context.l10n),
        // On the page whenever a rule applies or anything is logged; with
        // neither there is nothing to log against, so it is never offered.
        isEmpty: (_) => false,
        editorBuilder: (context, session) => CertificationCurrencySection(
          certification: session.working,
          editing: session,
        ),
      ),
      CertificationCardId.instructor: EditCard<Certification>(
        id: CertificationCardId.instructor.name,
        title: (context) =>
            CertificationCardId.instructor.localizedDisplayName(context.l10n),
        isEmpty: (c) =>
            c.instructorId == null &&
            c.instructorName == null &&
            c.instructorNumber == null,
        editorBuilder: (context, session) =>
            CertificationInstructorCardEditor(session: session),
      ),
      CertificationCardId.cardPhotos: EditCard<Certification>(
        id: CertificationCardId.cardPhotos.name,
        title: (context) =>
            CertificationCardId.cardPhotos.localizedDisplayName(context.l10n),
        isEmpty: (c) => !c.hasPhotos,
        editorBuilder: (context, session) =>
            CertificationCardPhotosEditor(session: session),
      ),
      CertificationCardId.documents: EditCard<Certification>(
        id: CertificationCardId.documents.name,
        title: (context) =>
            CertificationCardId.documents.localizedDisplayName(context.l10n),
        // Always on the page: with none, it says so.
        isEmpty: (_) => false,
        editorBuilder: (context, session) => DocumentsSection<Certification>(
          owner: DocumentOwner(
            DocumentOwnerKind.certification,
            session.stored.id,
          ),
          // The card images show in Card photos.
          excludeCards: true,
          editing: session,
        ),
      ),
      CertificationCardId.notes: EditCard<Certification>(
        id: CertificationCardId.notes.name,
        title: (context) =>
            CertificationCardId.notes.localizedDisplayName(context.l10n),
        isEmpty: (c) => c.notes.trim().isEmpty,
        editorBuilder: (context, session) =>
            CertificationNotesCardEditor(session: session),
      ),
    };

/// The cards the page leaves out while they are empty, offered in the
/// strip, in page order.
const List<CertificationCardId> certificationOptionalCards = [
  CertificationCardId.instructor,
  CertificationCardId.cardPhotos,
  CertificationCardId.notes,
];
