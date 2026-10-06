import 'package:submersion/core/constants/certification_enums.dart';
import 'package:submersion/core/constants/certification_levels.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/domain/entities/credential_currency.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/domain/entities/dive_activity_index.dart';
import 'package:submersion/features/certifications/domain/services/calendar_days.dart';

/// The synthesized rule that keeps the old expiring-certifications warning
/// for a dated card no catalog rule covers. Not a database row; a pref keyed
/// by this id mutes or retunes it per card.
const kCardExpiryRuleId = 'card_expiry';

final _cardExpiryRule = CurrencyRule(
  id: kCardExpiryRuleId,
  name: 'Card expiry',
  clockKind: CurrencyClockKind.date,
  lapseDays: 0,
  leadDays: 90,
  isBuiltIn: true,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

/// Evaluates every rule against every certification (issue #2267). Pure and
/// total: no database, no clock read, nothing thrown.
List<CredentialCurrency> evaluateCurrency({
  required List<Certification> certifications,
  required List<CurrencyRule> rules,
  required List<CurrencyPref> prefs,
  required List<CurrencyEvent> events,
  required DiveActivityIndex activity,
  required DateTime now,
}) {
  final today = calendarDay(now);
  // Only a copy this build can read replaces its built-in: an unreadable
  // copy matches nothing, and hiding the built-in too would silence the
  // card entirely.
  final superseded = {
    for (final r in rules)
      if (!r.isBuiltIn && !r.unreadableScope && r.supersedesRuleId != null)
        r.supersedesRuleId!,
  };
  final live = [
    for (final r in rules)
      if (!(r.isBuiltIn && superseded.contains(r.id))) r,
  ];
  // Only the evaluated certifications' prefs and events count: in a
  // multi-diver library another diver's refresher must not reset this
  // diver's rule.
  final certIds = {for (final c in certifications) c.id};
  final prefByKey = {
    for (final p in prefs)
      if (certIds.contains(p.certificationId)) (p.certificationId, p.ruleId): p,
  };
  final scopedEvents = [
    for (final e in events)
      if (certIds.contains(e.certificationId)) e,
  ];
  // A custom rule that supersedes a built-in inherits the built-in's prefs
  // and events, so copying a rule in Manage keeps the diver's mutes,
  // overrides and logged refreshers. Its own pref wins.
  CurrencyPref? prefFor(String certId, CurrencyRule rule) =>
      prefByKey[(certId, rule.id)] ??
      (rule.supersedesRuleId == null
          ? null
          : prefByKey[(certId, rule.supersedesRuleId!)]);

  final out = <CredentialCurrency>[];
  for (final cert in certifications) {
    final matched = [
      for (final r in live)
        if (cert.credentials.any((c) => _matches(r, c))) r,
    ];
    var dateCovered = false;
    for (final rule in matched) {
      final status = _evaluate(
        cert,
        rule,
        prefFor(cert.id, rule),
        scopedEvents,
        activity,
        today,
      );
      if (status == null) continue;
      if (rule.clockKind == CurrencyClockKind.date) dateCovered = true;
      out.add(status);
    }
    if (!dateCovered && cert.expiryDate != null) {
      final status = _evaluate(
        cert,
        _cardExpiryRule,
        prefByKey[(cert.id, kCardExpiryRuleId)],
        scopedEvents,
        activity,
        today,
      );
      if (status != null) out.add(status);
    }
  }
  return out;
}

bool _matches(CurrencyRule rule, CertificationCredential c) {
  // A scope this build cannot read must not decode to "any".
  if (rule.unreadableScope) return false;
  // Credentials store ids (issue #690): a built-in's enum name or a custom
  // id. Scopes name built-ins only, so a custom agency or level matches only
  // a rule that leaves that dimension open.
  if (rule.agencies.isNotEmpty &&
      !rule.agencies.contains(CertificationAgency.fromId(c.agency))) {
    return false;
  }
  if (rule.levels.isEmpty) return true;
  final level = CertificationLevel.fromId(c.level);
  return level != null && rule.levels.contains(level);
}

CredentialCurrency? _evaluate(
  Certification cert,
  CurrencyRule rule,
  CurrencyPref? pref,
  List<CurrencyEvent> events,
  DiveActivityIndex activity,
  DateTime today,
) {
  final lapse = pref?.lapseDaysOverride ?? rule.lapseDays;
  final lead = pref?.leadDaysOverride ?? rule.leadDays;
  final muted = pref?.muted ?? false;

  final anchor = rule.clockKind == CurrencyClockKind.date
      ? _dateAnchor(cert, rule, events, lapse)
      : _activityAnchor(cert, rule, pref, events, activity, lapse);
  if (anchor == null) {
    // A date rule with no date has no clock and no row. An activity rule
    // with nothing counted yet keeps a neutral row that never warns, so
    // the diver can still change which dives count.
    if (rule.clockKind == CurrencyClockKind.date) return null;
    return CredentialCurrency(
      certification: cert,
      rule: rule,
      severity: CurrencySeverity.current,
      anchor: today,
      origin: CurrencyAnchorOrigin.noCountedDive,
      dueDate: today,
      lapseDays: lapse,
      leadDays: lead,
      muted: muted,
    );
  }

  final CurrencySeverity severity;
  if (!today.isBefore(anchor.due)) {
    severity = CurrencySeverity.lapsed;
  } else if (!today.isBefore(addCalendarDays(anchor.due, -lead))) {
    severity = CurrencySeverity.dueSoon;
  } else {
    severity = CurrencySeverity.current;
  }
  return CredentialCurrency(
    certification: cert,
    rule: rule,
    severity: severity,
    anchor: anchor.day,
    origin: anchor.origin,
    dueDate: anchor.due,
    lapseDays: lapse,
    leadDays: lead,
    muted: muted,
    anchorEventType: anchor.eventType,
  );
}

typedef _Anchor = ({
  DateTime day,
  DateTime due,
  CurrencyAnchorOrigin origin,
  CurrencyEventType? eventType,
});

/// Card expiry and the newest own event for the rule both count; the later
/// due date wins, so a renewal logged after an expiry clears the lapse.
/// The issue date plus the interval applies only when neither exists.
_Anchor? _dateAnchor(
  Certification cert,
  CurrencyRule rule,
  List<CurrencyEvent> events,
  int lapse,
) {
  final candidates = <_Anchor>[];
  final expiry = cert.expiryDate;
  if (expiry != null) {
    final day = calendarDay(expiry);
    candidates.add((
      day: day,
      due: day,
      origin: CurrencyAnchorOrigin.cardExpiry,
      eventType: null,
    ));
  }
  // The synthesized card-expiry status follows the printed date alone: a
  // renewed card is a new expiry date on the card, not a ledger event.
  final own = rule.id == kCardExpiryRuleId
      ? null
      : _newest([
          for (final e in events)
            if (e.certificationId == cert.id && _resets(e, rule)) e,
        ]);
  if (own != null) {
    final day = calendarDay(own.eventDate);
    candidates.add((
      day: day,
      due: addCalendarDays(day, lapse),
      origin: CurrencyAnchorOrigin.ledgerEvent,
      eventType: own.eventType,
    ));
  }
  if (candidates.isEmpty && cert.issueDate != null) {
    final day = calendarDay(cert.issueDate!);
    candidates.add((
      day: day,
      due: addCalendarDays(day, lapse),
      origin: CurrencyAnchorOrigin.cardIssue,
      eventType: null,
    ));
  }
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) => b.due.compareTo(a.due));
  return candidates.first;
}

