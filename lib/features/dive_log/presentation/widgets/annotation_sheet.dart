import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/minutes_seconds_field.dart';

/// What an annotation sheet returns (#4109): the second from the start of
/// the dive, the depth there when the dive has a profile, and the words.
typedef AnnotationSheetResult = ({
  int seconds,
  double? depthMeters,
  String words,
});

/// The fields every annotation sheet shares (#4109): the time box, the
/// depth at that time, and the words when the sheet has to ask for them
/// ([onWordsChanged] set). Lives inside the caller's [Form].
class AnnotationForm extends StatelessWidget {
  const AnnotationForm({
    super.key,
    required this.seconds,
    required this.maxSeconds,
    required this.onSecondsChanged,
    required this.units,
    this.words,
    this.onWordsChanged,
    this.depthMeters,
    this.autofocusWords = false,
  });

  final int? seconds;
  final int maxSeconds;
  final ValueChanged<int?> onSecondsChanged;
  final UnitFormatter units;
  final String? words;
  final ValueChanged<String>? onWordsChanged;
  final double? depthMeters;
  final bool autofocusWords;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final onWords = onWordsChanged;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onWords != null) ...[
          TextFormField(
            initialValue: words,
            autofocus: autofocusWords,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.diveLog_annotation_field_words,
              border: const OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? l10n.diveLog_annotation_words_required
                : null,
            onChanged: onWords,
          ),
          const SizedBox(height: 12),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wide enough for the label "Time from the start" at the
            // theme's label size, so it never ellipsizes.
            SizedBox(
              width: 190,
              child: MinutesSecondsField(
                seconds: seconds,
                onChanged: onSecondsChanged,
                label: l10n.diveLog_annotation_field_time,
                formatErrorText: l10n.diveLog_annotation_time_invalid,
                validator: (s) => s > maxSeconds
                    ? l10n.diveLog_annotation_time_outsideDive
                    : null,
              ),
            ),
            if (depthMeters != null) ...[
              const SizedBox(width: 16),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(
                  units.formatDepth(depthMeters),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
