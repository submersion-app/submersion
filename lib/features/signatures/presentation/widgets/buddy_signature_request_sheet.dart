import 'package:flutter/material.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';

/// Bottom sheet for requesting a buddy's signature
///
/// Shows a message to hand device to buddy, then displays signature canvas
class BuddySignatureRequestSheet extends StatefulWidget {
  final BuddyWithRole buddyWithRole;
  final void Function(List<List<Offset>> strokes)? onSave;

  const BuddySignatureRequestSheet({
    super.key,
    required this.buddyWithRole,
    this.onSave,
  });

  @override
  State<BuddySignatureRequestSheet> createState() =>
      _BuddySignatureRequestSheetState();
}

class _BuddySignatureRequestSheetState
    extends State<BuddySignatureRequestSheet> {
  bool _showingCapture = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final buddy = widget.buddyWithRole.buddy;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            if (!_showingCapture) ...[
              // Handoff message
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.swap_horiz,
                      size: 48,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Hand your device to',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      buddy.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.buddyWithRole.role.displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _showingCapture = true;
                        });
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Ready to Sign'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Title
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${buddy.name} - Sign Here',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),

              const Divider(height: 1),

              // Signature capture
              _BuddySignatureCapture(
                buddyName: buddy.name,
                onSave: (strokes) {
                  widget.onSave?.call(strokes);
                  Navigator.of(context).pop();
                },
                onCancel: () => Navigator.of(context).pop(),
              ),

              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

/// Customized signature capture for buddy signatures (no name field needed)
class _BuddySignatureCapture extends StatefulWidget {
  final String buddyName;
  final void Function(List<List<Offset>> strokes)? onSave;
  final VoidCallback? onCancel;

  const _BuddySignatureCapture({
    required this.buddyName,
    this.onSave,
    this.onCancel,
  });

  @override
  State<_BuddySignatureCapture> createState() => _BuddySignatureCaptureState();
}

class _BuddySignatureCaptureState extends State<_BuddySignatureCapture> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];

  void _clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
    });
  }

  void _handleSave() {
    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please draw a signature')));
      return;
    }

    widget.onSave?.call(_strokes);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Signature canvas
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.5),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _currentStroke = [details.localPosition];
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _currentStroke.add(details.localPosition);
                  });
                },
                onPanEnd: (details) {
                  setState(() {
                    if (_currentStroke.isNotEmpty) {
                      _strokes.add(List.from(_currentStroke));
                    }
                    _currentStroke = [];
                  });
                },
                child: CustomPaint(
                  painter: _SignaturePainter(
                    strokes: _strokes,
                    currentStroke: _currentStroke,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Helper text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Draw your signature above',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Action buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _strokes.isEmpty && _currentStroke.isEmpty
                    ? null
                    : _clear,
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _strokes.isEmpty && _currentStroke.isEmpty
                    ? null
                    : _handleSave,
                icon: const Icon(Icons.check),
                label: const Text('Done'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom painter for signature strokes
class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;

  _SignaturePainter({required this.strokes, required this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, paint);
    }

    if (currentStroke.isNotEmpty) {
      _drawStroke(canvas, currentStroke, paint);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> stroke, Paint paint) {
    if (stroke.length < 2) return;

    final path = Path();
    path.moveTo(stroke.first.dx, stroke.first.dy);

    for (int i = 1; i < stroke.length; i++) {
      path.lineTo(stroke[i].dx, stroke[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) {
    return strokes != oldDelegate.strokes ||
        currentStroke != oldDelegate.currentStroke;
  }
}

/// Shows the buddy signature request sheet
Future<void> showBuddySignatureRequestSheet({
  required BuildContext context,
  required BuddyWithRole buddyWithRole,
  required void Function(List<List<Offset>> strokes) onSave,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => BuddySignatureRequestSheet(
      buddyWithRole: buddyWithRole,
      onSave: onSave,
    ),
  );
}
