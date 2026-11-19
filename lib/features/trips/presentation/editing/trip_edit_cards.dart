import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/features/trips/presentation/editing/trip_overview_card_editors.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';

/// The trip page's cards that can be edited in place (issue #4527, phase
/// 3), by card id, in page order. The gear, cylinders, checklists, dives
/// and photos join in phase 3's next trip plan.
final Map<TripCardId, EditCard<Trip>> tripEditCards = {
  TripCardId.notes: EditCard<Trip>(
    id: TripCardId.notes.name,
    title: (context) => TripCardId.notes.localizedDisplayName(context.l10n),
    isEmpty: (t) => t.notes.trim().isEmpty,
    editorBuilder: (context, session) => TripNotesCardEditor(session: session),
  ),
  TripCardId.documents: EditCard<Trip>(
    id: TripCardId.documents.name,
    title: (context) => TripCardId.documents.localizedDisplayName(context.l10n),
    // Always on the page: with none, it says so.
    isEmpty: (_) => false,
    editorBuilder: (context, session) => DocumentsSection<Trip>(
      owner: DocumentOwner(DocumentOwnerKind.trip, session.stored.id),
      editing: session,
    ),
  ),
};

/// The cards the page leaves out while they are empty, offered in the
/// strip on their tab, in page order.
const List<TripCardId> tripOptionalCards = [TripCardId.notes];
