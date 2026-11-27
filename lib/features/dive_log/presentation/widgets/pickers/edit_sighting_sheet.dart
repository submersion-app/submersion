import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_depth_at.dart';
import 'package:submersion/features/dive_log/presentation/widgets/mini_profile_picker.dart';
import 'package:submersion/shared/widgets/forms/minutes_seconds_field.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/sighting_abundance_picker.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the sheet needs to set when in the dive a sighting was seen
/// (issue #5092): the profile the chart draws (empty for none), the latest
/// second allowed ([sightingTimeMaxSeconds]) and the diver's units.
@immutable
class SightingTimeContext {
  const SightingTimeContext({
    required this.profile,
    required this.maxSeconds,
    required this.units,
  });

  final List<DiveProfilePoint> profile;
  final int maxSeconds;
  final UnitFormatter units;
}

/// Edit sighting sheet
class EditSightingSheet extends StatefulWidget {
  final Sighting sighting;
  final void Function(Sighting) onSave;
  final VoidCallback onDelete;

  /// Where the time can be set. Null hides "Seen at", as for bulk edit,
  /// whose dives have no one timeline.
  final SightingTimeContext? time;

  const EditSightingSheet({
    super.key,
    required this.sighting,
    required this.onSave,
    required this.onDelete,
    this.time,
  });

  @override
  State<EditSightingSheet> createState() => _EditSightingSheetState();
}

class _EditSightingSheetState extends State<EditSightingSheet> {
  late SightingAmount _amount;
  late TextEditingController _notesController;
  late int? _seenAt = widget.sighting.seenAtSeconds;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _amount = widget.sighting.amount;
    _notesController = TextEditingController(text: widget.sighting.notes);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scrolls: the "How many" chips and stepper plus the keyboard for the
    // notes do not fit a small phone's height.
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  localizedSpeciesName(
                    context.l10n,
                    widget.sighting.speciesId,
                    widget.sighting.speciesName,
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  tooltip: context.l10n.diveLog_editSighting_remove,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: Text(
                          context.l10n.diveLog_editSighting_removeTitle,
                        ),
                        content: Text(
                          context.l10n.diveLog_editSighting_removeConfirm(
                            localizedSpeciesName(
                              context.l10n,
                              widget.sighting.speciesId,
                              widget.sighting.speciesName,
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: Text(context.l10n.common_action_cancel),
                          ),
                          FilledButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              widget.onDelete();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                            ),
                            child: Text(
                              context.l10n.diveLog_editSighting_remove,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            SightingAbundancePicker(
              value: _amount,
              onChanged: (v) => setState(() => _amount = v),
            ),
            if (widget.time case final time?) ...[
              const SizedBox(height: 24),
              _seenAtSection(context, time),
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: context.l10n.diveLog_editSighting_notes,
                hintText: context.l10n.diveLog_editSighting_notesHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (!(_formKey.currentState?.validate() ?? true)) return;
                widget.onSave(
                  widget.sighting.copyWith(
                    abundance: _amount.abundance,
                    count: _amount.count,
                    notes: _notesController.text,
                    seenAtSeconds: _seenAt,
                    clearSeenAt: _seenAt == null,
                  ),
                );
              },
              child: Text(context.l10n.diveLog_editSighting_save),
            ),
          ],
        ),
      ),
    );
  }

  /// "Seen at": a time box with a clear button, the depth then, and the
  /// dive's small profile to point at when it has one.
  Widget _seenAtSection(BuildContext context, SightingTimeContext time) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final seenAt = _seenAt;
    final depth = seenAt == null || time.profile.isEmpty
        ? null
        : profileDepthAt(time.profile, seenAt);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 190,
                child: MinutesSecondsField(
                  seconds: seenAt,
                  onChanged: (s) => setState(() => _seenAt = s),
                  label: l10n.diveLog_editSighting_seenAt,
                  formatErrorText: l10n.diveLog_annotation_time_invalid,
                  validator: (s) => s > time.maxSeconds
                      ? l10n.diveLog_annotation_time_outsideDive
                      : null,
                  allowEmpty: true,
                  suffixIcon: seenAt == null
                      ? null
                      : IconButton(
                          key: const ValueKey('sighting_seen_at_clear'),
                          icon: const Icon(Icons.clear),
                          tooltip: l10n.diveLog_editSighting_seenAtClear,
                          onPressed: () => setState(() => _seenAt = null),
                        ),
                ),
              ),
              if (depth != null) ...[
                const SizedBox(width: 16),
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(
                    time.units.formatDepth(depth),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (time.profile.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              l10n.diveLog_annotation_pickOnProfile,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            MiniProfilePicker(
              profile: time.profile,
              selectedSeconds: seenAt,
              onPick: (s) => setState(() => _seenAt = s),
            ),
          ],
        ],
      ),
    );
  }
}
