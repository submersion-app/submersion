import 'package:equatable/equatable.dart';

/// Why a built-in record was taken out of the catalogue.
enum CatalogueWithdrawalReason {
  /// Its position was wrong.
  position,

  /// It is not a place people dive.
  notASite,

  /// It listed a site another record already lists.
  duplicate,

  /// Any other reason, including one this build does not know.
  other,
}

/// A researched record a catalogue no longer ships, and why.
///
/// The catalogue file lists every withdrawn id (`metadata.withdrawn`), so a
/// diver's site adopted from one can say that its record was withdrawn
/// instead of falling silent. Nothing about the site changes.
class CatalogueWithdrawal extends Equatable {
  /// The withdrawn record's id.
  final String id;
  final CatalogueWithdrawalReason reason;

  /// When it was withdrawn, as the file writes it (`2026-12-02`).
  final String date;

  /// The id of the record that corrects it, when there is one.
  final String? replacedBy;

  const CatalogueWithdrawal({
    required this.id,
    required this.reason,
    required this.date,
    this.replacedBy,
  });

  @override
  List<Object?> get props => [id, reason, date, replacedBy];
}

/// The reason a file names, as the app reads it. A reason this build does
/// not know reads as [CatalogueWithdrawalReason.other].
CatalogueWithdrawalReason catalogueWithdrawalReasonFromName(Object? name) =>
    switch (name) {
      'position' => CatalogueWithdrawalReason.position,
      'not_a_site' => CatalogueWithdrawalReason.notASite,
      'duplicate' => CatalogueWithdrawalReason.duplicate,
      _ => CatalogueWithdrawalReason.other,
    };

/// The name a file and the local cache write for [reason].
String catalogueWithdrawalReasonName(CatalogueWithdrawalReason reason) =>
    switch (reason) {
      CatalogueWithdrawalReason.position => 'position',
      CatalogueWithdrawalReason.notASite => 'not_a_site',
      CatalogueWithdrawalReason.duplicate => 'duplicate',
      CatalogueWithdrawalReason.other => 'other',
    };

/// Reads one `metadata.withdrawn` entry, or null when it is not an object
/// with a date.
CatalogueWithdrawal? catalogueWithdrawalFromJson(String id, Object? raw) {
  if (raw is! Map) return null;
  final date = raw['date'];
  if (date is! String || date.isEmpty) return null;
  final replacedBy = raw['replaced_by'];
  return CatalogueWithdrawal(
    id: id,
    reason: catalogueWithdrawalReasonFromName(raw['reason']),
    date: date,
    replacedBy: replacedBy is String && replacedBy.isNotEmpty
        ? replacedBy
        : null,
  );
}
