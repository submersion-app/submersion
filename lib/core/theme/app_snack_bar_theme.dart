import 'package:flutter/material.dart';

/// Snack bar defaults shared by every theme preset.
///
/// A snack bar overlays whatever sits at the bottom of the screen, which
/// routinely means a form's confirm button or a bottom action bar. Material's
/// only built-in escape hatch is a swipe-to-dismiss drag, which is an
/// invisible affordance with a mouse, so on desktop a lingering "undo" snack
/// bar reads as unhideable chrome covering the button underneath it.
///
/// Turning on the close icon at the theme level reaches every snack bar in the
/// app at once: Flutter resolves `SnackBar.showCloseIcon` before falling back
/// to `SnackBarThemeData.showCloseIcon`, so an individual snack bar can still
/// opt out.
ThemeData withAppSnackBarDefaults(ThemeData theme) {
  return theme.copyWith(
    snackBarTheme: theme.snackBarTheme.copyWith(showCloseIcon: true),
  );
}
