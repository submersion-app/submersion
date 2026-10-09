import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The "from your profile" / "differs from your profile, reset" caption
/// shared by every profile-backed override control (ppO2 limits, END limit,
/// O2-narcotic) across the MOD and Best Mix calculators.
class ProfileOverrideCaption extends StatelessWidget {
  const ProfileOverrideCaption({
    super.key,
    required this.isOverridden,
    required this.profileValueText,
    required this.onReset,
  });

  final bool isOverridden;

  /// The profile's own value, already formatted for display.
  final String profileValueText;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(
            isOverridden ? Icons.edit : Icons.person_outline,
            size: 16,
            color: isOverridden
                ? colorScheme.tertiary
                : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isOverridden
                  ? l10n.gasCalculators_differsFromProfile(profileValueText)
                  : l10n.gasCalculators_mod_fromProfile,
              style: textTheme.bodySmall?.copyWith(
                color: isOverridden
                    ? colorScheme.tertiary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (isOverridden)
            TextButton(
              onPressed: onReset,
              child: Text(l10n.gasCalculators_mod_useProfileValue),
            ),
        ],
      ),
    );
  }
}
