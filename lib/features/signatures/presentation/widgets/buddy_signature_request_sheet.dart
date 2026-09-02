import 'package:flutter/material.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_roles/presentation/dive_role_display.dart';

/// Bottom sheet for requesting a buddy's signature
///
/// Shows a message to hand device to buddy, then displays signature canvas
class BuddySignatureRequestSheet extends StatefulWidget {
  final BuddyWithRole buddyWithRole;

  /// Receives the strokes together with the size of the canvas they were
  /// drawn on. The strokes are in canvas-local coordinates, so rendering
  /// them at any other size crops the signature.
  final void Function(List<List<Offset>> strokes, Size canvasSize)? onSave;

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
            ExcludeSemantics(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
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
                      context.l10n.signatures_handoff_title,
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
                      widget.buddyWithRole.role.localizedName(context.l10n),
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
                      label: Text(context.l10n.signatures_action_readyToSign),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.l10n.common_action_cancel),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Title
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.l10n.signatures_signHere(buddy.name),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),

              const Divider(height: 1),

              // Signature capture
              _BuddySignatureCapture(
                buddyName: buddy.name,
                onSave: (strokes, canvasSize) {
                  widget.onSave?.call(strokes, canvasSize);
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
  final void Function(List<List<Offset>> strokes, Size canvasSize)? onSave;
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
  static const double _canvasHeight = 200;

  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];

  /// Laid-out size of the drawing surface, recorded by the [LayoutBuilder]
  /// that wraps it. The canvas stretches to the sheet width, so it is only
  /// known after layout -- and the strokes mean nothing without it.
  ///
  /// The placeholder is never read: a stroke requires a laid-out canvas, so
  /// the builder has always run by the time a save can happen.
  Size _canvasSize = Size.zero;

  /// Whether anything drawable has been captured. Mirrors what the painter
  /// and the PNG encoder accept, so an enabled button always means there is
  /// a signature to save.
  bool get _hasDrawing => _strokes.isNotEmpty || _currentStroke.length >= 2;

  void _clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
    });
  }

  void _handleSave() {
    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.signatures_error_drawSignature)),
      );
      return;
    }

    widget.onSave?.call(_strokes, _canvasSize);
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
          child: _buildCanvas(context, colorScheme),
        ),

        const SizedBox(height: 8),

        // Helper text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            context.l10n.signatures_drawSignatureHint,
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
                onPressed: !_hasDrawing ? null : _clear,
                icon: const Icon(Icons.clear),
                label: Text(context.l10n.signatures_action_clear),
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onCancel,
                child: Text(context.l10n.common_action_cancel),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: !_hasDrawing ? null : _handleSave,
                icon: const Icon(Icons.check),
                label: Text(context.l10n.signatures_action_done),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCanvas(BuildContext context, ColorScheme colorScheme) {
    return Container(
      height: _canvasHeight,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Recorded, not applied, and measured HERE rather than around
            // the Container: the border insets this surface by 1px a side,
            // and `details.localPosition` is relative to it. Measuring the
            // outer box would report a canvas 2px larger than the space the
            // strokes actually live in.
            _canvasSize = constraints.biggest;
            return _buildGestureSurface(context);
          },
        ),
      ),
    );
  }

  Widget _buildGestureSurface(BuildContext context) {
    return Semantics(
      label: context.l10n.signatures_drawSignatureSemantics,
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
            // Only strokes with a segment to draw. A plain tap wins the
            // gesture arena uncontested and lands here with a single point,
            // which the painter and the PNG encoder both skip -- so storing
            // it would light up Done and save a blank signature.
            if (_currentStroke.length >= 2) {
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
  required void Function(List<List<Offset>> strokes, Size canvasSize) onSave,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    // Drawing on the signature canvas uses a pan gesture; the sheet's
    // drag-to-dismiss would otherwise win the gesture arena and move the
    // whole sheet instead of drawing. A Cancel button provides dismissal.
    enableDrag: false,
    builder: (context) => BuddySignatureRequestSheet(
      buddyWithRole: buddyWithRole,
      onSave: onSave,
    ),
  );
}
