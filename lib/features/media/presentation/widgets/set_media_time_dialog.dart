import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/dive_media_enricher.dart';
import 'package:submersion/features/media/data/services/enrichment_service.dart';
import 'package:submersion/features/media/domain/entities/media_dive_window.dart';
import 'package:submersion/features/media/domain/services/dive_media_clock.dart';
import 'package:submersion/features/media/presentation/helpers/elapsed_time_format.dart';
import 'package:submersion/features/media/presentation/helpers/media_time_choice.dart';
import 'package:submersion/features/media/presentation/utils/capture_time_offset_format.dart';
import 'package:submersion/features/media/presentation/widgets/mini_dive_profile_overlay.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

export 'package:submersion/features/media/presentation/helpers/media_time_choice.dart';

/// Opens the Set-time dialog and resolves with the diver's [MediaTimeChoice],
/// or null when they cancel (issue #1090).
///
/// [initialElapsedSeconds] seeds the field: the current pin, or the automatic
/// position when it is inside the dive, or 0. [isPinned] offers the Reset
/// action, which only means something when a pin exists.
///
/// [automatic] resolves to where the item sits by its capture time, with the
/// shift its dive already applies (issue #4539). Once it has one, the dialog
/// offers to move every photo and video on the dive by as much as this item
/// moves; null (no capture-time place to measure from) leaves the dialog a
/// pin only. It is a future so the dialog opens on the tap: reading it means
/// loading the dive, and waiting for that first would leave the button dead
/// long enough to be tapped twice.
Future<MediaTimeChoice?> showSetMediaTimeDialog(
  BuildContext context, {
  required List<DiveProfilePoint> profile,
  required int initialElapsedSeconds,
  required bool isPinned,
  required AppSettings settings,
  Future<MediaAutomaticTime?>? automatic,
}) {
  return showDialog<MediaTimeChoice>(
    context: context,
    builder: (_) => SetMediaTimeDialog(
      profile: profile,
      initialElapsedSeconds: initialElapsedSeconds,
      isPinned: isPinned,
      settings: settings,
      automatic: automatic,
    ),
  );
}

/// A minutes:seconds field and a slider over the dive's length, previewed
/// live on the mini dive profile so the diver can see the depth they are
/// pinning the shot to.
class SetMediaTimeDialog extends StatefulWidget {
  const SetMediaTimeDialog({
    super.key,
    required this.profile,
    required this.initialElapsedSeconds,
    required this.isPinned,
    required this.settings,
    this.automatic,
  });

  final List<DiveProfilePoint> profile;
  final int initialElapsedSeconds;
  final bool isPinned;
  final AppSettings settings;

  /// Resolves to where the item sits by capture time and the shift its dive
  /// applies; the dive-wide shift stays hidden until it has a value.
  final Future<MediaAutomaticTime?>? automatic;

  @override
  State<SetMediaTimeDialog> createState() => _SetMediaTimeDialogState();
}

class _SetMediaTimeDialogState extends State<SetMediaTimeDialog> {
  static const _enrichment = EnrichmentService();

  late final int _maxSeconds = MediaDiveWindow.profileLengthSeconds(
    widget.profile,
  );
  late int _seconds = widget.initialElapsedSeconds.clamp(0, _maxSeconds);
  late final TextEditingController _controller = TextEditingController(
    text: formatElapsedMmSs(_seconds),
  );
  bool _invalid = false;

  /// Whether Save moves every item on the dive instead of pinning this one.
  bool _shiftAll = false;

  /// What [SetMediaTimeDialog.automatic] resolved to, once it has.
  MediaAutomaticTime? _automatic;

