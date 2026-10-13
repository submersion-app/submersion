import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_role_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The newest clock of a library site's state, or null when none.
FieldClock? newestFieldClock(SharedSiteState? state) =>
    newestClockOf(state?.clocks.values ?? const <FieldClock>[]);

/// A member's display name from the cache, or a shortened id.
String memberDisplayName(Map<String, String> names, String memberId) {
  final name = names[memberId];
  if (name != null && name.isNotEmpty) return name;
  return memberId.length > 8 ? memberId.substring(0, 8) : memberId;
}

/// `Last edited by [name], [date]` for a shared site library site (issue #2567);
/// nothing for a personal site or one with no clocks yet.
class SiteAttributionLine extends ConsumerWidget {
  const SiteAttributionLine({super.key, required this.site});

  final DiveSite site;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryId = site.sharedLibraryId;
    if (libraryId == null) return const SizedBox.shrink();
    // .value keeps the last state through a reload (each new clock
    // reloads it), where valueOrNull would blank the line.
    final state = ref.watch(siteLibraryStateProvider(site.id)).value;
    final newest = newestFieldClock(state);
    if (newest == null) return const SizedBox.shrink();
    final names =
        ref.watch(libraryMemberNamesProvider(libraryId)).value ??
        const <String, String>{};
    final when = newest.editedAt;
    return Text(
      context.l10n.sharedLibrary_site_lastEdited(
        memberDisplayName(names, newest.memberId),
        libraryDateLabel(ref, when),
      ),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
