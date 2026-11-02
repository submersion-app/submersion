import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_depth_at.dart';
import 'package:submersion/features/dive_log/presentation/widgets/annotation_marker_label.dart';
import 'package:submersion/features/dive_log/presentation/widgets/annotation_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/mini_profile_picker.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The sheet the notes editor's pin opens (#4109): when the selected
/// [words] happened. A time box, the dive's small profile to point at (or a
/// note that there is none), and a words field when nothing was selected.
/// Returns null on cancel.
Future<AnnotationSheetResult?> showAnnotationTimeSheet(
  BuildContext context, {
  required String? words,
  required List<DiveProfilePoint> profile,
  required int maxSeconds,
  int? initialSeconds,
  double? initialDepthMeters,
  required UnitFormatter units,
}) {
  return showModalBottomSheet<AnnotationSheetResult>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AnnotationTimeSheet(
      words: words,
      profile: profile,
      maxSeconds: maxSeconds,
      initialSeconds: initialSeconds,
      initialDepthMeters: initialDepthMeters,
      units: units,
    ),
  );
}

class _AnnotationTimeSheet extends StatefulWidget {
  const _AnnotationTimeSheet({
    required this.words,
    required this.profile,
    required this.maxSeconds,
    required this.initialSeconds,
    required this.initialDepthMeters,
    required this.units,
  });

  final String? words;
  final List<DiveProfilePoint> profile;
  final int maxSeconds;
  final int? initialSeconds;
  final double? initialDepthMeters;
  final UnitFormatter units;

  @override
  State<_AnnotationTimeSheet> createState() => _AnnotationTimeSheetState();
}

class _AnnotationTimeSheetState extends State<_AnnotationTimeSheet> {
  final _formKey = GlobalKey<FormState>();
  late int? _seconds = widget.initialSeconds;
  late String _words = widget.words ?? '';

  bool get _asksForWords => widget.words == null || widget.words!.isEmpty;

  double? get _depth {
    final seconds = _seconds;
    if (widget.profile.isEmpty) return widget.initialDepthMeters;
    if (seconds == null) return null;
    return profileDepthAt(widget.profile, seconds);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final seconds = _seconds;
    if (seconds == null) return;
    Navigator.of(context).pop<AnnotationSheetResult>((
      seconds: seconds,
      depthMeters: _depth,
      words: _words.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final title = _asksForWords
        ? l10n.diveLog_annotation_sheetTitle_new
        : l10n.diveLog_annotation_sheetTitle_words(
            cutAtWord(widget.words!, maxChars: 40),
          );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            AnnotationForm(
              seconds: _seconds,
              maxSeconds: widget.maxSeconds,
              onSecondsChanged: (s) => setState(() => _seconds = s),
              units: widget.units,
              words: _asksForWords ? _words : widget.words,
              onWordsChanged: _asksForWords ? (w) => _words = w : null,
              depthMeters: _depth,
              autofocusWords: _asksForWords,
            ),
            const SizedBox(height: 12),
            if (widget.profile.isEmpty)
              Text(
                l10n.diveLog_annotation_noProfile,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              Text(
                l10n.diveLog_annotation_pickOnProfile,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              MiniProfilePicker(
                profile: widget.profile,
                selectedSeconds: _seconds,
                onPick: (s) => setState(() => _seconds = s),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.common_action_cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submit,
                  child: Text(
                    _asksForWords
                        ? l10n.diveLog_annotation_action_add
                        : l10n.diveLog_annotation_action_annotate,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
