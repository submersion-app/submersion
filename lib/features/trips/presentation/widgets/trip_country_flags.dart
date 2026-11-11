import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_country.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/country_flag.dart';

/// Whether [TripCountryFlags] would draw anything for [tripId]: flags are on
/// and the trip has a recognised country. Lets a title fall back to plain
/// text when there is nothing to show beside it.
bool tripHasFlags(WidgetRef ref, String tripId) =>
    _shownCountries(ref, tripId).isNotEmpty;

/// [tripId]'s countries as its flags show them: none while they load, when
/// the trip has none, or when the diver has turned flags off.
List<TripCountry> _shownCountries(WidgetRef ref, String tripId) {
  if (!ref.watch(showCountryFlagsProvider)) return const [];
  return ref.watch(tripCountriesProvider).value?[tripId] ?? const [];
}

/// The flags of the countries a trip's dives were in (issue #4426), most
/// dived first.
///
/// Nothing at all while the countries load, when the trip has none, or when
/// the diver has turned flags off, so a trip row never shows a placeholder.
/// The trip's countries are not written beside the flags, so the group
/// names them for screen readers and in a tooltip.
class TripCountryFlags extends ConsumerWidget {
  const TripCountryFlags({
    super.key,
    required this.tripId,
    this.maxFlags,
    this.flagHeight = 11,
    this.gap = 0,
  });

  final String tripId;

  /// How many flags to draw before summing the rest as "+N"; null draws all.
  final int? maxFlags;

  final double flagHeight;

  /// Space before the flags, drawn only when there are flags, so a trip
  /// with none leaves no stray gap after its name.
  final double gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countries = _shownCountries(ref, tripId);
    if (countries.isEmpty) return const SizedBox.shrink();

    final shown = maxFlags == null
        ? countries
        : countries.take(maxFlags!).toList();
    final hidden = countries.length - shown.length;
    final names = countries
        .map((c) => c.name)
        .join(context.l10n.trips_countryFlags_separator);

    return Padding(
      padding: EdgeInsetsDirectional.only(start: gap),
      child: Tooltip(
        message: names,
        excludeFromSemantics: true,
        child: Semantics(
          label: context.l10n.trips_countryFlags_semantics(names),
          excludeSemantics: true,
          // A Wrap, so a trip with more flags than fit on the line (all of
          // them, on trip details) runs onto another line instead of
          // overflowing.
          child: Wrap(
            spacing: 2,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final country in shown)
                CountryFlag(code: country.code, height: flagHeight),
              if (hidden > 0) ...[
                const SizedBox(width: 1),
                Text(
                  context.l10n.trips_countryFlags_more(hidden),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
