import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/divers/presentation/editing/item_shares_sharing_adapter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_sharing_sitting.dart';

/// The held change of the site's sharing with other profiles, on the
/// header block (issue #4527, phase 2).
const String siteSharingKey = 'site.sharing';

/// Who the site is shared with, held in its sitting and written at Save
/// (issue #4527, phase 3, plan 12), as a trip's is.
final siteSharing = RecordSharingSitting<DiveSite, ItemSharing>(
  key: siteSharingKey,
  cardId: siteHeaderCardId,
  recordIdOf: (site) => site.id,
);

/// Reads who the site is shared with into [session], so the header's
/// editor can change it and an owner's Save clears share rows a sync race
/// left beside the Everyone flag, written by [actingDiverId] (the profile
/// acting now when not given). A read that fails is noted
/// ([RecordSharingSitting.unread]), as the form locked its field. A library
/// site reads nothing: it follows its library. A new site is shared as its
/// seed was, read from nowhere.
Future<void> loadSiteSharing(
  EditSession<DiveSite> session,
  ProviderRead read, {
  String? actingDiverId,
}) {
  if (session.stored.isLibrarySite) return Future<void>.value();
  return siteSharing.load(
    session,
    ItemSharesSharingAdapter(
      read(itemSharesRepositoryProvider),
      SharedItemKind.site,
    ),
    actingDiverId: actingDiverId ?? read(validatedCurrentDiverIdProvider).value,
    newRecordSharing: ItemSharing(everyone: session.stored.isShared),
  );
}
