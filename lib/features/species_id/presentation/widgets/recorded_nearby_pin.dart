import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/species_id/domain/services/recorded_nearby.dart';
import 'package:submersion/features/species_id/presentation/providers/recorded_nearby_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A small pin after a suggestion chip's label when the species is on the
/// dive's "Recorded nearby" list (issue #4668). It is the chip's form of
/// `RecordedNearbyLine`, for the photo viewer's single line of chips, where
/// a second line of text does not fit.
///
/// Positive only, as the line is: nothing while the list loads, when it
/// cannot be had, or when the species is not on it. Screen readers hear
/// "Recorded nearby" with the chip.
class RecordedNearbyPin extends ConsumerWidget {
  const RecordedNearbyPin({
    super.key,
    required this.request,
    required this.gbifKey,
    this.catalogId,
    this.size = 16,
  });

  /// The dive or photo whose list is read.
  final NearbyListRequest request;

  /// The suggestion's GBIF species key.
  final int gbifKey;

  /// The suggestion's catalogue id, which still matches when its key is a
  /// synonym of the key the list holds.
  final String? catalogId;

  /// The pin's size, the chip's icon size.
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearby = ref.watch(recordedNearbyListProvider(request)).value;
    if (nearby == null ||
        !isRecordedNearby(nearby, gbifKeys: {gbifKey}, catalogId: catalogId)) {
      return const SizedBox.shrink();
    }
    // In the colour of the chip's label, so the marker adds no colour.
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Icon(
        Icons.place_outlined,
        key: const ValueKey('recorded_nearby_pin'),
        size: size,
        color: DefaultTextStyle.of(context).style.color,
        semanticLabel: context.l10n.reef_species_recordedNearby,
      ),
    );
  }
}
