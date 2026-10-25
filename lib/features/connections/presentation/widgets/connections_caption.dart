import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_caption_text.dart';

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
    return _HeightReporter(
      onHeight: onHeight,
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
    );
  }
}

class _HeightReporter extends SingleChildRenderObjectWidget {
  const _HeightReporter({required this.onHeight, super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHeightReporter(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHeightReporter renderObject,
  ) => renderObject.onHeight = onHeight;
}

class _RenderHeightReporter extends RenderProxyBox {
  _RenderHeightReporter(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    // Reported after the frame: the listener rebuilds the page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onHeight(height);
    });
  }
}
