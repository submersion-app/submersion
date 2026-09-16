import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/widgets/diver_switcher_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// The active diver's avatar in the dashboard hero, tappable to switch diver.
///
/// Before this the only ways to change the active profile were a row buried
/// in Settings > Diver Profile and a desktop-only keyboard shortcut. The
/// dashboard greeting already names the diver, so the avatar beside it is
/// where a second-profile user looks first.
///
/// Rendered only once a second profile exists: with one profile there is
/// nothing to switch to, and the header stays exactly as it was. A small swap
/// badge marks the avatar as a control rather than decoration. The widget
/// owns the gap to the greeting, so it collapses to nothing when hidden.
class HeroDiverAvatar extends ConsumerWidget {
  const HeroDiverAvatar({super.key});

  /// Touch target. The visual avatar is smaller ([_radius] * 2) so the
  /// greeting keeps a single line on a 390-wide phone; the difference is
  /// transparent hit area.
  static const double tapSize = 44;
  static const double _radius = 18;
  static const double _badgeSize = 16;
  static const double _gap = 8;

  /// Darkest tone of the ocean gradient; the badge glyph and its ring use it
  /// so the white disc reads on both the light (cyan) and dark (navy) hero.
  static const Color _oceanDeep = Color(0xFF0B2540);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Counted in SQL and self-invalidating on divers-table writes, so adding
    // a second profile reveals the avatar without a restart. Unknown (still
    // loading) counts as one: most users have a single profile, and they
    // must never see the greeting jump.
    final diverCount = ref.watch(diverCountProvider).value ?? 1;
    if (diverCount < 2) return const SizedBox.shrink();

    // `value`, not the project's `valueOrNull` polyfill: switching diver
    // re-runs the provider through its watched id, and the polyfill returns
    // null for that reload, which would blank the avatar for a frame or two.
    // `value` keeps the previous diver until the new one has loaded.
    final diver = ref.watch(dashboardDiverProvider).value;
    // Reserve the slot on first load so the greeting does not jump right
    // when the avatar lands.
    if (diver == null) {
      return const SizedBox(width: tapSize + _gap, height: tapSize);
    }

    final label = context.l10n.settings_profileHub_switchDiver;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: _gap),
      child: _button(context, diver, label),
    );
  }

  Widget _button(BuildContext context, Diver diver, String label) {
    return IconButton(
      tooltip: label,
      onPressed: () => showDiverSwitcherSheet(context),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(tapSize),
        fixedSize: const Size.square(tapSize),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          ProfileAvatar(
            photo: diver.photo,
            initials: diver.initials,
            radius: _radius,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            foregroundColor: Colors.white,
            ringColor: Colors.white.withValues(alpha: 0.7),
            textStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: _badgeSize,
              height: _badgeSize,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _oceanDeep, width: 1.5),
              ),
              child: const Icon(Icons.swap_horiz, size: 10, color: _oceanDeep),
            ),
          ),
        ],
      ),
    );
  }
}
