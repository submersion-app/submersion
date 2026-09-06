import 'package:flutter/material.dart';

import 'package:submersion/features/auto_update/domain/entities/build_train.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Whether this launch should show the beta-build warning.
///
/// A beta binary reached by direct download from the beta-builds repository
/// never passes through the in-app channel picker, so its user has never seen
/// the warning that switching to beta carries: a beta build may upgrade the
/// dive log's database ahead of stable, and stable will then refuse to open it
/// (#1568). This is the one moment that text can reach them.
///
/// Pure, and separate from [showBetaBuildNotice], so the decision can be
/// tested without a widget tree.
bool shouldShowBetaBuildNotice({
  required BuildTrain train,
  required bool alreadySeen,
}) => train == BuildTrain.beta && !alreadySeen;

/// Show the beta-build warning, reusing the channel picker's wording.
///
/// The body is deliberately the same string the picker shows before switching
/// to beta (`settings_updates_betaDialogBody`): one text to
/// keep accurate, and a user who arrives by either route reads the same
/// promise about backups and about sync partners sharing a channel. Only the
/// framing differs, because here the choice has already been made.
Future<void> showBetaBuildNotice(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.science_outlined),
      title: Text(ctx.l10n.settings_updates_betaBuildNoticeTitle),
      content: Text(
        '${ctx.l10n.settings_updates_betaBuildNoticeIntro}\n\n'
        '${ctx.l10n.settings_updates_betaDialogBody}',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
        ),
      ],
    ),
  );
}
