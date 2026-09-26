import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

extension ServiceDueFilterDisplay on ServiceDueFilter {
  /// The diver-facing name of this narrowing, used by the filter sheet's
  /// choice chip and by the active-filter chip that clears it again.
  String localizedName(AppLocalizations l10n) => switch (this) {
    ServiceDueFilter.any => l10n.equipment_list_filterServiceDue,
    ServiceDueFilter.overdue => l10n.equipment_list_filterServiceOverdue,
    ServiceDueFilter.dueSoon => l10n.equipment_list_filterServiceDueSoon,
  };

  /// How the empty state names what it looked for, e.g. "No equipment
  /// overdue for service".
  String emptyStateFilterText(AppLocalizations l10n) => switch (this) {
    ServiceDueFilter.any =>
      l10n.equipment_list_emptyState_filterText_serviceDue,
    ServiceDueFilter.overdue =>
      l10n.equipment_list_emptyState_filterText_serviceOverdue,
    ServiceDueFilter.dueSoon =>
      l10n.equipment_list_emptyState_filterText_serviceDueSoon,
  };

  /// The line under the empty state's headline.
  ///
  /// Only the combined filter can claim the whole kit is up to date: an
  /// empty due-soon list says nothing about what has already lapsed, and an
  /// empty overdue list says nothing about what is coming.
  String emptyStateSubtitle(AppLocalizations l10n) => switch (this) {
    ServiceDueFilter.any => l10n.equipment_list_emptyState_serviceDueUpToDate,
    ServiceDueFilter.overdue =>
      l10n.equipment_list_emptyState_serviceNoneOverdue,
    ServiceDueFilter.dueSoon =>
      l10n.equipment_list_emptyState_serviceNoneDueSoon,
  };
}
