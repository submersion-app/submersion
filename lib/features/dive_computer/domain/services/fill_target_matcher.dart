import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A download's wall-clock window, flagged UTC as dive times are.
typedef IncomingDiveWindow = ({DateTime start, DateTime end});

/// What [FillTargetMatcher.match] found: each paired download's target, and
/// the downloads that fitted more than one draft with those drafts' ids, so
/// a caller can say "two candidates" rather than "no match".
class FillPairing {
  const FillPairing({required this.pairs, required this.ambiguous});

  final Map<int, String> pairs;
  final Map<int, List<String>> ambiguous;
}

/// Pairs downloaded dives with the dives waiting for their readings: drafts
/// marked at the site (issue #637) and planned dives (issues #2002 and
/// #4003). Pure: takes windows and entities, returns index-to-id maps.
///
/// Drafts come first, because a draft's taps pin its time within minutes
/// while a plan only names a day. A download fits a draft when its window
/// overlaps the draft's entry-to-exit window widened by [draftTolerance] on
/// each side for computer clock drift; an open draft reaches three hours past
/// its entry. A download that fits two drafts, or a draft that two downloads
/// fit, is left for the diver, and such a download is not offered to a plan
/// either: it belongs to one of those drafts.
///
/// Plans take the downloads no draft fitted, by the existing rule: a
/// download fits a plan on its own calendar day or the day before, so a dive
/// pushed back a day, or a night dive logged after midnight, still fills.
/// Fits are taken smallest start-time gap first, each download and each plan
/// once, so a download just after midnight goes to the previous night's plan
/// rather than the next morning's. Ties go to the earlier download, then the
/// earlier plan. Both start times are the dive's wall clock flagged UTC, so
/// the day is their own date, compared as is: converting them to the
/// device's zone would move the day boundary by its UTC offset and pair dives
/// from different days near midnight.
///
/// A target carrying both flags is matched as a draft: it happened.
class FillTargetMatcher {
  const FillTargetMatcher({this.draftTolerance = const Duration(minutes: 10)});

  final Duration draftTolerance;

  /// How far an open draft (no exit yet) reaches past its entry.
  static const openDraftReach = Duration(hours: 3);

  Map<int, String> pair({
    required List<IncomingDiveWindow> incoming,
    required List<Dive> targets,
  }) => match(incoming: incoming, targets: targets).pairs;

  FillPairing match({
    required List<IncomingDiveWindow> incoming,
    required List<Dive> targets,
  }) {
    final drafts = [
      for (final t in targets)
        if (t.isDraft) t,
    ];
    final plans = [
      for (final t in targets)
        if (t.isPlanned && !t.isDraft) t,
    ];

    final pairs = <int, String>{};
    final ambiguous = <int, List<String>>{};

    // Drafts: an unambiguous fit both ways, or nothing.
    final fitsByDownload = <int, List<String>>{};
    final fitsByDraft = <String, List<int>>{};
    for (var i = 0; i < incoming.length; i++) {
      for (final d in drafts) {
        if (_fitsDraft(incoming[i], d)) {
          (fitsByDownload[i] ??= []).add(d.id);
          (fitsByDraft[d.id] ??= []).add(i);
        }
      }
    }
    for (final entry in fitsByDownload.entries) {
      final ids = entry.value;
      if (ids.length > 1) {
        ambiguous[entry.key] = ids;
      } else if (fitsByDraft[ids.single]!.length == 1) {
        pairs[entry.key] = ids.single;
      } else {
        ambiguous[entry.key] = ids;
      }
    }

    // Plans: the downloads no draft fitted.
    final rest = [
      for (var i = 0; i < incoming.length; i++)
        if (!fitsByDownload.containsKey(i)) i,
    ];
    pairs.addAll(_pairPlans(rest, incoming, plans));
    return FillPairing(pairs: pairs, ambiguous: ambiguous);
  }

  bool _fitsDraft(IncomingDiveWindow dive, Dive draft) {
    final entry = draft.entryTime ?? draft.dateTime;
    final exit = draft.exitTime ?? entry.add(openDraftReach);
    final from = entry.subtract(draftTolerance);
    final to = exit.add(draftTolerance);
    return !dive.end.isBefore(from) && !dive.start.isAfter(to);
  }

  Map<int, String> _pairPlans(
    List<int> indices,
    List<IncomingDiveWindow> incoming,
    List<Dive> plannedDives,
  ) {
    final plans = [
      for (final d in plannedDives)
        (id: d.id, start: d.entryTime ?? d.dateTime),
    ];
    final fits =
        <({int index, DateTime incoming, String plan, DateTime planned})>[
          for (final i in indices)
            for (final p in plans)
              if (_fitsPlan(incoming[i].start, p.start))
                (
                  index: i,
                  incoming: incoming[i].start,
                  plan: p.id,
                  planned: p.start,
                ),
        ]..sort((a, b) {
          final gap = a.incoming
              .difference(a.planned)
              .abs()
              .compareTo(b.incoming.difference(b.planned).abs());
          if (gap != 0) return gap;
          final byIncoming = a.incoming.compareTo(b.incoming);
          if (byIncoming != 0) return byIncoming;
          return a.planned.compareTo(b.planned);
        });

    final result = <int, String>{};
    final taken = <String>{};
    for (final fit in fits) {
      if (result.containsKey(fit.index) || taken.contains(fit.plan)) continue;
      result[fit.index] = fit.plan;
      taken.add(fit.plan);
    }
    return result;
  }

  static bool _fitsPlan(DateTime incoming, DateTime planned) {
    final day = _day(planned);
    return day == _day(incoming) ||
        day == DateTime(incoming.year, incoming.month, incoming.day - 1);
  }

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);
}