/// The later of the last qualifying dive and the newest event that resets
/// the rule: one for this rule on any card, or a rule-less one on this card.
_Anchor? _activityAnchor(
  Certification cert,
  CurrencyRule rule,
  CurrencyPref? pref,
  List<CurrencyEvent> events,
  DiveActivityIndex activity,
  int lapse,
) {
  final types = pref?.countedDiveTypeIds ?? rule.countedDiveTypeIds;
  final modes = pref?.countedDiveModes ?? rule.countedDiveModes;
  final anyDive = types.isEmpty && modes.isEmpty;
  final DateTime? lastDive = anyDive
      ? activity.lastDiveAt
      : _latest([
          for (final t in types) activity.lastDiveByTypeId[t],
          for (final m in modes) activity.lastDiveByMode[m],
        ]);

  final event = _newest([
    for (final e in events)
      if (_resets(e, rule) ||
          (e.ruleId == null && e.certificationId == cert.id))
        e,
  ]);
  final eventDay = event == null ? null : calendarDay(event.eventDate);

  if (lastDive == null && eventDay == null) return null;
  if (eventDay != null && (lastDive == null || eventDay.isAfter(lastDive))) {
    return (
      day: eventDay,
      due: addCalendarDays(eventDay, lapse),
      origin: CurrencyAnchorOrigin.ledgerEvent,
      eventType: event!.eventType,
    );
  }
  final day = calendarDay(lastDive!);
  return (
    day: day,
    due: addCalendarDays(day, lapse),
    origin: anyDive
        ? CurrencyAnchorOrigin.lastDive
        : CurrencyAnchorOrigin.lastQualifyingDive,
    eventType: null,
  );
}

