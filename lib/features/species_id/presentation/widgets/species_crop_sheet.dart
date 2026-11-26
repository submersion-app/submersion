import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/helpers/face_box_geometry.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/services/species_crops.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/suggested_species_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(SpeciesCropSheet);

/// Whether a tag's crops are being read, so a second tap meanwhile opens
/// nothing more.
bool _opening = false;

/// Opens what [chip]'s species looks like on [item], a locked photo or
/// video (issue #5024): its crops in a sheet, or the species page when
/// there is none to show (a tag added by hand, labels off, or a read that
/// failed).
///
/// On a video, [onMoment] lets the sheet list when the species was seen
/// (issue #5032): a tapped time closes it and is handed to [onMoment],
/// which plays the video from there. Without it no times show.
Future<void> openSpeciesCrops(
  BuildContext context,
  WidgetRef ref, {
  required MediaItem item,
  required SpeciesTagChip chip,
  ValueChanged<Duration>? onMoment,
}) async {
  final speciesPage = '/species/${chip.speciesId}';
  if (!marineLifeLabelsShown) {
    context.push(speciesPage);
    return;
  }
  if (_opening) return;
  _opening = true;
  List<MediaIdentification> crops;
  try {
    // Read once, at the tap: the photo is locked, so its tags hold still.
    final identifications = await ref
        .read(mediaIdentificationRepositoryProvider)
        .forMedia(item.id);
    crops = cropsOfSpecies(identifications, chip.speciesId);
  } catch (e, stack) {
    _log.warning(
      'Could not read the crops of a species tag',
      error: e,
      stackTrace: stack,
    );
    crops = const [];
  } finally {
    _opening = false;
  }
  if (!context.mounted) return;
  if (crops.isEmpty) {
    context.push(speciesPage);
    return;
  }
  final moment = await showModalBottomSheet<Duration>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => SpeciesCropSheet(
      item: item,
      chip: chip,
      crops: crops,
      showMoments: onMoment != null,
    ),
  );
  if (moment != null) onMoment?.call(moment);
}

/// What one species looks like on a photo or video: its crops, large,
/// with the way to its species page (issue #5024).
class SpeciesCropSheet extends ConsumerStatefulWidget {
  const SpeciesCropSheet({
    super.key,
    required this.item,
    required this.chip,
    required this.crops,
    this.showMoments = false,
  });

  final MediaItem item;
  final SpeciesTagChip chip;

  /// Never empty, in the order [cropsOfSpecies] gives. On a video, every
  /// track of the species, whether or not the cap kept its crop (issue
  /// #5032).
  final List<MediaIdentification> crops;

  /// Whether a video lists when the species was seen, each time closing
  /// the sheet with that moment.
  final bool showMoments;

  @override
  ConsumerState<SpeciesCropSheet> createState() => _SpeciesCropSheetState();
}

class _SpeciesCropSheetState extends ConsumerState<SpeciesCropSheet> {
  /// The crop shown large.
  int _selected = 0;

