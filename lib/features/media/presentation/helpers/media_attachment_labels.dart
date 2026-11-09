import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// [kind]'s label, shared by the filter sheet's Attached to section and the
/// active-filter chip (issue #4224) so a kind never reads two different ways.
///
/// Exhaustive by enum value, so a new MediaAttachmentKind is a compile error
/// here until its label is wired in.
String mediaAttachmentKindLabel(
  AppLocalizations l10n,
  MediaAttachmentKind kind,
) => switch (kind) {
  MediaAttachmentKind.dive => l10n.media_library_filter_attachedDive,
  MediaAttachmentKind.site => l10n.media_library_filter_attachedSite,
  MediaAttachmentKind.equipment => l10n.media_library_filter_attachedEquipment,
  MediaAttachmentKind.unlinked => l10n.media_library_filter_attachedUnlinked,
};
