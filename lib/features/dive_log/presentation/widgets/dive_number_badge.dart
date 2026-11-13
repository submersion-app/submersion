import 'package:flutter/material.dart';

/// Rounded 40 point square showing a dive's number, as the rows of the trip
/// Dives tab and the buddy "Shared dives" card lead with it.
///
/// The number scales down to stay on one line once it outgrows the square
/// (#4497: "#1234" used to wrap onto two lines), the way the dive detail hero
/// badge already handles long numbers. Short numbers keep their full size.
class DiveNumberBadge extends StatelessWidget {
  /// The dive's number, or null for a dive without one (shown as "#-").
  final int? diveNumber;

  const DiveNumberBadge({super.key, required this.diveNumber});

  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.square(
      dimension: _size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '#${diveNumber ?? '-'}',
                maxLines: 1,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
