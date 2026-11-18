import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';
import 'package:submersion/shared/widgets/shared_items/item_sharing_field.dart';

const _log = LoggerService('SiteSharingSitting');

/// The held change of the site's sharing with other profiles, on the
/// header block (issue #4527, phase 2).
const String siteSharingKey = 'site.sharing';

const String _repoKey = 'site.sharing.repo';
const String _loadedKey = 'site.sharing.loaded';
const String _currentKey = 'site.sharing.current';
const String _unreadKey = 'site.sharing.unread';

/// Reads who the site is shared with into the sitting, tracked, and keeps
/// the repository its held write uses. A read that fails is noted
/// ([siteSharingUnread]), as the form locked its field. A library site
/// reads nothing.
Future<void> loadSiteSharing(EditSession<DiveSite> session, ProviderRead read) {
  // A library site follows its library: no sharing to show or write.
  if (session.stored.isLibrarySite) return Future<void>.value();
  final repository = read(itemSharesRepositoryProvider);
  session.remember(_repoKey, repository);
  final siteId = session.stored.id;
  final work = () async {
    try {
      final sharing = await repository.sharingOf(SharedItemKind.site, siteId);
      if (session.isDisposed) return;
      session
        ..remember(_loadedKey, sharing)
        ..remember(_unreadKey, null);
    } catch (error, stackTrace) {
      _log.warning(
        'Could not read who site $siteId is shared with',
        error: error,
        stackTrace: stackTrace,
      );
      if (!session.isDisposed) session.remember(_unreadKey, true);
    }
  }();
  session.track(work);
  return work;
}

/// Who the site is shared with in the sitting: the diver's choice, else as
/// read; null before the read has answered.
ItemSharing? siteSharingInSitting(EditSession<DiveSite> session) {
  if (session.isDisposed) return null;
  return session.recall<ItemSharing>(_currentKey) ??
      session.recall<ItemSharing>(_loadedKey);
}

/// Who the site was shared with as the sitting read it.
ItemSharing? siteSharingLoaded(EditSession<DiveSite> session) =>
    session.isDisposed ? null : session.recall<ItemSharing>(_loadedKey);

/// Whether the read of the site's sharing failed: the field reads only.
bool siteSharingUnread(EditSession<DiveSite> session) =>
    !session.isDisposed && session.recall<bool>(_unreadKey) == true;

/// Holds [next] as the site's sharing, written at Save by [actingDiverId]
/// (the profile acting, which the repository checks; never the owner on its
/// behalf). Back to what was read releases it. A share the repository
/// refuses fails the whole Save.
void setSiteSharing(
  EditSession<DiveSite> session,
  ItemSharing next, {
  required String? actingDiverId,
}) {
  if (session.isDisposed || session.isFrozen) return;
  final loaded = siteSharingLoaded(session);
  final repository = session.recall<ItemSharesRepository>(_repoKey);
  if (loaded == null || repository == null) return;
  if (next == loaded) {
    session
      ..remember(_currentKey, null)
      ..releaseWrite(siteSharingKey);
    return;
  }
  final siteId = session.stored.id;
  session
    ..remember(_currentKey, next)
    // After the row, so the sharing's own everyone flag stands.
    ..holdChange(
      siteSharingKey,
      cardId: siteHeaderCardId,
      write: () async {
        final done = await repository.setSharing(
          SharedItemKind.site,
          siteId,
          next,
          actingDiverId: actingDiverId,
        );
        if (!done) throw const RecordSittingRefusal(sharingRefusedMessage);
      },
    );
}
