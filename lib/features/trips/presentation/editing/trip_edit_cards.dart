import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_fields.dart';
import 'package:submersion/features/trips/presentation/editing/trip_header_card_editor.dart';
import 'package:submersion/features/trips/presentation/editing/trip_overview_card_editors.dart';
import 'package:submersion/features/trips/presentation/editing/trip_vessel_sitting.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';

/// The trip page's cards that can be edited in place (issue #4527, phase
/// 3), by card id, in page order. The gear, cylinders, checklists, dives
/// and photos join in phase 3's next trip plan.
final Map<TripCardId, EditCard<Trip>> tripEditCards = {
  TripCardId.header: EditCard<Trip>(
    id: TripCardId.header.name,
    title: (context) => TripCardId.header.localizedDisplayName(context.l10n),
    isEmpty: (_) => false,
    // A name, as the form's validator had it.
    isValid: (session) => tripNameValid(session.working.name),
    editorBuilder: (context, session) => TripHeaderCardEditor(session: session),
  ),
  TripCardId.plan: EditCard<Trip>(
    id: TripCardId.plan.name,
    title: (context) => TripCardId.plan.localizedDisplayName(context.l10n),
    isEmpty: (t) =>
        t.divesPerDayTarget == null &&
        t.expectedDives == null &&
        t.expectedRuntimeMinutes == null &&
        t.diversSharingCylinders == 1,
    editorBuilder: (context, session) => TripPlanCardEditor(session: session),
  ),
  TripCardId.vessel: EditCard<Trip>(
    id: TripCardId.vessel.name,
    title: (context) => TripCardId.vessel.localizedDisplayName(context.l10n),
    // On the page while the trip is a liveaboard, details or not.
    isEmpty: (_) => false,
    // A liveaboard needs a vessel name, as the form's validator had it.
    isValid: (session) => tripVesselValid(tripVesselState, session),
    editorBuilder: (context, session) => TripVesselCardEditor(session: session),
  ),
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
///
/// The Plan card is on the prepare page; from the trip's first day it is
/// offered here, the story having no place of its own for it.
const List<TripCardId> tripOptionalCards = [TripCardId.plan, TripCardId.notes];
