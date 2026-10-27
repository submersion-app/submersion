import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/browser_launch.dart';

/// Opens [uri] with [launch], and when the platform refuses (or throws),
/// tells the diver it could not be opened and offers to copy the link.
///
/// Both halves of the context handling matter. Resolving the messenger and
/// l10n BEFORE the await keeps a BuildContext from being dereferenced across
/// the gap (what the use_build_context_synchronously lint is about), but it
/// does not make the captured ScaffoldMessengerState safe to use afterwards:
/// showSnackBar builds the SnackBar's AnimationController with `vsync: this`,
/// so calling it on a state that was disposed while the platform launch was
/// in flight throws. The mounted check is what covers that.
Future<void> openLinkOrOfferCopy(
  BuildContext context,
  Uri uri, {
  required UrlLaunch launch,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;
  var opened = false;
  try {
    opened = await launch(uri);
  } catch (_) {
    opened = false;
  }
  if (opened || !context.mounted || messenger == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.common_link_couldNotOpen),
      action: SnackBarAction(
        label: l10n.common_action_copyLink,
        onPressed: () => Clipboard.setData(ClipboardData(text: uri.toString())),
      ),
    ),
  );
}
