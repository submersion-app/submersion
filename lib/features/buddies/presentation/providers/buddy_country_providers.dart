import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_sites/domain/services/site_suggestions.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

/// The buddy Country field's suggestions (issue #4457): the countries
/// already written on buddies and sites first, then the ISO list, as the
/// site country field offers them. Worked out when buddies or sites change,
/// not on every rebuild of the form.
final buddyCountrySuggestionsProvider = FutureProvider<List<String>>((
  ref,
) async {
  final buddies = await ref.watch(allBuddiesProvider.future);
  final sites = await ref.watch(sitesProvider.future);
  return suggestedCountryNames([
    for (final buddy in buddies) buddy.country,
    for (final site in sites) site.country,
  ]);
});
