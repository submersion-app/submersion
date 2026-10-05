import 'package:flutter/material.dart';
import 'package:submersion/features/settings/presentation/conflicts/word_diff.dart';

/// One side's text with the words only on that side highlighted. The
/// highlight is a background and bold weight together, so it does not rely on
/// colour alone.
class ConflictTextDiff extends StatelessWidget {
  const ConflictTextDiff({
    super.key,
    required this.spans,
    required this.highlight,
    required this.onHighlight,
  });

  final List<DiffSpan> spans;
  final Color highlight;
  final Color onHighlight;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: Theme.of(context).textTheme.bodySmall,
        children: [
          for (final span in spans)
            TextSpan(
              text: span.text,
              style: span.unique
                  ? TextStyle(
                      backgroundColor: highlight,
                      color: onHighlight,
                      fontWeight: FontWeight.bold,
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}
