import 'package:flutter/material.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/profile_hides_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(SharedItemKind);

/// The dives linked to a shared trip or site, split into the active
/// profile's and every other profile's, for the delete and remove
/// confirmations (issue #2594). The counts only inform the confirmation,
/// so a failed read opens it without them rather than blocking it, as
/// `readSiteDeleteUsage` does.
Future<({int mine, int others})> readDiveLinkCounts(
  WidgetRef ref,
  SharedItemKind kind,
  String id,
) async {
  try {
    final activeDiverId = await ref.read(
      validatedCurrentDiverIdProvider.future,
    );
    return await ref
        .read(profileHidesRepositoryProvider)
        .diveLinkCounts(kind, id, activeDiverId);
  } catch (e, stackTrace) {
    _log.warning(
      'Could not count the dives linked to a shared ${kind.name}',
      error: e,
      stackTrace: stackTrace,
    );
    return (mine: 0, others: 0);
  }
}

/// The active profile and how many profiles exist, for splitting a bulk
/// selection and choosing its warning (issue #2594). A failed read gives
/// no profile and no count, so the split treats every item as the
/// caller's to delete, as before sharing existed; the repositories still
/// refuse another profile's item.
Future<({String? activeDiverId, int diverCount})> readSharingContext(
  WidgetRef ref,
) async {
  String? activeDiverId;
  var diverCount = 0;
  try {
    activeDiverId = await ref.read(validatedCurrentDiverIdProvider.future);
  } catch (e, stackTrace) {
    _log.warning(
      'Could not read the active profile',
      error: e,
      stackTrace: stackTrace,
    );
  }
  try {
    diverCount = (await ref.read(allDiversProvider.future)).length;
  } catch (e, stackTrace) {
    _log.warning(
      'Could not count the profiles',
      error: e,
      stackTrace: stackTrace,
    );
  }
  return (activeDiverId: activeDiverId, diverCount: diverCount);
}

/// The owning profile's name, or a neutral fallback for a profile that is
/// gone or unknown (issue #2594).
String sharedItemOwnerName(
  List<Diver> divers,
  String? ownerId,
  AppLocalizations l10n,
) {
  for (final diver in divers) {
    if (diver.id == ownerId) return diver.name;
  }
  return l10n.sharedItems_ownerUnknown;
}

/// The owner's delete-confirmation line counting the other profiles' dives
/// that will lose the trip or site; null when there are none.
String? otherProfilesDivesLine(
  AppLocalizations l10n,
  SharedItemKind kind,
  int count,
) {
  if (count <= 0) return null;
  return switch (kind) {
    SharedItemKind.trip => l10n.sharedItems_otherProfilesDives_trip(count),
    SharedItemKind.site => l10n.sharedItems_otherProfilesDives_site(count),
  };
}

/// A bulk-delete confirmation's lines: what is deleted (and how many of
/// those are shared, so deleted for every profile), and what is only
/// removed from the active profile. An empty half has no line.
List<String> bulkDeleteLines(
  AppLocalizations l10n,
  SharedItemKind kind, {
  required int deleteCount,
  required int hideCount,
  int sharedDeleteCount = 0,
}) => [
  if (deleteCount > 0)
    switch (kind) {
      SharedItemKind.trip => l10n.sharedItems_bulkDeleteCount_trips(
        deleteCount,
      ),
      SharedItemKind.site => l10n.sharedItems_bulkDeleteCount_sites(
        deleteCount,
      ),
    },
  if (deleteCount > 0 && sharedDeleteCount > 0)
    switch (kind) {
      SharedItemKind.trip => l10n.sharedItems_bulkSharedWarning_trips(
        sharedDeleteCount,
      ),
      SharedItemKind.site => l10n.sharedItems_bulkSharedWarning_sites(
        sharedDeleteCount,
      ),
    },
  if (hideCount > 0)
    switch (kind) {
      SharedItemKind.trip => l10n.sharedItems_bulkHideCount_trips(hideCount),
      SharedItemKind.site => l10n.sharedItems_bulkHideCount_sites(hideCount),
    },
];

/// Confirms hiding another profile's shared trip or site from the active
/// profile only (issue #2594). True when confirmed.
Future<bool> confirmRemoveFromProfile(
  BuildContext context, {
  required String name,
  required String ownerName,
  required int ownDiveCount,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.sharedItems_removeTitle(name)),
        content: Text(
          [
            ctx.l10n.sharedItems_removeBody(ownerName),
            if (ownDiveCount > 0)
              ctx.l10n.sharedItems_removeOwnDives(ownDiveCount),
            ctx.l10n.sharedItems_removeRestoreHint,
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.common_action_remove),
          ),
        ],
      ),
    ) ??
    false;
