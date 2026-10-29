import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/presentation/helpers/face_box_geometry.dart';
import 'package:submersion/features/media/presentation/media_tag_navigation.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The people tagged on a photo or video (issue #1745), as a wrapping row of
/// chips over the viewer's dark overlay, beside the species chips. Me comes
/// first, then buddies by name; a video face tag reads "Alex · 0:42".
///
/// A buddy chip opens the buddy and Me opens the library filtered to Me. A
/// moment chip goes to [onMomentTap] instead, so the viewer can jump the
/// video there. Renders nothing when nobody is tagged.
class MediaPeopleChipsRow extends ConsumerWidget {
  final String mediaId;
  final ValueChanged<MediaPersonTag>? onMomentTap;

  const MediaPeopleChipsRow({
    super.key,
    required this.mediaId,
    this.onMomentTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chips =
        ref.watch(mediaPeopleChipsProvider(mediaId)).value ?? const [];
    if (chips.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: l10n.media_people_chipsLabel,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final chip in chips)
              ActionChip(
                avatar: ExcludeSemantics(
                  child: Icon(
                    chip.tag.isMe ? Icons.person : Icons.person_outline,
                    size: 16,
                  ),
                ),
                label: Text(personChipLabel(context, chip)),
                onPressed: () => _open(context, ref, chip.tag),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref, MediaPersonTag tag) {
    final moment = onMomentTap;
    if (tag.videoPosition != null && moment != null) {
      moment(tag);
    } else if (tag.isMe) {
      openMediaWithMe(context, ref);
    } else {
      context.push('/buddies/${tag.buddyId}');
    }
  }
}

/// A person's name as chips and box labels show it: "Me" for the diver,
/// the buddy's name otherwise, with the moment on a video face tag.
String personChipLabel(BuildContext context, MediaPersonChip chip) {
  final l10n = context.l10n;
  final name = chip.tag.isMe ? l10n.media_people_me : (chip.buddyName ?? '');
  final at = chip.tag.videoPosition;
  return at == null
      ? name
      : l10n.media_people_momentChip(name, formatMoment(at));
}
