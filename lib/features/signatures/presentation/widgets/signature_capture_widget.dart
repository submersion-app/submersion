import 'package:flutter/material.dart';

/// A widget for capturing hand-drawn signatures
///
/// Provides a canvas area for drawing with touch/stylus input,
/// along with clear and save controls.
class SignatureCaptureWidget extends StatefulWidget {
  /// Initial signer name (pre-filled if instructor is known)
  final String? initialSignerName;

  /// Callback when signature is saved
  final void Function(List<List<Offset>> strokes, String signerName)? onSave;

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
        const SnackBar(content: Text('Please enter the signer name')),
      );
      return;
    }

    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please draw a signature')));
      return;
    }

    widget.onSave?.call(_strokes, name);
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
            decoration: const InputDecoration(
              labelText: 'Instructor Name',
              hintText: 'Enter instructor name',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
        ),

        const SizedBox(height: 8),

        // Signature label
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Instructor Signature',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Signature canvas
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: widget.canvasHeight,
            decoration: BoxDecoration(
              color: canvasBackground,
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
                    strokeColor: widget.strokeColor,
                    strokeWidth: widget.strokeWidth,
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
            'Draw signature above using finger or stylus',
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
                onPressed: _strokes.isEmpty && _currentStroke.isEmpty
                    ? null
                    : _clear,
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
              const Spacer(),
              // Cancel button
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              // Save button
              FilledButton.icon(
                onPressed: _strokes.isEmpty && _currentStroke.isEmpty
                    ? null
                    : _handleSave,
                icon: const Icon(Icons.check),
                label: const Text('Save Signature'),
              ),
            ],
          ),
        ),
      ],
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
  final void Function(List<List<Offset>> strokes, String signerName)? onSave;

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
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Capture Instructor Signature',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),

            const Divider(height: 1),

            // Signature capture widget
            SignatureCaptureWidget(
              initialSignerName: initialSignerName,
              onSave: (strokes, name) {
                onSave?.call(strokes, name);
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
  required void Function(List<List<Offset>> strokes, String signerName) onSave,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => SignatureCaptureSheet(
      initialSignerName: initialSignerName,
      onSave: onSave,
    ),
  );
}
