import 'package:flutter/material.dart';

import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/editing/gps_track_card_ids.dart';
import 'package:submersion/features/gps_log/presentation/editing/gps_track_edit_fields.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_timeline_scrubber.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

/// The GPS track page's cards that can be edited in place (issue #4527,
/// phase 3), by card id.
final Map<GpsTrackCardId, EditCard<GpsTrack>> gpsTrackEditCards = {
  // Shown whenever the page is unlocked, named or not: offered in the
  // strip it would read "GPS Track", which says nothing about a name.
  GpsTrackCardId.header: EditCard<GpsTrack>(
    id: GpsTrackCardId.header.name,
    title: (context) =>
        GpsTrackCardId.header.localizedDisplayName(context.l10n),
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        GpsTrackHeaderCardEditor(session: session),
  ),
  GpsTrackCardId.trim: EditCard<GpsTrack>(
    id: GpsTrackCardId.trim.name,
    title: (context) => GpsTrackCardId.trim.localizedDisplayName(context.l10n),
    isEmpty: (t) => t.trimStartTime == null && t.trimEndTime == null,
    editorBuilder: (context, session) =>
        GpsTrackTrimCardEditor(session: session),
  ),
};

/// The header block's editor: the track's own name. Blank falls back to
/// the file or device it came from.
class GpsTrackHeaderCardEditor extends StatefulWidget {
  const GpsTrackHeaderCardEditor({super.key, required this.session});

  final EditSession<GpsTrack> session;

  @override
  State<GpsTrackHeaderCardEditor> createState() =>
      _GpsTrackHeaderCardEditorState();
}

class _GpsTrackHeaderCardEditorState extends State<GpsTrackHeaderCardEditor> {
  late final _binding = FieldTextBinding<GpsTrack, String?>(
    session: widget.session,
    field: gpsTrackNameField,
    format: (value) => value ?? '',
    // Any text is a value: blank is no name.
    parse: FieldValue<String?>.new,
  );

  @override
  void dispose() {
    _binding.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    key: const ValueKey('gps-track-name-field'),
    controller: _binding.controller,
    autofocus: true,
    decoration: InputDecoration(
      hintText: context.l10n.gpsTrack_editCard_nameHint,
    ),
  );
}

/// The Trim card's editor: a range over the whole recording, starting at
/// the trim being changed, and Reset trim.
///
/// The trim is set when a drag ends, not on every frame of it: the page's
/// statistics walk every fix of the track again for each change.
class GpsTrackTrimCardEditor extends StatelessWidget {
  const GpsTrackTrimCardEditor({super.key, required this.session});

  final EditSession<GpsTrack> session;

  @override
  Widget build(BuildContext context) {
    final points = session.stored.points;
    final l10n = context.l10n;
    if (points.length < 2) return const SizedBox.shrink();
    final spanStart = points.first.timestamp * 1000;
    final spanEnd = points.last.timestamp * 1000;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final trim = session.valueOf(gpsTrackTrimField);
        final hasTrim = trim.startMs != null || trim.endMs != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TrackTimelineScrubber(
              // A new scrubber once the trim is reset, so its handles move
              // back to the ends.
              key: ValueKey('gps-track-trim-scrubber-$hasTrim'),
              startMs: spanStart,
              endMs: spanEnd,
              initialStartMs: trim.startMs,
              initialEndMs: trim.endMs,
              mode: TrackScrubberMode.range,
              onChanged: (_, _) {},
              // A handle left at its end of the recording cuts nothing
              // there: that end stays open.
              onChangeEnd: (start, end) => session.set(gpsTrackTrimField, (
                startMs: start <= spanStart ? null : start,
                endMs: end >= spanEnd ? null : end,
              )),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: const ValueKey('gps-track-reset-trim'),
                onPressed: hasTrim
                    ? () => session.set(gpsTrackTrimField, (
                        startMs: null,
                        endMs: null,
                      ))
                    : null,
                child: Text(l10n.gpsTrack_action_resetTrim),
              ),
            ),
          ],
        );
      },
    );
  }
}
