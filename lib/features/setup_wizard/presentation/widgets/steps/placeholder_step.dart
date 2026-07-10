import 'package:flutter/material.dart';

/// Temporary stand-in for steps implemented in later tasks.
class PlaceholderStep extends StatelessWidget {
  final String title;

  const PlaceholderStep({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
