import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The name shown for a dive's own diver beside their roles on the dive: in
/// the dive detail Buddies card, on the edit view's Me chip and on the
/// detailed PDF's Team row (#4458). Their name, or the localized "Me" when
/// there is no diver or their name is blank.
String diveOwnerLabel(Diver? diver, AppLocalizations l10n) {
  final name = diver?.name.trim() ?? '';
  return name.isEmpty ? l10n.buddies_picker_me : name;
}

/// [diver] when they own a dive whose owner is [diveOwnerId] (a dive with no
/// owner counts as theirs), otherwise null.
///
/// For a document made for one diver, such as the detailed PDF logbook: a
/// dive owned by another profile, a sibling logged with theirs (#2002), is
/// not labelled with their name.
Diver? diverIfOwner(String? diveOwnerId, Diver? diver) =>
    diveOwnerId == null || diveOwnerId == diver?.id ? diver : null;
