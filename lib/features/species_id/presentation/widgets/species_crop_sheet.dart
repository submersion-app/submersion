import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/services/species_crops.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

/// Opens what [chip]'s species looks like on [item], a locked photo or
/// video (issue #5024): its crops in a sheet, or the species page when
/// there is none to show (a tag added by hand, or labels off).
Future<void> openSpeciesCrops(
  BuildContext context,
  WidgetRef ref, {
  required MediaItem item,
  required SpeciesTagChip chip,
}) async {
  final speciesPage = '/species/${chip.speciesId}';
  if (!marineLifeLabelsShown) {
    context.push(speciesPage);
    return;
  }
  // Read once, at the tap: the photo is locked, so its tags hold still.
  final identifications = await ref
      .read(mediaIdentificationRepositoryProvider)
      .forMedia(item.id);
  if (!context.mounted) return;
  final crops = cropsOfSpecies(identifications, chip.speciesId);
  if (crops.isEmpty) {
    context.push(speciesPage);
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => SpeciesCropSheet(item: item, chip: chip, crops: crops),
  );
}

/// What one species looks like on a photo or video: its crops, large,
/// with the way to its species page (issue #5024).
class SpeciesCropSheet extends ConsumerStatefulWidget {
  const SpeciesCropSheet({
    super.key,
    required this.item,
    required this.chip,
    required this.crops,
  });

  final MediaItem item;
  final SpeciesTagChip chip;

  /// Never empty, in the order [cropsOfSpecies] gives.
  final List<MediaIdentification> crops;

  @override
  ConsumerState<SpeciesCropSheet> createState() => _SpeciesCropSheetState();
}

class _SpeciesCropSheetState extends ConsumerState<SpeciesCropSheet> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(key: ValueKey('species_crop_sheet'));
  }
}
