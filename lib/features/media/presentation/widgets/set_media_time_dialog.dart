import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/enrichment_service.dart';
import 'package:submersion/features/media/domain/entities/media_dive_window.dart';
import 'package:submersion/features/media/presentation/helpers/elapsed_time_format.dart';
import 'package:submersion/features/media/presentation/helpers/media_time_choice.dart';
import 'package:submersion/features/media/presentation/widgets/mini_dive_profile_overlay.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

export 'package:submersion/features/media/presentation/helpers/media_time_choice.dart';

/// Opens the Set-time dialog and resolves with the diver's [MediaTimeChoice],
/// or null when they cancel (issue #1090).
///
/// [initialElapsedSeconds] seeds the field: the current pin, or the automatic
/// position when it is inside the dive, or 0. [isPinned] offers the Reset
/// action, which only means something when a pin exists.
Future<MediaTimeChoice?> showSetMediaTimeDialog(
  BuildContext context, {
  required List<DiveProfilePoint> profile,
  required int initialElapsedSeconds,
  required bool isPinned,
  required AppSettings settings,
}) {
  return showDialog<MediaTimeChoice>(
    context: context,
    builder: (_) => SetMediaTimeDialog(
      profile: profile,
      initialElapsedSeconds: initialElapsedSeconds,
      isPinned: isPinned,
      settings: settings,
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
  });

  final List<DiveProfilePoint> profile;
  final int initialElapsedSeconds;
  final bool isPinned;
  final AppSettings settings;

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _inRange(int seconds) => seconds >= 0 && seconds <= _maxSeconds;

  void _onFieldChanged(String text) {
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
    Navigator.of(context).pop(MediaTimePinned(parsed));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final max = formatElapsedMmSs(_maxSeconds);
    final preview = _enrichment.calculateEnrichmentAtElapsed(
      profile: widget.profile,
      elapsedSeconds: _seconds,
    );

    return AlertDialog(
      title: Text(l10n.media_timeInDive_label),
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
