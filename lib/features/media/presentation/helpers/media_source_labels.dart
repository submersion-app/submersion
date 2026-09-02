import 'package:flutter/widgets.dart';

import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Localized display name for a media source type.
///
/// Shared rather than duplicated: the Sources section lists these as
/// browsable rows and the library's active-filter chips echo whichever one is
/// filtering, so two copies of the switch would drift the moment a source
/// type is added or renamed.
///
/// Exhaustive by enum value, so a new MediaSourceType is a compile error here
/// until its label is wired in.
String mediaSourceLabel(BuildContext context, MediaSourceType type) {
  return switch (type) {
    MediaSourceType.platformGallery => context.l10n.media_source_gallery,
    MediaSourceType.localFile => context.l10n.media_source_localFile,
    MediaSourceType.networkUrl => context.l10n.media_source_networkUrl,
    MediaSourceType.manifestEntry => context.l10n.media_source_manifest,
    MediaSourceType.serviceConnector => context.l10n.media_source_connector,
    MediaSourceType.mediaStore => context.l10n.media_source_mediaStore,
    MediaSourceType.signature => context.l10n.media_source_signature,
  };
}
