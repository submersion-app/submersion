import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The active diver's hidden ids for one [BuiltInCatalog] (issue #401).
///
/// Selects a sorted, newline-joined key rather than the set itself, since
/// every settings load decodes a fresh Set: this way a picker rebuilds only
/// when its own catalog's ids change, not on every settings write.
final hiddenBuiltInIdsProvider = Provider.family<Set<String>, BuiltInCatalog>((
  ref,
  catalog,
) {
  final key = ref.watch(
    settingsProvider.select(
      (settings) =>
          (settings.hiddenBuiltIns(catalog).toList()..sort()).join('\n'),
    ),
  );
  return key.isEmpty ? const {} : key.split('\n').toSet();
});
