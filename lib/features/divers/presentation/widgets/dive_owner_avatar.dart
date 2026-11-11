import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/dive_owner_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// Whether a dive's owner (from `diveOwnerProvider`) is still on its first
/// load, with nothing to show yet.
///
/// Screens draw a neutral placeholder for the owner meanwhile, rather than
/// "Me" and the person icon they would swap out a moment later, and without
/// holding back anything else on screen: a lookup that keeps failing can sit
/// in loading through Riverpod's retries. A refresh keeps the last value, so
/// this is only ever the first load.
bool isDiveOwnerPending(AsyncValue<Diver?> owner) =>
    owner.isLoading && !owner.hasValue && !owner.hasError;

/// The name of a dive's own diver beside their roles: see [diveOwnerLabel].
///
/// While [pending] it is an empty line, which keeps its height so nothing
/// moves when the name arrives, and still reads "Me" to a screen reader so
/// the roles beside it are not announced without a subject.
class DiveOwnerName extends StatelessWidget {
  const DiveOwnerName({super.key, required this.diver, this.pending = false});

  final Diver? diver;

  /// See [isDiveOwnerPending].
  final bool pending;

  @override
  Widget build(BuildContext context) {
    if (pending) {
      return Text('', semanticsLabel: context.l10n.buddies_picker_me);
    }
    return Text(diveOwnerLabel(diver, context.l10n));
  }
}

/// The avatar for a dive's own diver, beside their roles on the dive: in the
/// dive detail Buddies card and on the edit view's Me chip (#4458).
///
/// Shows the diver's photo when they have one. Otherwise it keeps the generic
/// person icon rather than initials, which is how this row has always looked;
/// only a real photo changes it. While [pending], it is a blank circle of the
/// same size.
class DiveOwnerAvatar extends StatelessWidget {
  const DiveOwnerAvatar({
    super.key,
    required this.diver,
    this.iconSize,
    this.pending = false,
  });

  /// The dive's owner, or null when none resolves.
  final Diver? diver;

  /// The person icon's size; null for the [Icon] default.
  final double? iconSize;

  /// See [isDiveOwnerPending].
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (diver case Diver(photo: final photo?, :final initials)) {
      return ProfileAvatar(
        photo: photo,
        initials: initials,
        backgroundColor: colorScheme.primaryContainer,
      );
    }
    return CircleAvatar(
      backgroundColor: colorScheme.primaryContainer,
      child: pending
          ? null
          : Icon(
              Icons.person,
              size: iconSize,
              color: colorScheme.onPrimaryContainer,
            ),
    );
  }
}