  /// Whether the diver has typed in the field or moved the slider.
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAutomatic());
  }

  Future<void> _loadAutomatic() async {
    MediaAutomaticTime? automatic;
    try {
      automatic = await widget.automatic;
    } on Object {
      // No shift to offer; the pin needs none of this.
      return;
    }
    if (!mounted || automatic == null) return;
    final place = automatic.elapsedSeconds;
    setState(() {
      _automatic = automatic;
      // The dialog opened on the stored position, which lags the dive's
      // clock until the dive's media is placed again. An item the diver has
      // neither pinned nor moved starts from where it sits now, so the shift
      // switch offers no move they did not make.
      if (!_touched && !widget.isPinned && _inRange(place)) {
        _seconds = place;
        _controller.text = formatElapsedMmSs(place);
      }
    });
  }

  /// The dive's whole shift if the item moves to [seconds], or null when
  /// that is more than a dive holds: an item with no real capture time, not
  /// a camera whose clock is out.
  int? _shiftAt(MediaAutomaticTime automatic, int seconds) {
    // The dive's shift is already in the automatic place, so the new shift
    // is the old one plus how far this item moves from there.
    final shift =
        automatic.diveShiftSeconds + seconds - automatic.elapsedSeconds;
    return DiveMediaClock.isValidOffset(shift) ? shift : null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _inRange(int seconds) => seconds >= 0 && seconds <= _maxSeconds;

  void _onFieldChanged(String text) {
    _touched = true;
    final parsed = parseElapsedMmSs(text);
    // The slider and preview follow only a usable value; the field keeps
    // whatever is being typed so a half-entered time is not fought.
    if (parsed == null || !_inRange(parsed)) return;
    setState(() {
      _seconds = parsed;
      _invalid = false;
    });
  }

  void _onSliderChanged(double value) {
    final seconds = value.round();
    setState(() {
      _touched = true;
      _seconds = seconds;
      _invalid = false;
      _controller.text = formatElapsedMmSs(seconds);
    });
  }

  void _save() {
    final parsed = parseElapsedMmSs(_controller.text);
    if (parsed == null || !_inRange(parsed)) {
      setState(() => _invalid = true);
      return;
    }
    final automatic = _automatic;
    final shift = _shiftAll && automatic != null
        ? _shiftAt(automatic, parsed)
        : null;
    Navigator.of(context).pop(
      shift != null ? MediaTimeDiveShifted(shift) : MediaTimePinned(parsed),
    );
  }

  /// How far Save would move the dive's media, in words.
  String _shiftSummary(AppLocalizations l10n, MediaAutomaticTime automatic) {
    final moved = _seconds - automatic.elapsedSeconds;
    if (moved == 0) return l10n.media_timeInDive_shiftAllHint;
    final amount = formatShiftMagnitude(moved);
    return moved < 0
        ? l10n.media_timeInDive_shiftAllEarlier(amount)
        : l10n.media_timeInDive_shiftAllLater(amount);
  }

  /// The shift the dive already has, in words.
  String _diveShiftLabel(AppLocalizations l10n, int shiftSeconds) {
    final amount = formatShiftMagnitude(shiftSeconds);
    return shiftSeconds < 0
        ? l10n.media_timeInDive_diveShiftEarlier(amount)
        : l10n.media_timeInDive_diveShiftLater(amount);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final max = formatElapsedMmSs(_maxSeconds);
    final automatic = _automatic;
    final canShift = automatic != null && _shiftAt(automatic, _seconds) != null;
    final preview = _enrichment.calculateEnrichmentAtElapsed(
      profile: widget.profile,
      elapsedSeconds: _seconds,
    );

    return AlertDialog(
      title: Text(l10n.media_timeInDive_label),
      // The shift rows make the content taller than a small phone with its
      // keyboard up.
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            // datetime, not number: the number keypad on iOS and Android has
            // no ':' key, and mm:ss cannot be typed without one.
            keyboardType: TextInputType.datetime,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9:]')),
            ],
            decoration: InputDecoration(
              labelText: l10n.media_timeInDive_fieldLabel,
              hintText: l10n.media_timeInDive_fieldHint,
              helperText: l10n.media_timeInDive_range(max),
              errorText: _invalid ? l10n.media_timeInDive_invalid(max) : null,
            ),
            onChanged: _onFieldChanged,
            onSubmitted: (_) => _save(),
          ),
          if (_maxSeconds > 0)
            Slider(
              value: _seconds.toDouble(),
              min: 0,
              max: _maxSeconds.toDouble(),
              onChanged: _onSliderChanged,
            ),
          const SizedBox(height: 8),
          Center(
            child: MiniDiveProfileOverlay(
              profile: widget.profile,
              photoElapsedSeconds: _seconds,
              photoDepthMeters: preview.depthMeters,
              settings: widget.settings,
            ),
          ),
          if (automatic != null) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.media_timeInDive_shiftAll),
              subtitle: Text(_shiftSummary(l10n, automatic)),
              value: _shiftAll && canShift,
              onChanged: canShift
                  ? (value) => setState(() => _shiftAll = value)
                  : null,
            ),
            if (automatic.diveShiftSeconds != 0)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _diveShiftLabel(l10n, automatic.diveShiftSeconds),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(const MediaTimeDiveShiftRemoved()),
                    child: Text(l10n.media_timeInDive_removeShift),
                  ),
                ],
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.media_timeInDive_cancel),
        ),
        if (widget.isPinned)
          TextButton(
            onPressed: () => Navigator.of(context).pop(const MediaTimeReset()),
            child: Text(l10n.media_timeInDive_reset),
          ),
        FilledButton(onPressed: _save, child: Text(l10n.media_timeInDive_save)),
      ],
    );
  }
}
