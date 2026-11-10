import 'package:flutter/material.dart';

/// The media viewer's source line (issue #3355): where the current item comes
/// from, such as the check-in a gear photo backs up. A small dark pill so it
/// reads over any photo.
///
/// At most [maxWidthFraction] of the screen wide, one line, ellipsized: it
/// sits across from the colour-correction label below the toolbar, and a
/// long check-in title must not run into it or off a phone's edge.
class MediaViewerCaption extends StatelessWidget {
  const MediaViewerCaption({super.key, required this.text});

  final String text;

  static const double maxWidthFraction = 0.6;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxWidth: MediaQuery.sizeOf(context).width * maxWidthFraction,
    ),
    child: Container(
      key: const ValueKey('viewer_caption'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: Colors.white),
      ),
    ),
  );
}
