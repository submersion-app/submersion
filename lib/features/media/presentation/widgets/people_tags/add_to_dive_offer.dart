import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/person_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// After tagging a buddy who is not logged on the photo's dive, offers to
/// log them there (issue #1745): a snackbar with an Add action, which
/// [onAdd] takes; in a photo's sitting it is held until Save (issue #4527).
/// Ignoring it leaves the dive alone; tags and dive buddies stay
/// independent facts.
///
/// Nothing is offered for Me, for media with no dive, or for a buddy
/// already on the dive.
///
/// Returns the offer while it is shown, so its caller can close it when an
/// Add would no longer land anywhere; null when nothing was offered.
Future<ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?>
offerAddToDive(
  BuildContext context,
  WidgetRef ref, {
  required String? diveId,
  required PersonChoice choice,
  required void Function(Buddy buddy) onAdd,
}) async {
  if (diveId == null || choice is! BuddyChoice) return null;
  final repository = ref.read(buddyRepositoryProvider);
  final onDive = await repository.getBuddiesForDive(diveId);
  if (onDive.any((b) => b.buddy.id == choice.buddy.id)) return null;
  if (!context.mounted) return null;
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.media_people_addToDiveOffer(choice.buddy.name)),
      persist: false,
      action: SnackBarAction(
        label: l10n.media_people_addToDiveAction,
        onPressed: () => onAdd(choice.buddy),
      ),
    ),
  );
}
