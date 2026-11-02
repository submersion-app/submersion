import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(CopyableDetailRow);

/// Makes a detail row copyable: a long press anywhere on it, or the copy
/// button at its far edge, puts [copyValue] on the clipboard (issue #3362).
///
/// The button sits over the row rather than in a column of its own, because
/// the row's label column is a share of the row's whole width: narrowing the
/// row would move its value off the column it shares with its neighbours.
/// [child] reserves [buttonWidth] at the end of its value instead.
///
/// [child] reads as one [semanticsLabel] node, with the button after it.
class CopyableDetailRow extends StatelessWidget {
  const CopyableDetailRow({
    super.key,
    required this.copyValue,
    required this.semanticsLabel,
    required this.buttonHeight,
    required this.child,
  });

  /// The width of the button, which the row keeps clear of its value.
  static const double buttonWidth = 36;

  static const double _iconSize = 18;
  static const Duration _messageDuration = Duration(seconds: 2);

  /// The latest confirmation per messenger: a sheet has its own, and what
  /// one messenger shows says nothing about another.
  static final _confirmations = Expando<_Confirmation>();

  final String copyValue;
  final String semanticsLabel;

  /// As tall as the row's first line with its padding, so the button fills
  /// that line and a wrapped value leaves it beside the label.
  final double buttonHeight;
  final Widget child;

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await Clipboard.setData(ClipboardData(text: copyValue));
    } on PlatformException catch (e, stackTrace) {
      _log.error(
        'Could not copy to the clipboard',
        error: e,
        stackTrace: stackTrace,
      );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.common_error_tryAgain)),
      );
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    _confirm(messenger, l10n.common_snackbar_copiedToClipboard);
  }

  /// Shows the confirmation in [messenger], without a pile-up: one on screen
  /// is replaced, and one still waiting behind another message stands.
  ///
  /// Only the message's own confirmation is ever closed, because the current
  /// message could be someone's Undo. A waiting one holds off a new one only
  /// for [_messageDuration], because `clearSnackBars` can drop it without
  /// closing it, and that must not silence every later copy.
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    void copy() => unawaited(_copy(context));

    return Stack(
      children: [
        Semantics(
          label: semanticsLabel,
          onLongPress: copy,
          onLongPressHint: l10n.common_action_copy,
          excludeSemantics: true,
          child: InkWell(
            onLongPress: copy,
            // The haptic is ours, so Android does not get a second one.
            enableFeedback: false,
            // Only a long press does anything, so to a mouse or a keyboard
            // the row stays plain text and the button is the way in.
            mouseCursor: SystemMouseCursors.basic,
            hoverColor: Colors.transparent,
            canRequestFocus: false,
            borderRadius: BorderRadius.circular(8),
            child: child,
          ),
        ),
        PositionedDirectional(
          top: 0,
          end: 0,
          width: buttonWidth,
          height: buttonHeight,
          child: IconButton(
            tooltip: l10n.common_action_copy,
            onPressed: copy,
            onLongPress: copy,
            enableFeedback: false,
            iconSize: _iconSize,
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            icon: const Icon(Icons.content_copy),
          ),
        ),
      ],
    );
  }
}

/// A confirmation raised in a messenger, which cannot be asked what it holds.
class _Confirmation {
  _Confirmation(this.raisedAt);

  final DateTime raisedAt;

  /// False while it waits behind another message.
  bool visible = false;
}
