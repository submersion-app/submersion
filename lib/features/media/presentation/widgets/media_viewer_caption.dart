import 'package:flutter/material.dart';

/// The media viewer's source line (issue #3355): where the current item comes
/// from, such as the check-in a gear photo backs up. A small dark pill so it
/// reads over any photo.
class MediaViewerCaption extends StatelessWidget {
  const MediaViewerCaption({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('viewer_caption'),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: Colors.white),
    ),
  );
}
