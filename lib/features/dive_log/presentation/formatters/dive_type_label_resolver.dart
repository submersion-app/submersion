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

/// Builds a [DiveTypeLabelResolver] from the currently loaded dive types.
///
/// Call once per list, above the item builder, and pass the result down. The
/// lookup map is then built once for the whole list instead of once per row,
/// and only the calling widget subscribes to `diveTypesProvider`.
///
/// Types that have not loaded yet yield an empty map, which is not an error:
/// [diveTypeLabel] falls through to the built-in localization table, so
/// built-in slugs still render translated on the first frame.
DiveTypeLabelResolver watchDiveTypeLabelResolver(
  WidgetRef ref,
  AppLocalizations l10n,
) {
  final typesById = {
    for (final t
        in ref.watch(diveTypesProvider).value ?? const <DiveTypeEntity>[])
      t.id: t,
  };
  return (id) => diveTypeLabel(l10n, id, typesById: typesById);
}
