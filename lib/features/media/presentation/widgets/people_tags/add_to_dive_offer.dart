import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/person_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// After tagging a buddy who is not logged on the photo's dive, offers to
/// log them there (issue #1745): a snackbar with an Add action that adds
/// them in the plain buddy role. Ignoring it leaves the dive alone; tags
/// and dive buddies stay independent facts.
///
/// Nothing is offered for Me, for media with no dive, or for a buddy
/// already on the dive. [onAdd], when given, takes the Add instead of
/// writing it.
///
/// Returns the offer while it is shown, so its caller can close it when an
/// Add would no longer land anywhere; null when nothing was offered.
Future<ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?>
offerAddToDive(
  BuildContext context,
  WidgetRef ref, {
  required String? diveId,
  required PersonChoice choice,
  void Function(Buddy buddy)? onAdd,
}) async {
  if (diveId == null || choice is! BuddyChoice) return null;
  final repository = ref.read(buddyRepositoryProvider);
  final onDive = await repository.getBuddiesForDive(diveId);
  if (onDive.any((b) => b.buddy.id == choice.buddy.id)) return null;
  if (!context.mounted) return null;
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final failed = l10n.media_people_addToDiveFailed;
  Future<void> add() async {
    try {
      // An empty role list means the Buddy role.
      await repository.addBuddyToDiveWithRoles(
        diveId,
        choice.buddy.id,
        const [],
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to add a buddy to the dive',
        error: e,
        stackTrace: stackTrace,
      );
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.media_people_addToDiveOffer(choice.buddy.name)),
      persist: false,
      action: SnackBarAction(
        label: l10n.media_people_addToDiveAction,
        // In a photo's sitting the Add is held until Save (issue #4527).
        onPressed: onAdd == null
            ? () => unawaited(add())
            : () => onAdd(choice.buddy),
      ),
    ),
  );
}

const _log = LoggerService('AddToDiveOffer');
