import 'package:flutter/material.dart';

import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// [kind]'s label, shared by the filter sheet section and the active-filter
/// chip so a kind never reads two different ways.
String mediaAttachmentKindLabel(
  AppLocalizations l10n,
  MediaAttachmentKind kind,
) => switch (kind) {
  MediaAttachmentKind.dive => l10n.media_library_filter_attachedDive,
  MediaAttachmentKind.site => l10n.media_library_filter_attachedSite,
  MediaAttachmentKind.equipment => l10n.media_library_filter_attachedEquipment,
  MediaAttachmentKind.unlinked => l10n.media_library_filter_attachedUnlinked,
};

/// The filter sheet's Attached to section (issue #4224): one chip per
/// [MediaAttachmentKind], any-of, so a diver working through their dive
/// photos can hide the site maps and rules boards, or show only those.
///
/// Holds no state of its own: the sheet owns the draft and passes it in.
class MediaLibraryAttachmentFilterSection extends StatelessWidget {
  const MediaLibraryAttachmentFilterSection({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<MediaAttachmentKind> selected;
  final ValueChanged<Set<MediaAttachmentKind>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.media_library_filter_attachedTo,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in MediaAttachmentKind.values)
              FilterChip(
                key: ValueKey('media_filter_attached_${kind.name}'),
                label: Text(mediaAttachmentKindLabel(l10n, kind)),
                selected: selected.contains(kind),
                onSelected: (isSelected) => onChanged(
                  isSelected
                      ? {...selected, kind}
                      : selected.where((k) => k != kind).toSet(),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