/// Whether [e] was logged against [rule], or against the built-in it
/// supersedes.
bool _resets(CurrencyEvent e, CurrencyRule rule) =>
    e.ruleId != null &&
    (e.ruleId == rule.id || e.ruleId == rule.supersedesRuleId);

CurrencyEvent? _newest(List<CurrencyEvent> events) {
  if (events.isEmpty) return null;
  return events.reduce((a, b) => b.eventDate.isAfter(a.eventDate) ? b : a);
}

DateTime? _latest(Iterable<DateTime?> days) {
  DateTime? best;
  for (final d in days) {
    if (d != null && (best == null || d.isAfter(best))) best = d;
  }
  return best;
}

/// Groups [statuses] for display by rule, anchor, interval and mute, the
/// most advanced card first, and orders the groups: unmuted before muted,
/// then lapsed, due soon, current, then soonest due.
List<CurrencyGroup> collapseCurrency(List<CredentialCurrency> statuses) {
  final byKey = <Object, List<CredentialCurrency>>{};
  for (final s in statuses) {
    final key = (
      s.rule.id,
      s.anchor,
      s.origin,
      s.lapseDays,
      s.leadDays,
      s.muted,
    );
    (byKey[key] ??= []).add(s);
  }
  final groups = [
    for (final members in byKey.values)
      CurrencyGroup([...members]..sort(_mostAdvancedFirst)),
  ];
  groups.sort(_groupOrder);
  return groups;
}

int _rank(Certification c) {
  final level = CertificationLevel.fromId(c.level);
  if (level == null) return -1;
  final ladder = CertificationLevelCatalog.ladderFor(
    CertificationAgency.fromId(c.agency),
  );
  return ladder.indexOf(level);
}

int _mostAdvancedFirst(CredentialCurrency a, CredentialCurrency b) {
  final byRank = _rank(b.certification).compareTo(_rank(a.certification));
  if (byRank != 0) return byRank;
  final ai = a.certification.issueDate;
  final bi = b.certification.issueDate;
  if (ai != bi) {
    if (ai == null) return 1;
    if (bi == null) return -1;
    return bi.compareTo(ai);
  }
  return a.certification.id.compareTo(b.certification.id);
}

int _groupOrder(CurrencyGroup a, CurrencyGroup b) {
  if (a.muted != b.muted) return a.muted ? 1 : -1;
  final bySeverity = b.severity.index.compareTo(a.severity.index);
  if (bySeverity != 0) return bySeverity;
  final aNoClock =
      a.representative.origin == CurrencyAnchorOrigin.noCountedDive;
  final bNoClock =
      b.representative.origin == CurrencyAnchorOrigin.noCountedDive;
  if (aNoClock != bNoClock) return aNoClock ? 1 : -1;
  return a.representative.dueDate.compareTo(b.representative.dueDate);
}
