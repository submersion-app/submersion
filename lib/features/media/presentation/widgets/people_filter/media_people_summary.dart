import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/media/presentation/widgets/people_filter/media_people_selection.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// What the People row of the library filter reads for [selection]: "Any",
/// "No one tagged", or the first two people (Me first, then buddies by name)
/// and how many more, e.g. "Me, Alex +3".
///
/// [buddies] is null while they load. A picked id missing from a loaded
/// list is a removed buddy and reads as one; while loading, the picked
/// buddies can only be counted, never called removed.
String mediaPeopleSummary(
  AppLocalizations l10n,
  MediaPeopleSelection selection,
  List<Buddy>? buddies,
) {
  if (selection.noPeople) return l10n.media_library_filter_noPeople;
  if (selection.isEmpty) return l10n.media_library_filter_any;

  final picked = selection.buddyIds;
  final named = [
    for (final b in buddies ?? const <Buddy>[])
      if (picked.contains(b.id)) b.name,
  ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  // Removed buddies all share one label, so it is named once and the
  // rest of them counted, rather than read out as "Removed buddy, Removed
  // buddy".
  final removed = buddies == null ? 0 : picked.length - named.length;
  final names = [
    if (selection.includeMe) l10n.media_people_me,
    ...named,
    if (removed > 0) l10n.media_people_removedBuddy,
  ];
  final unnamed = buddies == null ? picked.length : 0;
  final total =
      (selection.includeMe ? 1 : 0) + named.length + removed + unnamed;

  if (names.isEmpty) return l10n.media_library_filter_peopleCount(total);
  final shown = names.length == 1
      ? names.first
      : l10n.media_library_filter_peopleTwo(names[0], names[1]);
  final more = total - (names.length == 1 ? 1 : 2);
  return more == 0
      ? shown
      : l10n.media_library_filter_peopleAndMore(shown, more);
}
