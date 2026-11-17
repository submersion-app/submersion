part of 'media_info_panel.dart';

/// The info panel's File block: what the file is, and its time in the
/// dive, with Set time (issue #1090), held in a sitting (issue #4527).

class _FileSection extends ConsumerWidget {
  const _FileSection({
    required this.item,
    required this.units,
    required this.readOnly,
    required this.sitting,
  });

  final MediaItem item;
  final UnitFormatter units;
  final bool readOnly;
  final EditSession<PhotoRecord>? sitting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The info sheet is a route of its own, which the viewer's redraws do
    // not reach: the section follows the sitting itself (issue #4527).
    final session = sitting;
    if (session == null || session.isDisposed) return _section(context, ref);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => _section(context, ref),
    );
  }

  Widget _section(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final unknown = l10n.media_info_unknown;
    // The dive's profile decides whether the stored position is inside the
    // dive window and gives the Set-time dialog its range (issue #1090).
    final diveId = item.diveId;
    final profile = diveId == null
        ? const <DiveProfilePoint>[]
        : ref.watch(diveProvider(diveId)).value?.profile ??
              const <DiveProfilePoint>[];
    final profileLength = MediaDiveWindow.profileLengthSeconds(profile);
    // In a sitting the photo sits where its held time puts it, and Set time
    // starts from there and holds its choice there until Save.
    final session = sitting;
    final held = sittingIsOver(session, item.id) ? session : null;
    final timed = held == null ? item : photoShownItem(held, profile);
    final enrichment = timed.enrichment;
    final positioned = enrichment?.isWithinDiveWindow(profileLength) ?? false;
    final String timeInDive;
    if (!positioned) {
      timeInDive = unknown;
    } else {
      final formatted = formatElapsedMmSs(enrichment!.elapsedSeconds!);
      timeInDive = enrichment.isManual
          ? l10n.media_timeInDive_manual(formatted)
          : formatted;
    }
    final width = item.width;
    final height = item.height;
    final size = item.contentSizeBytes;
    final lat = item.latitude;
    final lon = item.longitude;
    // A browser reads the media facts and changes none (issue #4121).
    final canEdit = ref.watch(deviceCapabilitiesProvider).mediaAttach;

    return _Section(
      title: l10n.media_info_fileSection,
      actions: [
        // Pinning needs a profile to pin against.
        if (diveId != null &&
            profile.isNotEmpty &&
            canEdit &&
            !readOnly &&
            held != null)
          _SetTimeButton(
            item: timed,
            sitting: held,
            profile: profile,
            initialElapsedSeconds: setTimeSeedFor(
              timed,
              profileLengthSeconds: profileLength,
            ),
          ),
      ],
      children: [
        DiveDetailRow(
          label: l10n.media_info_filename,
          value: item.originalFilename ?? unknown,
        ),
        DiveDetailRow(
          label: l10n.media_info_type,
          value: mediaTypeLabel(l10n, item.mediaType),
        ),
        DiveDetailRow(
          label: l10n.media_info_dimensions,
          // Pixels are unit-system invariant, so this is one of the few
          // displayed quantities the diver's unit settings do not touch.
          value: (width != null && height != null)
              ? '$width x $height'
              : unknown,
        ),
        DiveDetailRow(
          label: l10n.media_info_size,
          value: size == null ? unknown : formatBytes(size),
        ),
        DiveDetailRow(
          label: l10n.media_info_taken,
          // takenAt is non-nullable on the row, so there is no unknown case.
          value: units.formatDateTime(item.takenAt, l10n: l10n),
        ),
        if (diveId != null)
          DiveDetailRow(label: l10n.media_timeInDive_label, value: timeInDive),
        if (lat != null && lon != null)
          DiveDetailRow(
            label: l10n.media_info_coordinates,
            value: '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
          ),
      ],
    );
  }
}

/// Opens the Set-time dialog and holds the diver's choice in the photo's
/// sitting until Save (issues #1090, #4527).
class _SetTimeButton extends ConsumerWidget {
  const _SetTimeButton({
    required this.item,
    required this.sitting,
    required this.profile,
    required this.initialElapsedSeconds,
  });

  final MediaItem item;
  final List<DiveProfilePoint> profile;
  final int initialElapsedSeconds;
  final EditSession<PhotoRecord> sitting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      icon: const Icon(Icons.push_pin_outlined),
      label: Text(context.l10n.media_timeInDive_setAction),
      onPressed: () async {
        final pinner = ref.read(mediaTimePinnerProvider);
        final automatic = pinner.automaticTimeFor(item);
        final choice = await showSetMediaTimeDialog(
          context,
          profile: profile,
          initialElapsedSeconds: initialElapsedSeconds,
          isPinned: item.manualElapsedSeconds != null,
          settings: ref.read(settingsProvider),
          automatic: automatic,
        );
        if (choice == null || !context.mounted) return;
        await holdTimeChoice(sitting, item.id, choice, automatic);
      },
    );
  }
}
