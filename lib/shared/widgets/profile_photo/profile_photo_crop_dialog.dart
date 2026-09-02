import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:submersion/core/services/images/profile_photo_codec.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_photo_crop_geometry.dart';

/// Shows the pan and zoom crop surface and returns the encoded 512x512 JPEG,
/// or null if the user cancelled.
///
/// A full-screen dialog rather than a bottom sheet: a crop wants maximum area,
/// and `showModalBottomSheet(isScrollControlled: true)` removes the height
/// ceiling entirely, which puts a drag handle inside Android's notification
/// shade zone (issue #1188). Popping happens from inside this builder's own
/// context, which addresses the root navigator that `showDialog` already
/// defaults to, so this is not the pattern that blanked master-detail in
/// PR #1312.
Future<Uint8List?> showProfilePhotoCropDialog({
  required BuildContext context,
  required Uint8List sourceBytes,
  String? declaredName,
}) {
  return showDialog<Uint8List?>(
    context: context,
    builder: (dialogContext) => _ProfilePhotoCropDialog(
      sourceBytes: sourceBytes,
      declaredName: declaredName,
    ),
  );
}

class _ProfilePhotoCropDialog extends StatefulWidget {
  const _ProfilePhotoCropDialog({required this.sourceBytes, this.declaredName});

  final Uint8List sourceBytes;
  final String? declaredName;

  @override
  State<_ProfilePhotoCropDialog> createState() =>
      _ProfilePhotoCropDialogState();
}

class _ProfilePhotoCropDialogState extends State<_ProfilePhotoCropDialog> {
  final TransformationController _controller = TransformationController();
  ui.Image? _decoded;
  bool _busy = false;
  bool _centered = false;
  bool _decodeFailed = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    // instantiateImageCodec THROWS on bytes it cannot read, and a picked file
    // is not guaranteed to be a valid image: a corrupt file, or a contact
    // photo in a format the engine does not decode. Unhandled, the exception
    // escapes into the zone and leaves this dialog on its spinner forever
    // with no way out but Cancel.
    final ui.FrameInfo frame;
    try {
      // The codec holds native decode resources separate from the frame's
      // image, so it needs disposing even on the happy path or repeated opens
      // of this dialog leak. Same try/finally shape as
      // terrain_imagery_service.dart.
      final codec = await ui.instantiateImageCodec(widget.sourceBytes);
      try {
        frame = await codec.getNextFrame();
      } finally {
        codec.dispose();
      }
    } on Object {
      if (mounted) setState(() => _decodeFailed = true);
      return;
    }
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() => _decoded = frame.image);
  }

  @override
  void dispose() {
    _controller.dispose();
    _decoded?.dispose();
    super.dispose();
  }

  /// Centres the initial view on the middle of the photo.
  ///
  /// With `constrained: false` the child is anchored at the viewer's origin,
  /// so an identity transform shows the TOP-LEFT of an image that is larger
  /// than the square viewport. For a landscape photo that means the left edge,
  /// which forces the user to pan before every save and disagrees with the
  /// codec, whose no-rect default is the largest CENTRED square.
  void _centerOnce(Size viewport, Size childSize) {
    if (_centered) return;
    _centered = true;
    final dx = (childSize.width - viewport.width) / 2;
    final dy = (childSize.height - viewport.height) / 2;
    if (dx <= 0 && dy <= 0) return;
    // Deferred: the controller is a ValueNotifier, so assigning during build
    // would notify the viewer mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.value = Matrix4.identity()..translateByDouble(-dx, -dy, 0, 1);
    });
  }

  Future<void> _save(Size viewport, Size childSize, Size sourceSize) async {
    setState(() => _busy = true);
    final rect = cropRectInSourcePixels(
      transform: _controller.value,
      viewport: viewport,
      childSize: childSize,
      sourceSize: sourceSize,
    );
    // compute() spawns a real isolate, which can fail to start, and the codec
    // reports expected problems as an outcome but can still throw on the
    // unexpected. Either would otherwise strand the dialog at _busy true with
    // the Save button permanently disabled. This mirrors the guard on the
    // open-time decode.
    final ImageEncodeResult result;
    try {
      result = await encodeStoredImage(
        ImageEncodeRequest.fromBytes(
          bytes: widget.sourceBytes,
          spec: ImageEncodeSpec.avatar,
          cropRect: rect,
          declaredName: widget.declaredName,
        ),
      );
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.profilePhoto_error_undecodable)),
      );
      return;
    }
    if (!mounted) return;
    if (result.outcome != ImageEncodeOutcome.encoded) {
      setState(() => _busy = false);
      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.outcome == ImageEncodeOutcome.tooLarge
                ? l10n.profilePhoto_error_tooLarge
                : l10n.profilePhoto_error_undecodable,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(result.bytes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final decoded = _decoded;

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.profilePhoto_crop_title),
          leading: TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.common_action_cancel),
          ),
          leadingWidth: 96,
        ),
        body: _decodeFailed
            // Reported in place rather than through a snackbar: this Scaffold's
            // messenger dies with the dialog, and the user needs the reason to
            // stay on screen next to the only way out.
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.profilePhoto_error_undecodable,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              )
            : decoded == null
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final side = constraints.maxWidth < constraints.maxHeight
                      ? constraints.maxWidth
                      : constraints.maxHeight;
                  final viewport = Size(side, side);
                  final sourceSize = Size(
                    decoded.width.toDouble(),
                    decoded.height.toDouble(),
                  );
                  // Lay the child out at cover scale so the square viewport is
                  // always fully covered. minScale 1.0 then makes a gap
                  // unrepresentable rather than something to validate against.
                  final coverScale = decoded.width < decoded.height
                      ? side / decoded.width
                      : side / decoded.height;
                  final childSize = Size(
                    decoded.width * coverScale,
                    decoded.height * coverScale,
                  );
                  _centerOnce(viewport, childSize);

                  return Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            width: side,
                            height: side,
                            child: ClipOval(
                              child: InteractiveViewer(
                                transformationController: _controller,
                                minScale: 1,
                                maxScale: 5,
                                constrained: false,
                                // Renders the ui.Image already decoded for
                                // its dimensions. Image.memory would decode
                                // the same JPEG a second time, doubling both
                                // the work and the resident bitmap for a large
                                // source photo.
                                child: SizedBox(
                                  width: childSize.width,
                                  height: childSize.height,
                                  child: RawImage(
                                    image: decoded,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          l10n.profilePhoto_crop_hint,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: FilledButton(
                          onPressed: _busy
                              ? null
                              : () => _save(viewport, childSize, sourceSize),
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.common_action_save),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
