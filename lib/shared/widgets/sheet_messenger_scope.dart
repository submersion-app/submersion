import 'package:flutter/material.dart';

/// Gives a modal sheet its own snackbar host (#2365). A snackbar raised from
/// inside a modal bottom sheet otherwise goes to the page's
/// ScaffoldMessenger, which renders it underneath the sheet where the diver
/// never sees it. Transparent and non-resizing, so the sheet's own layout
/// and keyboard handling are unchanged.
class SheetMessengerScope extends StatelessWidget {
  const SheetMessengerScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ScaffoldMessenger(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: child,
    ),
  );
}
