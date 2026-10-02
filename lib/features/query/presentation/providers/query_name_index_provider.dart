import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/data/name_index_loader.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The one name index the parser, the builder's pickers, saved-query
/// loading and Explore's resolver read (#2365). Reloads when any ref table
/// or the locale changes, so a synced site or a renamed buddy shows up
/// without a restart and localized species names follow the app language.
final queryNameIndexProvider = FutureProvider<NameIndex>((ref) async {
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchTables(NameIndexLoader.tables));
  final locale = ref.watch(localeProvider);
  return NameIndexLoader(
    DatabaseService.instance.database,
  ).load(diverId: diverId, l10n: l10nForLocaleTag(locale));
});
