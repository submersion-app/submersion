import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/feature_accent_colors.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

/// The three user-toggleable surfaces that can show feature accent colors.
enum AccentSurface { nav, header, list }

/// Resolves the accent color for [featureId] on [surface], or null when the
/// surface's toggle is off or the palette has no entry. Callers treat null as
/// "use the ambient color", so every failure mode degrades to the appearance
/// the app had before accents existed.
Color? resolveFeatureAccent(
  BuildContext context,
  WidgetRef ref, {
  required AccentSurface surface,
  required String featureId,
}) {
  final enabled = switch (surface) {
    AccentSurface.nav => ref.watch(accentNavIconsProvider),
    AccentSurface.header => ref.watch(accentSectionHeadersProvider),
    AccentSurface.list => ref.watch(accentListIconsProvider),
  };
  if (!enabled) return null;
  return Theme.of(context).extension<FeatureAccentColors>()?.of(featureId);
}

/// An [Icon] tinted with its feature's accent color when the surface's toggle
/// is enabled; otherwise identical to a plain [Icon].
class FeatureAccentIcon extends ConsumerWidget {
  const FeatureAccentIcon(
    this.icon, {
    super.key,
    required this.featureId,
    required this.surface,
    this.size,
  });

  final IconData icon;
  final String featureId;
  final AccentSurface surface;
  final double? size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolveFeatureAccent(
      context,
      ref,
      surface: surface,
      featureId: featureId,
    );
    return Icon(icon, color: color, size: size);
  }
}

/// An app-bar title that prefixes the feature's filled nav icon, accent
/// tinted, when the section-headers toggle is on; plain [Text] otherwise.
///
/// Takes a pre-localized [title] so this shared widget never resolves l10n
/// itself -- consumers keep their own strings and their tests need no extra
/// localization delegates.
class FeatureAppBarTitle extends ConsumerWidget {
  const FeatureAppBarTitle({
    super.key,
    required this.featureId,
    required this.title,
  });

  final String featureId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = resolveFeatureAccent(
      context,
      ref,
      surface: AccentSurface.header,
      featureId: featureId,
    );
    if (color == null) return Text(title);

    NavDestination? destination;
    for (final candidate in kNavDestinations) {
      if (candidate.id == featureId) {
        destination = candidate;
        break;
      }
    }
    if (destination == null) return Text(title);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(destination.selectedIcon, color: color),
        const SizedBox(width: 8),
        Flexible(child: Text(title)),
      ],
    );
  }
}
