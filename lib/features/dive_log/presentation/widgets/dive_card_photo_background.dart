import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_crop_alignment.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_photo.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_photo_tuning.dart';
import 'package:submersion/features/dive_log/presentation/providers/card_photo_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
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

  /// The key the crop analysis for [item] is cached under: its id and where
  /// its pixels come from.
  @visibleForTesting
  static String analysisKeyFor(MediaItem item) =>
      '${item.id}\u0000${_DiveCardPhotoBackgroundState._sourceOf(item)}';

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

  /// Where the drawn photo's pixels come from ([_sourceOf]), or null before
  /// its media row has loaded.
  String? _source;

  /// Where [item]'s pixels come from. A repair or relink keeps the media id
  /// but changes this, and the crop must then be worked out from the new
  /// picture, not served from the scores of the old one.
  ///
  /// Joined with NUL, as the media tile memo and the local-file resolver do:
  /// a path or bookmark may contain any other separator, which would let
  /// two different sources read the same.
  static String _sourceOf(MediaItem item) => [
    item.sourceType.name,
    item.filePath ?? '',
    item.localPath ?? '',
    item.platformAssetId ?? '',
    item.bookmarkRef ?? '',
    item.url ?? '',
    item.remoteAssetId ?? '',
    item.cloudAssetId ?? '',
    item.contentHash ?? '',
  ].join('\u0000');

  /// The analyser's key for the photo on screen: its id and its source.
  String get _analysisKey => '${widget.photo.mediaId}\u0000${_source ?? ''}';

  @override
  void didUpdateWidget(covariant DiveCardPhotoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    final photo = widget.photo;
    if (oldWidget.photo.mediaId != photo.mediaId) {
      _imageSize = null;
      _rows = null;
      _provider = null;
      _source = null;
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
      if (analyzer.hasAnswer(_analysisKey)) {
        _rows = analyzer.peek(_analysisKey);
      } else {
        _analyse(provider);
      }
    }
  }

  void _onImageReady(ImageProvider provider, Size size) {
    if (!mounted) return;
    final key = _analysisKey;
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
    if (analyzer.hasAnswer(key)) {
      setState(() {
        _imageSize = size;
        _rows = analyzer.peek(key);
        _ready = true;
      });
      return;
    }
    _imageSize = size;
    _analyse(provider);
  }

  /// Analyses [provider]'s pixels for the photo on screen, and shows it once
  /// they are known, unless the card has moved on to another photo or
  /// source in the meantime.
  void _analyse(ImageProvider provider) {
    final key = _analysisKey;
    ref.read(cardFocusAnalyzerProvider).rowScoresFor(key, provider).then((
      rows,
    ) {
      if (!mounted || _analysisKey != key) return;
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
    // The same photo drawn from other pixels (repaired or relinked): the
    // old picture's size and crop no longer apply, so it is hidden until
    // the new one is ready, as on first draw. The view below is keyed by
    // the source, so it draws and reports the new picture afresh.
    final source = item == null ? null : _sourceOf(item);
    if (source != null && source != _source) {
      if (_source != null) {
        _imageSize = null;
        _rows = null;
        _provider = null;
        _ready = false;
      }
      _source = source;
    }
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
                // A card with no width to show (a pane collapsing) or none
                // bounded draws no photo: a 0 px decode trips ResizeImage,
                // and an infinite one cannot be bucketed.
                if (!card.width.isFinite || card.width <= 0) {
                  return const SizedBox.shrink();
                }
                final decodeWidth =
                    (card.width / _decodeStep).ceil() * _decodeStep;
                return AnimatedOpacity(
                  opacity: _ready ? 1 : 0,
                  duration: CardPhotoTuning.fadeIn,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MediaItemView(
                        key: ValueKey(_source),
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
