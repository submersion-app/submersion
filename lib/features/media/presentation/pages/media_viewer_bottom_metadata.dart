part of 'media_viewer_page.dart';

/// Bottom overlay showing dive metadata for the current photo.
class _BottomMetadataOverlay extends StatelessWidget {
  final MediaItem item;
  final UnitFormatterSettings settings;
  final String? siteName;

  /// Length of the dive's profile, for the dive-window tolerance.
  final int profileLengthSeconds;

  /// Opens the Set-time dialog (issue #1090); null when there is no profile
  /// to pin against, which also hides the affordance.
  final VoidCallback? onSetTime;

  /// A video face tag's chip was tapped (issue #1745).
  final ValueChanged<MediaPersonTag>? onMomentTap;

  /// The photo's sitting, whose held tags the chips show (issue #4527).
  final EditSession<PhotoRecord>? sitting;

  /// Opens the species sheet from a suggested species (issue #4668); null
  /// while the photo is locked.
  final VoidCallback? onSuggestionTap;

  const _BottomMetadataOverlay({
    required this.item,
    required this.settings,
    required this.profileLengthSeconds,
    this.onSetTime,
    this.siteName,
    this.onMomentTap,
    this.sitting,
    this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Depth, temperature and the elapsed chip describe a moment in the
    // dive, so they only render for a position inside the dive window (or
    // pinned by the diver). Outside it the raw offset used to print as
    // `+1879:28`; now the chip says the time is unknown and offers the fix.
    final positioned =
        item.enrichment?.isWithinDiveWindow(profileLengthSeconds) ?? false;
    final enrichment = positioned ? item.enrichment : null;
    final formatter = UnitFormatter(settings);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Site name
                if (siteName != null && siteName!.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          siteName!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                MediaPeopleChipsRow(
                  mediaId: item.id,
                  onMomentTap: onMomentTap,
                  sitting: sitting,
                ),
                MediaSpeciesChipsRow(
                  mediaId: item.id,
                  sitting: sitting,
                  onSuggestionTap: onSuggestionTap,
                ),
                // Metadata row
                Row(
                  children: [
                    // Depth
                    if (enrichment?.depthMeters != null) ...[
                      _MetadataChip(
                        icon: Icons.arrow_downward,
                        value: formatter.formatDepth(
                          enrichment!.depthMeters,
                          decimals: 1,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],

                    // Temperature
                    if (enrichment?.temperatureCelsius != null) ...[
                      _MetadataChip(
                        icon: Icons.thermostat,
                        value: formatter.formatTemperature(
                          enrichment!.temperatureCelsius,
                          decimals: 0,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],

                    // Elapsed time: the diver's pin, the automatic
                    // position, or an explicit unknown for a linked item
                    // whose capture time fell outside the dive.
                    if (enrichment?.elapsedSeconds != null)
                      _MetadataChip(
                        icon: enrichment!.isManual
                            ? Icons.push_pin_outlined
                            : Icons.timer_outlined,
                        value: _formatElapsedTime(enrichment.elapsedSeconds!),
                        onTap: onSetTime,
                        tooltip: l10n.media_timeInDive_setAction,
                      )
                    else if (item.diveId != null && onSetTime != null)
                      _MetadataChip(
                        icon: Icons.timer_off_outlined,
                        value: l10n.media_timeInDive_unknown,
                        onTap: onSetTime,
                        tooltip: l10n.media_timeInDive_setAction,
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // Timestamp row
                Row(
                  children: [
                    Text(
                      formatter.formatDateTime(item.takenAt, l10n: l10n),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),

                    // Confidence indicator. A manual position is the
                    // diver's own statement, not an estimate, so it gets
                    // the pin icon on the chip instead of a warning here.
                    if (enrichment != null &&
                        enrichment.matchConfidence != MatchConfidence.exact &&
                        enrichment.matchConfidence !=
                            MatchConfidence.interpolated &&
                        !enrichment.isManual) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          enrichment.matchConfidence.localizedName(
                            context.l10n,
                          ),
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// `+3:00` into the dive, `-1:30` for a surface shot just before it; the
  /// formatter already carries the minus, so the plus is only for the rest.
  String _formatElapsedTime(int seconds) {
    final formatted = formatElapsedMmSs(seconds);
    return seconds < 0 ? formatted : '+$formatted';
  }
}

/// Small metadata chip with icon and value.
class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String value;

  /// Makes the chip an action (the elapsed chip opens the Set-time dialog).
  final VoidCallback? onTap;
  final String? tooltip;

  const _MetadataChip({
    required this.icon,
    required this.value,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    if (onTap == null) return row;
    final tappable = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: row,
      ),
    );
    return tooltip == null
        ? tappable
        : Tooltip(message: tooltip!, child: tappable);
  }
}
