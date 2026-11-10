import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/info_sheet/info_content.dart';
import 'package:submersion/shared/widgets/info_sheet/info_sheet.dart';

export 'package:submersion/shared/widgets/info_sheet/info_content.dart';

/// The discreet "i" at the far right of a card header.
///
/// [content] runs when the icon is tapped, not when the card builds, so the
/// sheet lists what the card shows at that moment.
class InfoButton extends StatelessWidget {
  const InfoButton({super.key, required this.title, required this.content});

  /// The card's title, read out as "About {title}".
  final String title;

  final InfoContentBuilder content;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.info_button_semantics(title);
    // The tooltip stays out of semantics: the icon's label already says it,
    // and a screen reader would read it twice.
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: IconButton(
        icon: Icon(
          Icons.info_outline,
          size: 18,
          color: Theme.of(context).colorScheme.outline,
          semanticLabel: label,
        ),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        padding: EdgeInsets.zero,
        onPressed: () => showInfoSheet(context, content(context)),
      ),
    );
  }
}

/// An [InfoButton] for a header row, laid out [height] tall so the row keeps
/// its height.
///
/// The 48 px button overflows the slot, so its splash and focus ring look as
/// usual; taps land within the slot's [width] and [height], the title line the
/// icon sits on.
class HeaderInfoButton extends StatelessWidget {
  const HeaderInfoButton({
    super.key,
    required this.title,
    required this.content,
    this.height = 24,
    this.width = 48,
  });

  final String title;
  final InfoContentBuilder content;

  /// The height of the header's title line.
  final double height;

  /// The slot's width: 48 by default, or a row's shared control width where
  /// the header lines up a set of equal icon buttons.
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: OverflowBox(
        maxWidth: 48,
        maxHeight: 48,
        child: InfoButton(title: title, content: content),
      ),
    );
  }
}

/// A header's [title] with its info icon at the end, the title taking the
/// rest of the row. Without [info] it returns [title] alone.
class InfoTitleRow extends StatelessWidget {
  const InfoTitleRow({
    super.key,
    required this.title,
    required this.label,
    required this.info,
    this.height = 24,
  });

  /// The header's title widget, usually its text.
  final Widget title;

  /// The name the icon is read out with, "About {label}".
  final String label;

  final InfoContentBuilder? info;

  /// The height of the title line, passed to [HeaderInfoButton].
  final double height;

  @override
  Widget build(BuildContext context) {
    final builder = info;
    if (builder == null) return title;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        HeaderInfoButton(title: label, content: builder, height: height),
      ],
    );
  }
}

/// Puts an info icon in the top end corner of a block with no header of its
/// own, such as a grid of stat tiles. Without [info] it returns [child].
class InfoCorner extends StatelessWidget {
  const InfoCorner({
    super.key,
    required this.title,
    required this.child,
    this.info,
  });

  final String title;
  final Widget child;
  final InfoContentBuilder? info;

  @override
  Widget build(BuildContext context) {
    final builder = info;
    if (builder == null) return child;
    return Stack(
      children: [
        child,
        PositionedDirectional(
          top: 0,
          end: 0,
          child: HeaderInfoButton(title: title, content: builder),
        ),
      ],
    );
  }
}
