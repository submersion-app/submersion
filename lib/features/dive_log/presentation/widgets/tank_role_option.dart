import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A tank role as a Role picker shows it: the glyph the dive's Tanks card
/// draws for that role, then its localized name (issue #2901). Showing the
/// icon where the diver chooses the role is what teaches the icon set.
///
/// Used as a [DropdownMenuItem] child, so it also renders as the field's
/// selected value; the name ellipsizes rather than overflowing a narrow field.
class TankRoleOption extends StatelessWidget {
  const TankRoleOption({super.key, required this.role});

  final TankRole role;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(role.icon, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            role.localizedName(context.l10n),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
