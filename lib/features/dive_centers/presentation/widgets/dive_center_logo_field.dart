import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_avatar.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The tappable logo at the top of the dive center edit page (#4460): the
/// logo or the store icon in a rounded square, as the list and the detail
/// header draw it, with the buddy edit page's camera badge.
class DiveCenterLogoField extends StatelessWidget {
  const DiveCenterLogoField({
    super.key,
    required this.logo,
    required this.onTap,
  });

  final Uint8List? logo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Semantics(
        button: true,
        label: context.l10n.diveCenters_field_logo,
        // An InkWell rather than a GestureDetector, so the logo takes keyboard
        // focus and Enter or Space opens the picker on desktop and web.
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              DiveCenterAvatar(
                logo: logo,
                radius: 50,
                shape: DiveCenterAvatarShape.roundedSquare,
                cornerRadius: 16,
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
    );
  }
}
