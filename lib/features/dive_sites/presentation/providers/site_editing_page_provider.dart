import 'package:flutter/foundation.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The site page that edits in place, for what reaches the site from
/// outside the page: a file dropped on it (issue #4527, phase 2). Set by
/// the page for as long as it offers editing, with its sitting while the
/// site is unlocked; cleared when the page goes.
@immutable
class SiteEditingPage {
  const SiteEditingPage({
    required this.siteId,
    required this.session,
    required this.showMediaCard,
  });

  final String siteId;

  /// The open sitting, or null while the site is locked.
  final EditSession<DiveSite>? session;

  /// Brings the Media card into view as its editor, so a held drop shows.
  final VoidCallback showMediaCard;
}

final siteEditingPageProvider = StateProvider<SiteEditingPage?>((ref) => null);

/// What a media file dropped on a site does.
enum SiteDropAnswer {
  /// Imported at once, as before: no page edits this site in place.
  importNow,

  /// Held in the site's open sitting until Save.
  hold,

  /// Refused with a hint to unlock the site: it is locked, or being saved.
  refuse,
}

/// The answer for a drop on [siteId], given the [page] that edits a site
/// in place, if any.
SiteDropAnswer siteDropAnswer({
  required SiteEditingPage? page,
  required String siteId,
}) {
  if (page == null || page.siteId != siteId) return SiteDropAnswer.importNow;
  final session = page.session;
  if (session == null || session.isDisposed || session.isFrozen) {
    return SiteDropAnswer.refuse;
  }
  return SiteDropAnswer.hold;
}
