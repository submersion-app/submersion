/// One choice for how often a manifest subscription is polled.
class PollIntervalOption {
  const PollIntervalOption({required this.seconds, required this.label});

  final int seconds;
  final String label;
}

/// The poll intervals offered when subscribing and when editing a
/// subscription. The 24-hour default sits in the middle of the list.
// TODO(media): l10n
const List<PollIntervalOption> kPollIntervalOptions = [
  PollIntervalOption(seconds: 3600, label: '1 hour'),
  PollIntervalOption(seconds: 21600, label: '6 hours'),
  PollIntervalOption(seconds: 86400, label: '24 hours'),
  PollIntervalOption(seconds: 604800, label: '7 days'),
];

/// [kPollIntervalOptions] plus [currentSeconds] when it is none of them (a
/// subscription synced from a version with other choices), so an edit
/// dialog can show what is set without changing it.
List<PollIntervalOption> pollIntervalOptionsIncluding(int currentSeconds) {
  if (kPollIntervalOptions.any((o) => o.seconds == currentSeconds)) {
    return kPollIntervalOptions;
  }
  final hours = currentSeconds / 3600;
  final label = hours >= 1
      ? '${hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1)} hours'
      : '${(currentSeconds / 60).round()} minutes';
  return [
    ...kPollIntervalOptions,
    PollIntervalOption(seconds: currentSeconds, label: label),
  ]..sort((a, b) => a.seconds.compareTo(b.seconds));
}
