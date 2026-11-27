import 'package:flutter/material.dart';

import 'package:submersion/core/opening_hours/opening_hours.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/opening_hours_validation.dart';
import 'package:submersion/features/dive_sites/presentation/editing/opening_schedule_editor.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

export 'package:submersion/features/dive_sites/presentation/editing/opening_hours_validation.dart'
    show siteOpeningHoursIsValid;

/// The Opening hours card's editor (issue #5073): open 24/7, or one or more
/// weekly schedules with optional seasons, and a note.
class SiteOpeningHoursCardEditor extends StatefulWidget {
  const SiteOpeningHoursCardEditor({super.key, required this.session});

  final EditSession<DiveSite> session;

  @override
  State<SiteOpeningHoursCardEditor> createState() =>
      _SiteOpeningHoursCardEditorState();
}

class _SiteOpeningHoursCardEditorState
    extends State<SiteOpeningHoursCardEditor> {
  late final TextEditingController _note = TextEditingController(
    text: _hours.note ?? '',
  );

  /// A stable identity per schedule, so deleting one keeps the others'
  /// name fields with their own schedules.
  List<int> _ids = [];
  int _nextId = 0;

  OpeningHours get _hours =>
      widget.session.valueOf(siteOpeningHoursField) ?? const OpeningHours();

  /// Hours with nothing in them are no hours.
  void _set(OpeningHours hours) =>
      widget.session.set(siteOpeningHoursField, hours.isEmpty ? null : hours);

  List<int> _idsFor(int count) {
    if (_ids.length != count) {
      _ids = [for (var i = 0; i < count; i++) _nextId++];
    }
    return _ids;
  }

  /// Another sitting (a retake after a whole-record operation): show its
  /// note, and give its schedules fresh editors.
  @override
  void didUpdateWidget(SiteOpeningHoursCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session == widget.session) return;
    _note.text = _hours.note ?? '';
    _ids = [];
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        final hours = _hours;
        final ids = _idsFor(hours.schedules.length);
        final invalid = invalidOpeningDays(hours);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                key: const ValueKey('hours_always_open'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.diveSites_hours_alwaysOpen),
                value: hours.alwaysOpen,
                onChanged: (on) => _set(hours.copyWith(alwaysOpen: on)),
              ),
              if (!hours.alwaysOpen) ...[
                if (hours.schedules.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      l10n.diveSites_hours_noSchedule,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (var i = 0; i < hours.schedules.length; i++)
                  OpeningScheduleEditor(
                    key: ValueKey('hours_schedule_editor_${ids[i]}'),
                    index: i,
                    schedule: hours.schedules[i],
                    invalidDays: {
                      for (final (s, d) in invalid)
                        if (s == i) d,
                    },
                    onChanged: (schedule) => _set(
                      hours.copyWith(
                        schedules: [...hours.schedules]..[i] = schedule,
                      ),
                    ),
                    onDelete: () {
                      _ids = [...ids]..removeAt(i);
                      _set(
                        hours.copyWith(
                          schedules: [...hours.schedules]..removeAt(i),
                        ),
                      );
                    },
                  ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const ValueKey('hours_add_schedule'),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.diveSites_hours_addSchedule),
                    onPressed: () {
                      _ids = [...ids, _nextId++];
                      _set(
                        hours.copyWith(
                          schedules: [
                            ...hours.schedules,
                            const OpeningSchedule(),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (invalid.isNotEmpty &&
                  !siteOpeningHoursIsValid(widget.session))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l10n.diveSites_hours_invalid,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              TextField(
                key: const ValueKey('hours_note'),
                controller: _note,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  labelText: l10n.diveSites_hours_note,
                  hintText: l10n.diveSites_hours_note_hint,
                ),
                onChanged: (text) => _set(
                  text.trim().isEmpty
                      ? _hours.copyWith(clearNote: true)
                      : _hours.copyWith(note: text),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
