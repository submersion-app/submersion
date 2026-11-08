import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_crop_alignment.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_photo.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_photo_tuning.dart';
import 'package:submersion/features/dive_log/presentation/providers/card_photo_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The overlay that keeps a dive card's text readable over its photo: dark
/// on a dark theme, light on a light one, so the card sits with its
/// neighbours in the list.
abstract final class DiveCardPhotoScrim {
  /// The colour the card's text colours are chosen against.
  static Color textBase(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFF1A1A2E) : Colors.white;

  /// The overlay for [brightness] at the diver's chosen [opacity].
  static LinearGradient gradient(Brightness brightness, double opacity) {
    final base = brightness == Brightness.dark ? Colors.black : Colors.white;
    final alphas = CardPhotoTuning.overlayAlphas(opacity);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const [0.0, 0.3, 0.7, 1.0],
      colors: [for (final a in alphas) base.withValues(alpha: a)],
    );
  }
}

/// [child] over one of the dive's photos, cropped to cover the card.
///
/// The photo stays hidden until it has decoded and its crop is known, then
/// fades in at its final position, so it never jumps. Until then the card
/// shows its own fill. A photo that cannot be drawn is marked failed in
/// [failedCardPhotosProvider], so the card moves on to another of the
/// dive's photos, or to the map or colour.
class DiveCardPhotoBackground extends ConsumerStatefulWidget {
  const DiveCardPhotoBackground({
    super.key,
    required this.photo,
    required this.child,
  });

  final CardPhoto photo;
  final Widget child;

  @override
  ConsumerState<DiveCardPhotoBackground> createState() =>
      _DiveCardPhotoBackgroundState();
}

class _DiveCardPhotoBackgroundState
    extends ConsumerState<DiveCardPhotoBackground> {
  Size? _imageSize;
  List<double>? _rows;
  bool _ready = false;

  /// Decode widths step in buckets, so a window being resized does not
  /// resolve the photo again on every pixel.
  static const _decodeStep = 160.0;

  /// The image that drew this photo, kept so the crop can be worked out
  /// again when the tags on it change.
  ImageProvider? _provider;

  @override
  void didUpdateWidget(covariant DiveCardPhotoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    final photo = widget.photo;
    if (oldWidget.photo.mediaId != photo.mediaId) {
      _imageSize = null;
      _rows = null;
      _provider = null;
      _ready = false;
      return;
    }
    // The same photo, its people untagged: the boxes placed the crop, so
    // the pixels must now. New boxes need nothing: the crop reads them.
    final provider = _provider;
    if (oldWidget.photo.focusBoxes.isNotEmpty &&
        photo.focusBoxes.isEmpty &&
        CardPhotoTuning.usePixelAnalysis &&
        _rows == null &&
        provider != null) {
      final analyzer = ref.read(cardFocusAnalyzerProvider);
      if (analyzer.hasAnswer(photo.mediaId)) {
        _rows = analyzer.peek(photo.mediaId);
      } else {
        _analyse(photo.mediaId, provider);
      }
    }
  }

  void _onImageReady(ImageProvider provider, Size size) {
    if (!mounted) return;
    final mediaId = widget.photo.mediaId;
    _provider = provider;
    if (widget.photo.focusBoxes.isNotEmpty ||
        !CardPhotoTuning.usePixelAnalysis) {
      setState(() {
        _imageSize = size;
        _ready = true;
      });
      return;
    }
    final analyzer = ref.read(cardFocusAnalyzerProvider);
    if (analyzer.hasAnswer(mediaId)) {
      setState(() {
        _imageSize = size;
        _rows = analyzer.peek(mediaId);
        _ready = true;
      });
      return;
    }
    _imageSize = size;
    _analyse(mediaId, provider);
  }

  /// Analyses [provider]'s pixels for [mediaId]'s crop, and shows the photo
  /// once they are known.
  void _analyse(String mediaId, ImageProvider provider) {
    ref.read(cardFocusAnalyzerProvider).rowScoresFor(mediaId, provider).then((
      rows,
    ) {
      if (!mounted || widget.photo.mediaId != mediaId) return;
      setState(() {
        _rows = rows;
        _ready = true;
      });
    });
  }

  /// Gives up on this photo, so the card picks another of the dive's or
  /// falls back to the map or colour. [MediaItemView] calls this after its
  /// frame, outside any build.
  void _markFailed() {
    if (!mounted) return;
    ref
        .read(failedCardPhotosProvider.notifier)
        .markFailed(widget.photo.mediaId);
  }

  /// [_markFailed] from inside build, where it would change what the card
  /// above is building: after the frame, with one asked for so it comes
  /// even when nothing else on screen is moving.
  void _markFailedAfterFrame() {
    final mediaId = widget.photo.mediaId;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted && widget.photo.mediaId == mediaId) _markFailed();
      })
      ..ensureVisualUpdate();
  }

  double _alignmentY(Size card) {
    final image = _imageSize;
    if (!_ready || image == null || image.height <= 0 || card.height <= 0) {
      return 0;
    }
    return cardCropAlignmentY(
      imageAspect: image.width / image.height,
      cardAspect: card.width / card.height,
      focusBoxes: widget.photo.focusBoxes,
      rowScores: _rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = ref.watch(mediaByIdProvider(widget.photo.mediaId));
    // The row went away (deleted, or not on this device yet): no photo.
    if (media.hasValue && media.value == null) _markFailedAfterFrame();
    final item = media.value;
    final brightness = Theme.of(context).brightness;
    final overlay = ref.watch(cardPhotoOverlayProvider);
    final opacity = brightness == Brightness.dark
        ? overlay.dark
        : overlay.light;
    return Stack(
      children: [
        if (item != null)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final card = constraints.biggest;
                final decodeWidth =
                    (card.width / _decodeStep).ceil() * _decodeStep;
                return AnimatedOpacity(
                  opacity: _ready ? 1 : 0,
                  duration: CardPhotoTuning.fadeIn,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MediaItemView(
                        item: item,
                        thumbnail: true,
                        targetSize: Size(decodeWidth, decodeWidth),
                        fit: BoxFit.cover,
                        alignment: Alignment(0, _alignmentY(card)),
                        onImageReady: _onImageReady,
                        onImageFailed: _markFailed,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: DiveCardPhotoScrim.gradient(
                            brightness,
                            opacity,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        widget.child,
      ],
    );
  }
}
