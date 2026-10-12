import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_field_labels.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_role_chip.dart';
import 'package:submersion/features/shared_library/presentation/widgets/site_attribution_line.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Each field of a club library site with its last editor and time
/// (issue #2567).
Future<void> showSiteEditHistorySheet(
  BuildContext context, {
  required DiveSite site,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => SiteEditHistorySheet(site: site),
);

class SiteEditHistorySheet extends ConsumerWidget {
  const SiteEditHistorySheet({super.key, required this.site});

  final DiveSite site;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final libraryId = site.sharedLibraryId ?? '';
    // .value keeps the last state through a reload, as on the header.
    final state = ref.watch(siteLibraryStateProvider(site.id)).value;
    final names =
        ref.watch(libraryMemberNamesProvider(libraryId)).value ??
        const <String, String>{};
    // Growable: the first frame has no state yet and sort mutates in place.
    final entries = <MapEntry<String, FieldClock>>[...?state?.clocks.entries]
      ..sort((a, b) => b.value.hlc.compareTo(a.value.hlc));
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              l10n.sharedLibrary_site_history,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(site.name),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final e in entries)
                  ListTile(
                    dense: true,
                    title: Text(libraryFieldLabel(l10n, e.key)),
                    subtitle: Text(
                      l10n.sharedLibrary_site_lastEdited(
                        memberDisplayName(names, e.value.memberId),
                        libraryDateLabel(
                          ref,
                          DateTime.fromMillisecondsSinceEpoch(
                            e.value.hlc.physicalTime,
                            isUtc: true,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
