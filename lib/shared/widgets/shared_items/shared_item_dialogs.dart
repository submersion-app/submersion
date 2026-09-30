import 'package:flutter/material.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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
