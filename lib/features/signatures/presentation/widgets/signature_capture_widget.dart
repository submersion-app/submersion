import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// A widget for capturing hand-drawn signatures
///
/// Provides a canvas area for drawing with touch/stylus input,
/// along with clear and save controls.
class SignatureCaptureWidget extends StatefulWidget {
  /// Initial signer name (pre-filled if instructor is known)
  final String? initialSignerName;

  /// Callback when signature is saved
  final void Function(
    List<List<Offset>> strokes,
    String signerName,
    Size canvasSize,
  )?
  onSave;

  /// Callback when cancelled
  final VoidCallback? onCancel;

  /// Stroke color
  final Color strokeColor;

  /// Stroke width
  final double strokeWidth;

  /// Background color of the signature area
  final Color? backgroundColor;

  /// Height of the signature canvas (default 200)
  final double canvasHeight;

  const SignatureCaptureWidget({
    super.key,
    this.initialSignerName,
    this.onSave,
    this.onCancel,
    this.strokeColor = Colors.black,
    this.strokeWidth = 3.0,
    this.backgroundColor,
    this.canvasHeight = 200,
  });

  @override
  State<SignatureCaptureWidget> createState() => _SignatureCaptureWidgetState();
}

class _SignatureCaptureWidgetState extends State<SignatureCaptureWidget> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  late final TextEditingController _nameController;

  /// Laid-out size of the drawing surface, recorded by the [LayoutBuilder]
  /// that wraps it. The canvas stretches to the available width, so it is
  /// only known after layout -- and the strokes mean nothing without it.
  ///
  /// The placeholder is never read: a stroke requires a laid-out canvas, so
  /// the builder has always run by the time a save can happen.
  Size _canvasSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialSignerName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

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
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.signatures_error_enterSignerName)),
      );
      return;
    }

    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.signatures_error_drawSignature)),
      );
      return;
    }

    widget.onSave?.call(_strokes, name, _canvasSize);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canvasBackground =
        widget.backgroundColor ?? colorScheme.surfaceContainerHighest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Signer name field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: context.l10n.signatures_field_instructorName,
              hintText: context.l10n.signatures_field_instructorNameHint,
              prefixIcon: const Icon(Icons.person_outline),
              border: const OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
        ),

        const SizedBox(height: 8),

        // Signature label
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            context.l10n.signatures_instructorSignature,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Signature canvas
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildCanvas(context, canvasBackground, colorScheme),
        ),

        const SizedBox(height: 8),

        // Helper text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            context.l10n.signatures_drawSignatureHintDetailed,
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
              // Clear button
              OutlinedButton.icon(
                onPressed: !_hasDrawing ? null : _clear,
                icon: const Icon(Icons.clear),
                label: Text(context.l10n.signatures_action_clear),
              ),
              const Spacer(),
              // Cancel button
              TextButton(
                onPressed: widget.onCancel,
                child: Text(context.l10n.common_action_cancel),
              ),
              const SizedBox(width: 8),
              // Save button
              FilledButton.icon(
                onPressed: !_hasDrawing ? null : _handleSave,
                icon: const Icon(Icons.check),
                label: Text(context.l10n.signatures_action_saveSignature),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCanvas(
    BuildContext context,
    Color canvasBackground,
    ColorScheme colorScheme,
  ) {
    return Container(
      height: widget.canvasHeight,
      decoration: BoxDecoration(
        color: canvasBackground,
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
            // it would light up Save and store a blank signature.
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
            strokeColor: widget.strokeColor,
            strokeWidth: widget.strokeWidth,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Custom painter for drawing signature strokes
class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final Color strokeColor;
  final double strokeWidth;

  _SignaturePainter({
    required this.strokes,
    required this.currentStroke,
    required this.strokeColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Draw completed strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, paint);
    }

    // Draw current stroke
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

/// Full-screen signature capture sheet
class SignatureCaptureSheet extends StatelessWidget {
  final String? initialSignerName;
  final void Function(
    List<List<Offset>> strokes,
    String signerName,
    Size canvasSize,
  )?
  onSave;

  const SignatureCaptureSheet({super.key, this.initialSignerName, this.onSave});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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

            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.signatures_captureInstructorSignature,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),

            const Divider(height: 1),

            // Signature capture widget
            SignatureCaptureWidget(
              initialSignerName: initialSignerName,
              onSave: (strokes, name, canvasSize) {
                onSave?.call(strokes, name, canvasSize);
                Navigator.of(context).pop();
              },
              onCancel: () => Navigator.of(context).pop(),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Shows the signature capture sheet
Future<void> showSignatureCaptureSheet({
  required BuildContext context,
  String? initialSignerName,
  required void Function(
    List<List<Offset>> strokes,
    String signerName,
    Size canvasSize,
  )
  onSave,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    // Drawing on the signature canvas uses a pan gesture; the sheet's
    // drag-to-dismiss would otherwise win the gesture arena and move the
    // whole sheet instead of drawing. A Cancel button provides dismissal.
    enableDrag: false,
    builder: (context) => SignatureCaptureSheet(
      initialSignerName: initialSignerName,
      onSave: onSave,
    ),
  );
}
