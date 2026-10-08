import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Resolves a dive-type slug to its on-screen label.
///
/// Threaded into the list tiles as a parameter rather than each tile watching
/// `diveTypesProvider` itself: a tile that renders no Dive Type slot would
/// otherwise still rebuild its lookup map on every build, and still rebuild
/// whenever the `dive_types` table is touched -- including a sync re-applying
/// unchanged rows, which notifies on write regardless of whether any value
/// actually changed.
typedef DiveTypeLabelResolver = String Function(String id);

/// The currently loaded dive types, keyed by id.
///
/// Call once per list or section, above the item builder, and pass the
/// result down (or build a resolver from it) so the lookup map is built
/// once instead of once per row, and only the calling widget subscribes to
/// `diveTypesByIdProvider`.
///
/// A thin sync wrapper around [diveTypesByIdProvider] rather than a second
/// map built from [diveTypesProvider] directly: the two must stay the same
/// map, not two parallel copies of the same `{for (t in types) t.id: t}`.
///
/// Types that have not loaded yet yield an empty map, which is not an error:
/// [diveTypeLabel] falls through to the built-in localization table, so
/// built-in slugs still render translated on the first frame.
Map<String, DiveTypeEntity> watchDiveTypesById(WidgetRef ref) =>
    ref.watch(diveTypesByIdProvider).value ?? const <String, DiveTypeEntity>{};

/// Builds a [DiveTypeLabelResolver] from the currently loaded dive types.
/// Same call-once-per-list contract as [watchDiveTypesById].
DiveTypeLabelResolver watchDiveTypeLabelResolver(
  WidgetRef ref,
  AppLocalizations l10n,
) {
  final typesById = watchDiveTypesById(ref);
  return (id) => diveTypeLabel(l10n, id, typesById: typesById);
}

/// Short-form counterpart to [watchDiveTypeLabelResolver], for space
/// -constrained surfaces like list-row type badges. Same call-once-per-list
/// contract as [watchDiveTypesById].
DiveTypeLabelResolver watchDiveTypeShortLabelResolver(
  WidgetRef ref,
  AppLocalizations l10n,
) {
  final typesById = watchDiveTypesById(ref);
  return (id) => diveTypeShortLabel(l10n, id, typesById: typesById);
}

/// Whether a dive-type slug's badge should appear in the dive list's
/// type-badge row (issue #1269 follow-up). Independent of the header's own
/// visibility toggle -- a diver may want a type in one badge row but not
/// the other.
typedef DiveTypeListVisibilityPredicate = bool Function(String id);

/// Builds a [DiveTypeListVisibilityPredicate] from the currently loaded dive
/// types. Same call-once-per-list contract as [watchDiveTypeLabelResolver].
///
/// A slug absent from the loaded types (not yet loaded, or deleted out from
/// under a still-referencing dive) resolves to visible -- unknown is not the
/// same as explicitly hidden.
DiveTypeListVisibilityPredicate watchDiveTypeListVisibilityPredicate(
  WidgetRef ref,
) {
  final typesById = watchDiveTypesById(ref);
  return (id) => typesById[id]?.showInListView ?? true;
}
