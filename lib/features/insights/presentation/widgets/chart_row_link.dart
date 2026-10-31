import 'package:flutter/material.dart';

/// A chart row that opens the dives behind it in one tap (issue #3805).
class ChartRowLink extends StatelessWidget {
  const ChartRowLink({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(onTap: onTap, child: child),
    );
  }
}
