/// One unlinked route `NavTrackMatchService.sweep` looked at: `routeId`,
/// and `suggestedDiveId` when exactly one dive's time window overlaps it
/// (null when none or several do -- either way, confirming or picking a
/// different dive is up to the diver, never automatic).
typedef NavTrackMatchSuggestion = ({String routeId, String? suggestedDiveId});
