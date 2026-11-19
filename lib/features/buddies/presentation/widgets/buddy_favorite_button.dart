import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Favorite-star toggle shared by every buddy surface that offers it: the
/// list tiles, the detail page, and the "Add buddy" picker sheet (issue
/// #1336, extending the picker's own star from issue #638).
///
/// [unselectedColor] lets a list row match its own secondary-text tint;
/// left null, the button inherits the surrounding IconTheme (the app bar's
/// icon color, for instance). The favorite color is always the theme's
/// primary color, unlike the unselected one.
///
/// The tap target has an explicit 32x32 floor regardless of [iconSize] --
/// without it, a small [iconSize] shrinks the button's own hit area to the
/// icon's size, and a near-miss tap falls through to whatever sits behind it
/// (the row's own navigation, in the dense and compact tiles). On touch
/// platforms the theme's padded tap-target size then lifts it to the 48x48
/// Material minimum. The button keeps the standard visual density on
/// purpose: compact density subtracts 8 from both, which left 40x40 on touch
/// and 32x24 on desktop.
class BuddyFavoriteButton extends ConsumerWidget {
  final String buddyId;
  final bool isFavorite;
  final double iconSize;
  final Color? unselectedColor;

  /// Shows whether the buddy is a favourite and writes nothing on a tap:
  /// where buddies edit in place (issue #4527, phase 3), the favourite is
  /// set on the buddy's page, in its sitting.
  final bool readOnly;

  const BuddyFavoriteButton({
    super.key,
    required this.buddyId,
    required this.isFavorite,
    this.iconSize = 24,
    this.unselectedColor,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (readOnly) {
      return Semantics(
        label: isFavorite ? context.l10n.query_buddies_favorite : null,
        child: SizedBox.square(
          dimension: 32,
          child: Center(
            child: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              size: iconSize,
              color: isFavorite
                  ? Theme.of(context).colorScheme.primary
                  : unselectedColor,
            ),
          ),
        ),
      );
    }
    return IconButton(
      icon: Icon(
        isFavorite ? Icons.star : Icons.star_border,
        size: iconSize,
        color: isFavorite
            ? Theme.of(context).colorScheme.primary
            : unselectedColor,
      ),
      tooltip: isFavorite
          ? context.l10n.diveLog_detail_tooltip_removeFromFavorites
          : context.l10n.diveLog_detail_tooltip_addToFavorites,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () =>
          ref.read(buddyListNotifierProvider.notifier).toggleFavorite(buddyId),
    );
  }
}
