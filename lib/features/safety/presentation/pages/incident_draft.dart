import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/features/safety/domain/entities/incident_changes.dart';

/// The near-miss editor's form as shown (issue #4527, phase 4): choices as
/// picked, texts as typed (untrimmed), and the two dives the form tells
/// apart. A record type, so it compares by value.
typedef IncidentDraft = ({
  IncidentCategory category,
  IncidentSeverity severity,

  /// A wall-clock UTC date, as the form holds it.
  DateTime occurredAt,
  String? equipmentId,
  String? observationId,

  /// The report's own dive.
  String? diveId,

  /// The dive that came with the chosen check-in: it goes when the
  /// check-in does.
  String? checkInDiveId,
  String narrative,
  String factors,
  String lessons,
});

/// A new report's blank form on [today]: other, minor, nothing linked,
/// nothing typed. A new report opened from a dive or a check-in opens its
/// sitting on this, so what was filled in is a change.
IncidentDraft blankIncidentDraft(DateTime today) => (
  category: IncidentCategory.other,
  severity: IncidentSeverity.minor,
  occurredAt: today,
  equipmentId: null,
  observationId: null,
  diveId: null,
  checkInDiveId: null,
  narrative: '',
  factors: '',
  lessons: '',
);

/// The dive a report saves with when [linkable] is its check-in that can
/// still be linked: its own, else the check-in's. The check-in's goes when
/// the check-in has.
String? incidentSavedDiveId(IncidentDraft draft, String? linkable) =>
    linkable == null ? draft.diveId : draft.diveId ?? draft.checkInDiveId;

/// [text] trimmed, or null when nothing is left: how an optional text is
/// stored.
String? incidentOptionalText(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// What Save writes on a stored report: each field whose draft value
/// differs from [start]'s, texts trimmed and blank optional ones cleared.
/// The links only when the check-in or a dive changed, then as [linkable]
/// (the chosen check-in, when it can still be linked) and
/// [incidentSavedDiveId].
IncidentChanges incidentChanges({
  required IncidentDraft draft,
  required IncidentDraft start,
  required String? linkable,
}) {
  final linkChanged =
      draft.observationId != start.observationId ||
      draft.diveId != start.diveId ||
      draft.checkInDiveId != start.checkInDiveId;
  return IncidentChanges(
    occurredAt: draft.occurredAt == start.occurredAt ? null : draft.occurredAt,
    category: draft.category == start.category ? null : draft.category,
    severity: draft.severity == start.severity ? null : draft.severity,
    narrative: draft.narrative == start.narrative
        ? null
        : draft.narrative.trim(),
    contributingFactors: draft.factors == start.factors
        ? null
        : (value: incidentOptionalText(draft.factors)),
    lessonsLearned: draft.lessons == start.lessons
        ? null
        : (value: incidentOptionalText(draft.lessons)),
    equipmentId: draft.equipmentId == start.equipmentId
        ? null
        : (value: draft.equipmentId),
    link: linkChanged
        ? (
            diveId: incidentSavedDiveId(draft, linkable),
            observationId: linkable,
          )
        : null,
  );
}
