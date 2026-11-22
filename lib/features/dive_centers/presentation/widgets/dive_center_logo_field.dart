import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_avatar.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The tappable logo at the top of the dive center header editor (#4460): the
/// logo or the store icon in a rounded square, as the list and the detail
/// header draw it, with the buddy photo's camera badge.
class DiveCenterLogoField extends StatefulWidget {
  const DiveCenterLogoField({
    super.key,
    required this.logo,
    required this.onTap,
  });

  /// The ring drawn around the logo while it holds keyboard focus.
  @visibleForTesting
  static const focusRingKey = ValueKey('dive-center-logo-focus-ring');

  final Uint8List? logo;
  final VoidCallback onTap;

  @override
  State<DiveCenterLogoField> createState() => _DiveCenterLogoFieldState();
}

class _DiveCenterLogoFieldState extends State<DiveCenterLogoField> {
  static const _ringWidth = 3.0;
  static const _cornerRadius = 16.0;

  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Semantics(
        button: true,
        label: context.l10n.diveCenters_field_logo,
        // An InkWell rather than a GestureDetector, so the logo takes keyboard
        // focus and Enter or Space opens the picker on desktop and web. Its
        // own focus highlight paints under the opaque logo, so the ring below
        // shows focus instead.
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: (focused) => setState(() => _focused = focused),
          borderRadius: BorderRadius.circular(_cornerRadius + _ringWidth),
          child: DecoratedBox(
            key: DiveCenterLogoField.focusRingKey,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_cornerRadius + _ringWidth),
              border: _focused
                  ? Border.all(color: colors.primary, width: _ringWidth)
                  : null,
            ),
            // Always padded, so gaining focus does not move the logo.
            child: Padding(
              padding: const EdgeInsets.all(_ringWidth),
              child: Stack(
                children: [
                  DiveCenterAvatar(
                    logo: widget.logo,
                    radius: 50,
                    shape: DiveCenterAvatarShape.roundedSquare,
                    cornerRadius: _cornerRadius,
                    iconSize: 48,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: ExcludeSemantics(
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: colors.primary,
                        child: Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: colors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
