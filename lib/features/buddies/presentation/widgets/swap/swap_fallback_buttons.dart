import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The other ways to swap, under the nearby list (issue #3728). Each is a
/// callback; the page decides what it does.
class SwapFallbackButtons extends StatelessWidget {
  const SwapFallbackButtons({
    super.key,
    required this.onShowCode,
    required this.onScanCode,
    required this.onSendFile,
    required this.onOpenFile,
    required this.onWriteSticker,
    required this.onReadTag,
  });

  final VoidCallback onShowCode;
  final VoidCallback onScanCode;

  /// Gets the button's screen rectangle, for the iPad share popover.
  final ValueChanged<Rect?> onSendFile;
  final VoidCallback onOpenFile;
  final VoidCallback onWriteSticker;
  final VoidCallback onReadTag;

  static bool get _isPhone =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget button(IconData icon, String label, VoidCallback onPressed) =>
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          button(Icons.qr_code, l10n.buddySwap_action_showCode, onShowCode),
          button(
            Icons.qr_code_scanner,
            l10n.buddySwap_action_scanCode,
            onScanCode,
          ),
          // A Builder gives the button its own context, for the anchor.
          Builder(
            builder: (buttonContext) => button(
              Icons.ios_share,
              l10n.buddySwap_action_sendFile,
              () => onSendFile(shareAnchorFrom(buttonContext)),
            ),
          ),
          button(
            Icons.file_open_outlined,
            l10n.buddySwap_action_openFile,
            onOpenFile,
          ),
          if (_isPhone)
            button(
              Icons.nfc,
              l10n.buddySwap_action_writeSticker,
              onWriteSticker,
            ),
          if (defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb)
            button(
              Icons.tap_and_play,
              l10n.buddySwap_action_tapAndroid,
              onReadTag,
            ),
          if (defaultTargetPlatform == TargetPlatform.android && !kIsWeb)
            button(
              Icons.tap_and_play,
              l10n.buddySwap_action_receiveByTap,
              onReadTag,
            ),
        ],
      ),
    );
  }
}
