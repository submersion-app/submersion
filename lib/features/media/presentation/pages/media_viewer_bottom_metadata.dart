part of 'media_viewer_page.dart';

/// The viewer's bottom panel, built for the page.
extension _ViewerBottomPanel on _MediaViewerPageState {
  /// The bottom panel for [item]; for a video, its scrub bar is the panel's
  /// top row, so no tag can cover it (issue #4762).
  Widget _bottomPanel(
    BuildContext context, {
    required MediaItem item,
    required UnitFormatterSettings settings,
    required List<DiveProfilePoint>? diveProfile,
    required int profileLength,
    required bool photoLocked,
    required String? siteName,
    required bool miniProfileShown,
  }) {
    final video = item.isVideo ? _videoControllers[item.id] : null;
    return _BottomMetadataOverlay(
      item: item,
      settings: settings,
      onMomentTap: (tag) => _showMoment(item, tag),
      sitting: photoSitting,
      onSuggestionTap: photoSitting == null
          ? null
          : () {
              // Read at the tap, as Tag species does.
              final sitting = photoSitting;
              if (sitting == null) return;
              showMediaSpeciesSheet(context, item, sitting: sitting);
            },
      profileLengthSeconds: profileLength,
      // Pinning needs a profile to pin against; a dive with none has no
      // moments to choose from.
      onSetTime: diveProfile == null || diveProfile.isEmpty || photoLocked
          ? null
          : () => _setTimeInDive(item, diveProfile),
      siteName: siteName,
      controls: video == null
          ? null
          : VideoControlsBar(
              key: ValueKey('video_controls_${item.id}'),
              controller: video,
              mediaId: item.id,
              audio: _audio,
              // The controls hide 3 s after a reveal: hold them up while
              // scrubbing or under the mouse, so the bar is not pulled from
              // under the pointer.
              onHoldChanged: (held) => videoHoldChanged(video, held),
            ),
      // Clear of the mini profile in the corner.
      controlsClearance: miniProfileShown
          ? PositionedMiniProfileOverlay.reach + 8
          : 0,
      // The details stop short of the chart (issue #4921), past the
      // panel's own side inset.
      chartClearance: miniProfileShown
          ? PositionedMiniProfileOverlay.span +
                8 -
                _BottomMetadataOverlay.sideInset
          : 0,
      onHeightChanged: (height) =>
          _onBottomPanelHeight(height, video: item.isVideo),
    );
  }
}

/// Bottom overlay showing dive metadata for the current photo.
///
/// For a video, the playback [controls] are its top row (issue #4762): the
/// tags under them can push them up but never cover them.
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

  /// A video's scrub bar, drawn above everything else in the panel; null
  /// for a photo.
  final Widget? controls;

  /// How far up from the viewer's bottom edge the panel keeps clear under
  /// [controls], so they clear the mini profile chart in the corner.
  final double controlsClearance;

  /// How much further in from the right the details keep, past
  /// [sideInset], so no tag or reading runs over the mini profile chart in
  /// the corner (issue #4921). Right, not end: the chart is in the right
  /// corner whichever way the text runs.
  final double chartClearance;

  /// How far in from each side the details sit.
  static const double sideInset = 16;

  /// The panel's height, whenever it changes: the fish labels on a video
  /// keep above it.
  final ValueChanged<double>? onHeightChanged;

  const _BottomMetadataOverlay({
    required this.item,
    required this.settings,
    required this.profileLengthSeconds,
    this.onSetTime,
    this.siteName,
    this.onMomentTap,
    this.sitting,
    this.onSuggestionTap,
    this.controls,
    this.controlsClearance = 0,
    this.chartClearance = 0,
    this.onHeightChanged,
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
    final controls = this.controls;
    final onHeightChanged = this.onHeightChanged;

    final panel = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Inset from the sides as the rest of the panel is.
          if (controls != null)
            SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: controls,
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: controls == null ? 0 : controlsClearance,
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  sideInset,
                  controls == null ? 32 : 8,
                  sideInset + chartClearance,
                  16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  // Held to the clearance, the details keep to the bottom.
                  mainAxisAlignment: MainAxisAlignment.end,
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
                      item: item,
                      // Every species, from the "+N" chip: the sheet while
                      // the photo is unlocked, else the list (issue #4825).
                      onMoreTap:
                          onSuggestionTap ??
                          () => showMediaSpeciesListSheet(
                            context,
                            item,
                            sitting: sitting,
                          ),
                    ),
                    // Metadata row, onto a second line where the chart
                    // leaves too little room (issue #4921).
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Depth
                        if (enrichment?.depthMeters != null)
                          _MetadataChip(
                            icon: Icons.arrow_downward,
                            value: formatter.formatDepth(
                              enrichment!.depthMeters,
                              decimals: 1,
                            ),
                          ),

                        // Temperature
                        if (enrichment?.temperatureCelsius != null)
                          _MetadataChip(
                            icon: Icons.thermostat,
                            value: formatter.formatTemperature(
                              enrichment!.temperatureCelsius,
                              decimals: 0,
                            ),
                          ),

                        // Elapsed time: the diver's pin, the automatic
                        // position, or an explicit unknown for a linked item
                        // whose capture time fell outside the dive.
                        if (enrichment?.elapsedSeconds != null)
                          _MetadataChip(
                            icon: enrichment!.isManual
                                ? Icons.push_pin_outlined
                                : Icons.timer_outlined,
                            value: _formatElapsedTime(
                              enrichment.elapsedSeconds!,
                            ),
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
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
                            enrichment.matchConfidence !=
                                MatchConfidence.exact &&
                            enrichment.matchConfidence !=
                                MatchConfidence.interpolated &&
                            !enrichment.isManual)
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
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: onHeightChanged == null
          ? panel
          : SizeReporter(
              onChange: (size) => onHeightChanged(size.height),
              child: panel,
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
