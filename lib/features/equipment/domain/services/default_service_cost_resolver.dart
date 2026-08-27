import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

typedef DefaultServiceCost = ({double? cost, String? currency});

/// Resolves the price to prefill when logging maintenance, most specific
/// first: the per-item schedule, then the shared kind catalog.
///
/// Issue #829 lists the catalog before the interval. That is inverted
/// relative to specificity: a kind is global across every item using it,
/// while a schedule belongs to one piece of equipment, so two rebreathers
/// serviced at different shops could never reach their own price. The issue
/// also says the value can be overwritten or deleted, which makes the whole
/// chain a prefill rather than a binding value, so letting the per-item
/// figure win serves the stated goal.
///
/// Cost and currency resolve independently: a schedule that names a price but
/// no currency still inherits the kind's currency instead of dropping it.
DefaultServiceCost resolveDefaultServiceCost({
  required String? serviceKindId,
  required List<ServiceSchedule> schedules,
  required List<ServiceKind> kinds,
}) {
  if (serviceKindId == null) return (cost: null, currency: null);

  ServiceSchedule? schedule;
  for (final candidate in schedules) {
    if (candidate.serviceKindId == serviceKindId) {
      schedule = candidate;
      break;
    }
  }

  ServiceKind? kind;
  for (final candidate in kinds) {
    if (candidate.id == serviceKindId) {
      kind = candidate;
      break;
    }
  }

  return (
    cost: schedule?.defaultCost ?? kind?.defaultCost,
    currency: schedule?.defaultCurrency ?? kind?.defaultCurrency,
  );
}

/// Resolves the category to prefill when logging maintenance.
///
/// Unlike the price, this has no per-item level: a schedule carries no
/// category, because a category describes what kind of work a service type
/// is, which does not vary from one item to the next the way a shop's price
/// does. Returns null when nothing is selected, when the selected type has no
/// opinion, or when the id names a type no longer in the catalog.
ServiceCategory? resolveDefaultServiceCategory({
  required String? serviceKindId,
  required List<ServiceKind> kinds,
}) {
  if (serviceKindId == null) return null;
  for (final candidate in kinds) {
    if (candidate.id == serviceKindId) return candidate.defaultCategory;
  }
  return null;
}
