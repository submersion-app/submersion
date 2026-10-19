import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/color/color_correction_policy.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/apply_to_dive_action.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/color_adjust_sliders.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/color_correction_label.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(ColorAdjustPanel);

/// The viewers' "Adjust color" panel (issue #3520): Auto, Pick white,
/// Original (hold), Strength, Warmth, Tint, and Brightness, Contrast and
/// Saturation under More; then Reset, Apply to this dive and Done.
///
/// A drag draws live through [colorAdjustmentDraftProvider] and saves once
/// on release. Everything is display-only: nothing is written to the file.
/// [layout] is [Axis.vertical] when the panel is docked beside the photo,
/// where the tone sliders start open.
class ColorAdjustPanel extends ConsumerStatefulWidget {
  const ColorAdjustPanel({
    super.key,
    required this.item,
    required this.onDone,
    required this.onPickWhite,
    this.pickWhiteAvailable = true,
    this.layout = Axis.horizontal,
  });

  final MediaItem item;
  final VoidCallback onDone;
  final VoidCallback onPickWhite;
  final bool pickWhiteAvailable;
  final Axis layout;

  @override
  ConsumerState<ColorAdjustPanel> createState() => _ColorAdjustPanelState();
}

class _ColorAdjustPanelState extends ConsumerState<ColorAdjustPanel> {
  ProviderContainer? _container;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context, listen: false);
  }

  @override
  void didUpdateWidget(ColorAdjustPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) _clearDraft(oldWidget.item.id);
  }

  @override
  void dispose() {
    _clearDraft(widget.item.id);
    super.dispose();
  }

  /// Drops the live draft once the panel leaves [mediaId]; by then the
  /// saved value is on the row. Deferred: providers must not change while
  /// the tree is being torn down or rebuilt.
  void _clearDraft(String mediaId) {
    final container = _container;
    if (container == null) return;
    scheduleMicrotask(
      () => container
          .read(colorAdjustmentDraftProvider(mediaId).notifier)
          .clear(),
    );
  }

  void _draw(ColorAdjustment adjustment) => ref
      .read(colorAdjustmentDraftProvider(widget.item.id).notifier)
      .set(adjustment);

  /// Saves [adjustment] (null clears it), keeping the draft on the saved
  /// value so the photo does not flicker back while the row reloads.
  Future<void> _save(ColorAdjustment? adjustment) async {
    _draw(adjustment ?? const ColorAdjustment());
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    try {
      await ref
          .read(mediaColorAdjustmentRepositoryProvider)
          .setColorAdjustment(widget.item.id, adjustment);
    } catch (e, stackTrace) {
      _log.error(
        'Saving a color adjustment failed',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ref.read(colorAdjustmentDraftProvider(widget.item.id).notifier).clear();
      }
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.media_color_saveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final item = widget.item;
    final current = effectiveAdjustment(ref, item) ?? const ColorAdjustment();
    final onDive =
        item.diveId != null &&
        (item.mediaType == MediaType.photo ||
            item.mediaType == MediaType.video);
    final diverAuto = onDive && ref.watch(diverAutoColorCorrectionProvider);
    final autoOn = autoEnabledFor(
      item,
      adjustment: current,
      diverAutoEnabled: diverAuto,
    );
    final strengthApplies = autoOn || current.whitePoint != null;

    ColorAdjustSlider slider(
      String name,
      String label,
      double value,
      ColorAdjustment Function(double v) apply, {
      double min = -1,
      bool enabled = true,
    }) => ColorAdjustSlider(
      sliderKey: Key('color_slider_$name'),
      label: label,
      value: value,
      min: min,
      onChanged: enabled ? (v) => _draw(apply(v)) : null,
      onChangeEnd: (v) => _save(apply(v)),
    );

    final toneSliders = [
      slider(
        'brightness',
        l10n.media_color_brightness,
        current.brightness,
        (v) => current.copyWith(brightness: v),
      ),
      slider(
        'contrast',
        l10n.media_color_contrast,
        current.contrast,
        (v) => current.copyWith(contrast: v),
      ),
      slider(
        'saturation',
        l10n.media_color_saturation,
        current.saturation,
        (v) => current.copyWith(saturation: v),
      ),
    ];

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.media_color_adjustAction,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                ColorCorrectionLabel(item: item),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (onDive)
                  FilterChip(
                    label: Text(l10n.media_color_auto),
                    selected: autoOn,
                    onSelected: (on) => _save(
                      current.copyWith(
                        autoOverride: on == diverAuto ? null : on,
                      ),
                    ),
                  ),
                if (widget.pickWhiteAvailable)
                  ActionChip(
                    avatar: const Icon(Icons.colorize, size: 18),
                    label: Text(l10n.media_color_pickWhite),
                    onPressed: widget.onPickWhite,
                  ),
                Listener(
                  onPointerDown: (_) => ref
                      .read(colorPeekOriginalProvider.notifier)
                      .peek(item.id),
                  onPointerUp: (_) =>
                      ref.read(colorPeekOriginalProvider.notifier).release(),
                  onPointerCancel: (_) =>
                      ref.read(colorPeekOriginalProvider.notifier).release(),
                  child: Chip(
                    avatar: const Icon(Icons.compare, size: 18),
                    label: Text(l10n.media_color_original),
                  ),
                ),
              ],
            ),
            slider(
              'strength',
              l10n.media_color_strength,
              current.strength,
              (v) => current.copyWith(strength: v),
              min: 0,
              enabled: strengthApplies,
            ),
            slider(
              'warmth',
              l10n.media_color_warmth,
              current.warmth,
              (v) => current.copyWith(warmth: v),
            ),
            slider(
              'tint',
              l10n.media_color_tint,
              current.tint,
              (v) => current.copyWith(tint: v),
            ),
            ExpansionTile(
              title: Text(l10n.common_action_more),
              initiallyExpanded: widget.layout == Axis.vertical,
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              children: toneSliders,
            ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                TextButton(
                  onPressed: () => _save(null),
                  child: Text(l10n.media_color_reset),
                ),
                if (item.diveId != null)
                  TextButton(
                    onPressed: () =>
                        runApplyToDive(context, ref, item, current),
                    child: Text(l10n.media_color_applyToDive),
                  ),
                FilledButton.tonal(
                  onPressed: widget.onDone,
                  child: Text(l10n.common_action_done),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
