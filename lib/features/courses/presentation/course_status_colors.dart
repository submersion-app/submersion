import 'package:flutter/material.dart';

/// Colours for the course status card (completed vs in progress).
///
/// These exist because the status card used to pass [Card] a translucent
/// colour (`Colors.green.withValues(alpha: 0.1)`). The app's cards are
/// elevated and set no `surfaceTintColor`, so the Material 3 elevation tint
/// and the drop shadow composited *through* the translucent interior. In
/// light themes that turned the "completed" green into a grey wash, and in
/// the themes that supply their own card colour it discarded that colour
/// entirely.
///
/// The fix is to blend the status tint onto an opaque theme surface here and
/// hand [Card] a fully opaque result. [ColorScheme.surfaceContainerLow] is the
/// blend base because the bundled themes assign their own card colour to
/// exactly that role, so the outcome reads as "this theme's card, tinted".

/// Alpha of the status tint blended over the card surface. Low enough to stay
/// recognisably the theme's card material, high enough to be visible.
const double _tintAlpha = 0.12;

/// Green used for the completed state, chosen per brightness so it keeps
/// contrast against the surface it sits on. Material's default `Colors.green`
/// is too light to read as text on a pale surface and too saturated on a dark
/// one, so each brightness gets its own shade.
const Color _completedLight = Color(0xFF2E7D32); // green shade 800
const Color _completedDark = Color(0xFF81C784); // green shade 300

Color _accent(ColorScheme scheme, {required bool completed}) {
  if (!completed) return scheme.primary;
  return scheme.brightness == Brightness.light
      ? _completedLight
      : _completedDark;
}

/// Opaque background for the course status card.
Color courseStatusSurface(ColorScheme scheme, {required bool completed}) {
  final tint = _accent(scheme, completed: completed);
  return Color.alphaBlend(
    tint.withValues(alpha: _tintAlpha),
    scheme.surfaceContainerLow,
  );
}

/// Icon and title colour for the course status card, contrasting with
/// [courseStatusSurface] for the same state.
Color courseStatusAccent(ColorScheme scheme, {required bool completed}) =>
    _accent(scheme, completed: completed);
