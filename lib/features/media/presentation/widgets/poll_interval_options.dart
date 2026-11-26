import 'package:submersion/l10n/arb/app_localizations.dart';

/// One choice for how often a manifest subscription is polled.
class PollIntervalOption {
  const PollIntervalOption({required this.seconds});

  final int seconds;

  /// The interval as the diver reads it: whole days from two days up, else
  /// whole hours, else minutes.
  String label(AppLocalizations l10n) {
    const day = 86400;
    const hour = 3600;
    if (seconds >= 2 * day && seconds % day == 0) {
      return l10n.media_pollInterval_days(seconds ~/ day);
    }
    if (seconds % hour == 0) {
      return l10n.media_pollInterval_hours(seconds ~/ hour);
    }
    final minutes = (seconds / 60).round();
    return l10n.media_pollInterval_minutes(minutes < 1 ? 1 : minutes);
  }
}

/// The poll intervals offered when subscribing and when editing a
/// subscription. The 24-hour default sits in the middle of the list.
const List<PollIntervalOption> kPollIntervalOptions = [
  PollIntervalOption(seconds: 3600),
  PollIntervalOption(seconds: 21600),
  PollIntervalOption(seconds: 86400),
  PollIntervalOption(seconds: 604800),
];

/// [kPollIntervalOptions] plus [currentSeconds] when it is none of them (a
/// subscription synced from a version with other choices), so an edit
/// dialog can show what is set without changing it.
List<PollIntervalOption> pollIntervalOptionsIncluding(int currentSeconds) {
  if (kPollIntervalOptions.any((o) => o.seconds == currentSeconds)) {
    return kPollIntervalOptions;
  }
  return [...kPollIntervalOptions, PollIntervalOption(seconds: currentSeconds)]
    ..sort((a, b) => a.seconds.compareTo(b.seconds));
}
