import 'package:flutter/material.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_caption_text.dart';
import 'package:submersion/shared/widgets/size_reporter.dart';

/// The card at the top of the canvas naming the map and saying how to read
/// it. The sentence wraps rather than being cut short, so the card's height
/// varies; it reports that height so the overlays below it can move down.
class ConnectionsCaption extends StatelessWidget {
  const ConnectionsCaption({
    super.key,
    required this.text,
    required this.onHeight,
  });

  final ConnectionsCaptionText text;

  /// Called after layout whenever the card's height changes.
  final ValueChanged<double> onHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizeReporter(
      onChange: (size) => onHeight(size.height),
      // Read-only: a pan or pinch that starts on it moves the map.
      child: IgnorePointer(
        child: Card(
          key: const ValueKey('connections-caption'),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  text.sentence,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
