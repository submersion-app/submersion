import 'package:flutter/material.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// The avatar for a dive's own diver, beside their roles on the dive: in the
/// dive detail Buddies card and on the edit view's Me chip (#4458).
///
/// Shows the diver's photo when they have one. Otherwise it keeps the generic
/// person icon rather than initials, which is how this row has always looked;
/// only a real photo changes it.
class DiveOwnerAvatar extends StatelessWidget {
  const DiveOwnerAvatar({super.key, required this.diver, this.iconSize});

  /// The dive's owner, or null when none resolves.
  final Diver? diver;

  /// The person icon's size; null for the [Icon] default.
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final owner = diver;
    final photo = owner?.photo;
    if (owner != null && photo != null) {
      return ProfileAvatar(
        photo: photo,
        initials: owner.initials,
        backgroundColor: colorScheme.primaryContainer,
      );
    }
    return CircleAvatar(
      backgroundColor: colorScheme.primaryContainer,
      child: Icon(
        Icons.person,
        size: iconSize,
        color: colorScheme.onPrimaryContainer,
      ),
    );
  }
}

/// The name shown for a dive's own diver: their name, or the localized "Me"
/// when there is no diver or their name is blank.
String diveOwnerLabel(Diver? diver, AppLocalizations l10n) {
  final name = diver?.name.trim() ?? '';
  return name.isEmpty ? l10n.buddies_picker_me : name;
}
