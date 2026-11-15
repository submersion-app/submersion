import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/l10n/l10n_extension.dart';

bool get _isPhone =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

/// The ways to send your card to a buddy (issue #4598). Each row is a
/// callback; the page decides what it does.
class GiveCardGroup extends StatelessWidget {
  const GiveCardGroup({
    super.key,
    required this.onShowCode,
    required this.onSendFile,
    required this.onWriteSticker,
  });

  final VoidCallback onShowCode;

  /// Gets the row's screen rectangle, for the iPad share popover.
  final ValueChanged<Rect?> onSendFile;
  final VoidCallback onWriteSticker;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _MethodGroup(
      heading: l10n.buddySwap_give_heading,
      rows: [
        _MethodRow(
          icon: Icons.qr_code,
          title: l10n.buddySwap_action_showCode,
          hint: l10n.buddySwap_hint_showCode,
          onTap: (_) => onShowCode(),
        ),
        _MethodRow(
          icon: Icons.ios_share,
          title: l10n.buddySwap_action_sendFile,
          hint: l10n.buddySwap_hint_sendFile,
          onTap: (rowContext) => onSendFile(shareAnchorFrom(rowContext)),
        ),
        if (_isPhone)
          _MethodRow(
            icon: Icons.nfc,
            title: l10n.buddySwap_action_writeSticker,
            hint: l10n.buddySwap_hint_writeSticker,
            onTap: (_) => onWriteSticker(),
          ),
      ],
    );
  }
}

/// The ways to receive a buddy's card (issue #4598).
class GetCardGroup extends StatelessWidget {
  const GetCardGroup({
    super.key,
    required this.onScanCode,
    required this.onOpenFile,
    required this.onReadTag,
  });

  final VoidCallback onScanCode;
  final VoidCallback onOpenFile;
  final VoidCallback onReadTag;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return _MethodGroup(
      heading: l10n.buddySwap_get_heading,
      rows: [
        _MethodRow(
          icon: Icons.qr_code_scanner,
          title: l10n.buddySwap_action_scanCode,
          hint: l10n.buddySwap_hint_scanCode,
          onTap: (_) => onScanCode(),
        ),
        _MethodRow(
          icon: Icons.file_open_outlined,
          title: l10n.buddySwap_action_openFile,
          hint: l10n.buddySwap_hint_openFile,
          onTap: (_) => onOpenFile(),
        ),
        // iPhones can read a card an Android phone presents, but cannot
        // present one themselves.
        if (ios)
          _MethodRow(
            icon: Icons.tap_and_play,
            title: l10n.buddySwap_action_tapAndroid,
            hint: l10n.buddySwap_hint_tapAndroid,
            onTap: (_) => onReadTag(),
          ),
        if (android)
          _MethodRow(
            icon: Icons.tap_and_play,
            title: l10n.buddySwap_action_receiveByTap,
            hint: l10n.buddySwap_hint_receiveByTap,
            onTap: (_) => onReadTag(),
          ),
      ],
    );
  }
}

class _MethodGroup extends StatelessWidget {
  const _MethodGroup({required this.heading, required this.rows});

  final String heading;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(heading, style: Theme.of(context).textTheme.labelLarge),
        ),
        ...rows,
      ],
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String hint;

  /// Gets the row's own context, for anchoring a share popover.
  final ValueChanged<BuildContext> onTap;

  @override
  Widget build(BuildContext context) {
    // A Builder gives the tile its own context: shareAnchorFrom then finds
    // the tile's rectangle, not the group's.
    return Builder(
      builder: (rowContext) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(hint),
        onTap: () => onTap(rowContext),
      ),
    );
  }
}
