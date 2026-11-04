import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('ClipboardCopy');

const Duration _messageDuration = Duration(seconds: 2);

/// The latest confirmation per messenger: a sheet has its own, and what one
/// messenger shows says nothing about another.
final _confirmations = Expando<_Confirmation>();

/// Puts [text] on the clipboard and confirms it in the nearest
/// [ScaffoldMessenger], or says to try again when the clipboard refuses.
///
/// Shared by every copy control (issues #3362, #3629), so they confirm alike.
Future<void> copyToClipboardWithConfirmation(
  BuildContext context,
  String text,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    await Clipboard.setData(ClipboardData(text: text));
  } on PlatformException catch (e, stackTrace) {
    _log.error(
      'Could not copy to the clipboard',
      error: e,
      stackTrace: stackTrace,
    );
    // A sheet's messenger can go while the clipboard answers.
    if (messenger.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.common_error_tryAgain)),
      );
    }
    return;
  }
  unawaited(HapticFeedback.mediumImpact());
  if (messenger.mounted) {
    _confirm(messenger, l10n.common_snackbar_copiedToClipboard);
  }
}

/// Shows the confirmation in [messenger], without a pile-up: one on screen is
/// replaced, and one still waiting behind another message stands.
///
/// Only the message's own confirmation is ever closed, because the current
/// message could be someone's Undo. A waiting one holds off a new one only for
/// [_messageDuration], because `clearSnackBars` can drop it without closing
/// it, and that must not silence every later copy.
void _confirm(ScaffoldMessengerState messenger, String text) {
  final latest = _confirmations[messenger];
  if (latest != null) {
    if (latest.visible) {
      messenger.hideCurrentSnackBar();
    } else if (clock.now().difference(latest.raisedAt) < _messageDuration) {
      return;
    }
  }

  final confirmation = _Confirmation(clock.now());
  _confirmations[messenger] = confirmation;
  final message = messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      duration: _messageDuration,
      onVisible: () => confirmation.visible = true,
    ),
  );
  unawaited(
    message.closed.whenComplete(() {
      if (identical(_confirmations[messenger], confirmation)) {
        _confirmations[messenger] = null;
      }
    }),
  );
}

/// A confirmation raised in a messenger, which cannot be asked what it holds.
class _Confirmation {
  _Confirmation(this.raisedAt);

  final DateTime raisedAt;

  /// False while it waits behind another message.
  bool visible = false;
}
