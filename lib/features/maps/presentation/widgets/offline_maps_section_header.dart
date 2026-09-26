import 'package:flutter/material.dart';

/// Heading for one of the Offline Maps page's top-level sections (map tiles,
/// 3D terrain).
///
/// One size above the sub-headings each section uses for its own groups, so
/// the page reads as two sections rather than one flat list of groups.
class OfflineMapsSectionHeader extends StatelessWidget {
  const OfflineMapsSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
