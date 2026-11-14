import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One part of a [SacShareBar].
class SacSharePart {
  /// What this part names, for a screen reader.
  final String label;

  /// Its share of the whole, 0 to 1.
  final double share;

  /// The share as shown, such as `59%`.
  final String shareText;

  final Color color;

  const SacSharePart({
    required this.label,
    required this.share,
    required this.shareText,
    required this.color,
  });
}

/// A single bar split into the parts of a whole, such as the gas each phase
/// of a dive used.
///
/// The parts wear the colors of the rows they stand for, so the table below
/// is its legend and it needs no labels of its own.
class SacShareBar extends StatelessWidget {
  static const double _height = 10;
  static const double _gap = 1.5;

  /// The smallest a part draws, as a share of the bar, so a sliver still
  /// shows.
  static const double _minShare = 0.01;

  final String title;
  final List<SacSharePart> parts;

  const SacShareBar({super.key, required this.title, required this.parts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = parts.where((p) => p.share > 0).toList();
    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          '$title: ${[for (final p in parts) '${p.label} ${p.shareText}'].join(', ')}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(_height / 2),
            child: SizedBox(
              height: _height,
              child: Row(
                // A ColoredBox has no size of its own, so each part fills
                // the bar's height.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, part) in visible.indexed)
                    Expanded(
                      flex: (math.max(part.share, _minShare) * 1000).round(),
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          end: index == visible.length - 1 ? 0 : _gap,
                        ),
                        child: ColoredBox(color: part.color),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
