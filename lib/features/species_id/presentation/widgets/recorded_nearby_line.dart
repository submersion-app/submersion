import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/species_id/domain/services/recorded_nearby.dart';
import 'package:submersion/features/species_id/presentation/providers/recorded_nearby_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "Recorded nearby" under a marine life suggestion when the species is on
/// the dive's nearby list (issue #4668), the same words the site page uses.
///
/// A hint only, and positive only: while the list loads, when it cannot be
/// had, or when the species is not on it, this is empty and the row looks
/// as it did without it. Absence says little, since the list leaves out
/// every record not licensed CC0 or CC BY.
class RecordedNearbyLine extends ConsumerWidget {
  const RecordedNearbyLine({
    super.key,
    required this.request,
    required this.gbifKeys,
    this.catalogId,
  });

  /// The dive or photo whose list is read.
  final NearbyListRequest request;

  /// The suggestion's GBIF species keys: one for a suggestion, every key a
  /// review row's species is known by.
  final Set<int> gbifKeys;

  /// The suggestion's catalogue id, which still matches when its key is a
  /// synonym of the key the list holds.
  final String? catalogId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearby = ref.watch(recordedNearbyListProvider(request)).value;
    if (nearby == null ||
        !isRecordedNearby(nearby, gbifKeys: gbifKeys, catalogId: catalogId)) {
      return const SizedBox.shrink();
    }
    // Small, in the colour of the text around it: under a list tile's
    // secondary line it matches that line rather than outranking it. One
    // line, so a long translation arriving late cannot push the row's
    // buttons down.
    return Text(
      context.l10n.reef_species_recordedNearby,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: DefaultTextStyle.of(context).style.color,
      ),
    );
  }
}
