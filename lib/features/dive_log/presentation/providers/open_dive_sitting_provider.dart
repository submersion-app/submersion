import 'package:flutter/foundation.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The dive page's open sitting, for what reaches the dive from outside
/// the page: a file dropped on it (issue #4527, plan 6). Set by the page
/// while the dive is unlocked, cleared when it locks or the page goes.
@immutable
class OpenDiveSitting {
  const OpenDiveSitting({
    required this.diveId,
    required this.session,
    required this.showMediaCard,
  });

  final String diveId;
  final EditSession<Dive> session;

  /// Brings the Media card into view as its editor, so a held drop shows.
  final VoidCallback showMediaCard;
}

final openDiveSittingProvider = StateProvider<OpenDiveSitting?>((ref) => null);

/// What a media file dropped on a dive does.
enum DiveDropAnswer {
  /// Held in the dive's open sitting until Save.
  hold,

  /// Refused with a hint to unlock the dive: it is locked, being saved, or
  /// another dive is the one unlocked.
  refuse,
}

/// The answer for a drop on [diveId], given the [open] sitting.
DiveDropAnswer diveDropAnswer({
  required OpenDiveSitting? open,
  required String diveId,
}) {
  if (open == null || open.diveId != diveId) return DiveDropAnswer.refuse;
  final session = open.session;
  if (session.isDisposed || session.isFrozen) return DiveDropAnswer.refuse;
  return DiveDropAnswer.hold;
}
