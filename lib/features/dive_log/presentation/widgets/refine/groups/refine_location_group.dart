import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/utils/filter_option_search.dart';
import 'package:submersion/features/dive_log/presentation/widgets/searchable_filter_dropdown.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_field.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Refine panel's Location group (#2773): the dive site, picked from the
/// shared site picker sheet (#1080), and trip and dive center, each a
/// type-ahead that also matches where the place is.
class RefineLocationGroup extends ConsumerWidget {
  const RefineLocationGroup({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final DiveFilterState draft;
  final ValueChanged<DiveFilterState> onChanged;

  /// The DiveFilterState fields this group edits (read by the axis guard).
  static const fields = {'siteId', 'tripId', 'diveCenterId'};

  static int activeCount(DiveFilterState f) => [
    f.siteId != null,
    f.tripId != null,
    f.diveCenterId != null,
  ].where((active) => active).length;

  static String title(AppLocalizations l10n) =>
      l10n.diveLog_search_section_location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    const gap = SizedBox(height: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ref
            .watch(sitesProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text(l10n.diveLog_filter_errorLoadingSites),
              data: (_) => SitePickerField(
                value: draft.siteId,
                onChanged: (v) => onChanged(
                  draft.copyWith(siteId: v, clearSiteId: v == null),
                ),
              ),
            ),
        gap,
        ref
            .watch(allTripsProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text(l10n.diveLog_search_errorLoadingTrips),
              data: (trips) => SearchableFilterDropdown<String>(
                value: draft.tripId,
                labelText: l10n.diveLog_search_label_trip,
                allOptionLabel: l10n.diveLog_search_allTrips,
                searchHintText: l10n.diveLog_filter_searchTripsHint,
                icon: Icons.flight,
                options: [
                  for (final trip in trips)
                    FilterDropdownOption(
                      value: trip.id,
                      label: trip.name,
                      searchText: buildFilterSearchText([
                        trip.name,
                        trip.location,
                        trip.resortName,
                        trip.liveaboardName,
                      ]),
                    ),
                ],
                onChanged: (v) => onChanged(
                  draft.copyWith(tripId: v, clearTripId: v == null),
                ),
              ),
            ),
        gap,
        ref
            .watch(allDiveCentersProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text(l10n.diveLog_search_errorLoadingCenters),
              data: (centers) => SearchableFilterDropdown<String>(
                value: draft.diveCenterId,
                labelText: l10n.diveLog_search_label_diveCenter,
                allOptionLabel: l10n.diveLog_search_allCenters,
                searchHintText: l10n.diveLog_filter_searchCentersHint,
                icon: Icons.store,
                options: [
                  for (final center in centers)
                    FilterDropdownOption(
                      value: center.id,
                      label: center.name,
                      searchText: buildFilterSearchText([
                        center.name,
                        center.city,
                        center.stateProvince,
                        center.country,
                      ]),
                    ),
                ],
                onChanged: (v) => onChanged(
                  draft.copyWith(diveCenterId: v, clearDiveCenterId: v == null),
                ),
              ),
            ),
      ],
    );
  }
}