  static const double _largeHeight = 320;
  static const double _thumbSize = 56;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final chip = widget.chip;
    final all = widget.crops;
    final mediaId = widget.item.id;
    final video = widget.item.isVideo;
    // A video keeps only the clearest few crops of a species (issue #5032):
    // the strip shows those, or the first track, whose crop falls back to a
    // kept one of its group.
    final presentRead = video
        ? ref.watch(presentCropIdsProvider(mediaId))
        : null;
    final present = presentRead?.value;
    // Read, or failed to: a failed read counts every track, never hides it.
    final presentKnown = presentRead == null || !presentRead.isLoading;
    final kept = present == null
        ? const <MediaIdentification>[]
        : [
            for (final i in all)
              if (present.contains(i.id)) i,
          ];
    final crops = !video ? all : (kept.isEmpty ? [all.first] : kept);
    final selected = _selected < crops.length ? _selected : 0;
    final scientific = ref
        .watch(speciesProvider(chip.speciesId))
        .value
        ?.scientificName;
    return SingleChildScrollView(
      key: const ValueKey('species_crop_sheet'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            localizedSpeciesName(l10n, chip.speciesId, chip.storedName),
            style: theme.textTheme.titleLarge,
          ),
          if (scientific != null && scientific.isNotEmpty)
            Text(
              scientific,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 16),
          ClipRRect(
            key: const ValueKey('species_crop_large'),
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _largeHeight),
              child: IdentificationCrop(
                // A new crop, not the last one's picture held over.
                key: ValueKey(crops[selected].id),
                mediaId: mediaId,
                identificationId: crops[selected].id,
                fit: BoxFit.contain,
                showReason: true,
              ),
            ),
          ),
          // On a video, said once the kept crops are read, so the count
          // does not change under the diver's eyes.
          if (all.length > 1 && presentKnown) ...[
            const SizedBox(height: 12),
            Text(
              !video
                  ? l10n.media_species_cropCountPhoto(all.length)
                  : kept.isNotEmpty && kept.length < all.length
                  ? l10n.media_species_cropBestOfVideo(kept.length, all.length)
                  : l10n.media_species_cropCountVideo(all.length),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (crops.length > 1) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: _thumbSize + 8,
              child: ListView.separated(
                key: const ValueKey('species_crop_thumbs'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(4),
                itemCount: crops.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) =>
                    _thumb(context, crops, index, selected, mediaId),
              ),
            ),
          ],
          if (video && widget.showMoments) ..._moments(context, all),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey('species_crop_species_page'),
            icon: const Icon(Icons.chevron_right),
            iconAlignment: IconAlignment.end,
            label: Text(l10n.media_species_openSpeciesPage),
            onPressed: () {
              // The page goes over what opened this sheet, not over the
              // sheet itself, so Back returns there.
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              router.push('/species/${chip.speciesId}');
            },
          ),
        ],
      ),
    );
  }

  /// When the species was seen in the video, each time a chip that closes
  /// the sheet with its moment (issue #5032).
  List<Widget> _moments(BuildContext context, List<MediaIdentification> all) {
    final l10n = context.l10n;
    final stretches = videoStretches(all);
    if (stretches.isEmpty) return const [];
    String time(int ms) => formatMoment(Duration(milliseconds: ms));
    return [
      const SizedBox(height: 16),
      Text(
        l10n.media_species_seenAt,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in stretches)
            Builder(
              builder: (context) {
                void play() => Navigator.of(
                  context,
                ).pop(Duration(milliseconds: s.startMs));
                // The chip's own semantics are replaced, so the tap is
                // offered here too, or a screen reader cannot press it.
                return Semantics(
                  button: true,
                  label: l10n.media_species_playFrom(time(s.startMs)),
                  excludeSemantics: true,
                  onTap: play,
                  child: ActionChip(
                    key: ValueKey('species_crop_moment_${s.startMs}'),
                    avatar: const Icon(Icons.play_arrow, size: 18),
                    label: Text(
                      s.endMs - s.startMs < 1000
                          ? time(s.startMs)
                          : l10n.media_species_seenStretch(
                              time(s.startMs),
                              time(s.endMs),
                            ),
                    ),
                    onPressed: play,
                  ),
                );
              },
            ),
        ],
      ),
    ];
  }

  Widget _thumb(
    BuildContext context,
    List<MediaIdentification> crops,
    int index,
    int current,
    String mediaId,
  ) {
    final selected = index == current;
    final id = crops[index].id;
    final scheme = Theme.of(context).colorScheme;
    void select() => setState(() => _selected = index);
    return Semantics(
      button: true,
      selected: selected,
      label: context.l10n.media_species_cropThumb(index + 1, crops.length),
      excludeSemantics: true,
      onTap: select,
      child: GestureDetector(
        key: ValueKey('species_crop_thumb_$id'),
        onTap: select,
        child: Container(
          width: _thumbSize,
          height: _thumbSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: IdentificationCrop(mediaId: mediaId, identificationId: id),
          ),
        ),
      ),
    );
  }
}
