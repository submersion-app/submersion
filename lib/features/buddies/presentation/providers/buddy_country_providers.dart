import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_sites/domain/services/site_suggestions.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// The countries already written on the diver's buddies (issue #4457),
/// read as one column so the edit form never hydrates every buddy for them.
final usedBuddyCountriesProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.watch(buddyRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchBuddiesChanges());
  return repository.getUsedCountries(diverId: diverId);
});

/// The buddy Country field's suggestions (issue #4457): the countries
/// already written on buddies and sites first, then the ISO list, as the
/// site country field offers them. Worked out when buddies or sites change,
/// not on every rebuild of the form.
final buddyCountrySuggestionsProvider = FutureProvider<List<String>>((
  ref,
) async {
  final buddies = await ref.watch(usedBuddyCountriesProvider.future);
  final sites = await ref.watch(sitesProvider.future);
  return suggestedCountryNames([
    ...buddies,
    for (final site in sites) site.country,
  ]);
});
