import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/data/repositories/certification_currency_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/domain/entities/credential_currency.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_card_ids.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

/// A certification's currency held in its page's sitting (issue #4527,
/// phase 3): refreshers and renewals logged or deleted, and the
/// preferences (interval, mapping, mute) set on a row, which may stand for
/// several cards. All are written at Save, in the sitting's one entry.

final String _currency = CertificationCardId.currency.name;

/// The certification's logged refreshers and renewals. A new one carries
/// the id it is created with at Save.
final certificationEventsList = SittingList<Certification, CurrencyEvent>(
  key: 'certification.currencyEvents',
  cardId: _currency,
  read: (c) => CertificationCurrencyRepository().getEvents(c.id),
  write: (c, loaded, current) async {
    final repository = CertificationCurrencyRepository();
    final loadedIds = {for (final e in loaded) e.id};
    final currentIds = {for (final e in current) e.id};
    var changed = false;
    for (final event in current) {
      if (loadedIds.contains(event.id)) continue;
      await repository.createEvent(event);
      changed = true;
    }
    for (final event in loaded) {
      if (currentIds.contains(event.id)) continue;
      await repository.deleteEvent(event.id);
      changed = true;
    }
    return changed;
  },
  same: (a, b) => sameIdSets(a, b, (e) => e.id),
);

/// A new event for [certificationId] on [ruleId], with an id of its own so
/// the sitting can hold and release it.
CurrencyEvent newCurrencyEvent({
  required String certificationId,
  required String ruleId,
  required CurrencyEventType type,
  required DateTime date,
  String? provider,
  String notes = '',
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  return CurrencyEvent(
    id: const Uuid().v4(),
    certificationId: certificationId,
    ruleId: ruleId,
    eventType: type,
    eventDate: date,
    provider: provider,
    notes: notes,
    createdAt: at,
    updatedAt: at,
  );
}

/// A preference's place: the card and the rule it is for.
typedef CurrencyPrefKey = ({String certificationId, String ruleId});

CurrencyPrefKey _keyOf(CurrencyPref p) =>
    (certificationId: p.certificationId, ruleId: p.ruleId);

const Object _keep = Object();

/// [p] with the named fields replaced, each able to go back to null, which
/// copyWith cannot do. An omitted field keeps its value.
CurrencyPref rebuildCurrencyPref(
  CurrencyPref p, {
  Object? lapse = _keep,
  Object? lead = _keep,
  Object? types = _keep,
  Object? modes = _keep,
  bool? muted,
}) => CurrencyPref(
  id: p.id,
  certificationId: p.certificationId,
  ruleId: p.ruleId,
  lapseDaysOverride: identical(lapse, _keep)
      ? p.lapseDaysOverride
      : lapse as int?,
  leadDaysOverride: identical(lead, _keep) ? p.leadDaysOverride : lead as int?,
  countedDiveTypeIds: identical(types, _keep)
      ? p.countedDiveTypeIds
      : types as List<String>?,
  countedDiveModes: identical(modes, _keep)
      ? p.countedDiveModes
      : modes as List<DiveMode>?,
  muted: muted ?? p.muted,
  createdAt: p.createdAt,
  updatedAt: p.updatedAt,
);

/// The preference [group]'s member [m] has now, from [stored]: its own;
/// else the superseded built-in's, carried onto the custom rule as a new
/// row, so the first edit of a copied rule keeps the mute and overrides the
/// engine was already applying through it; else a new one.
CurrencyPref _currentPref(
  CredentialCurrency m,
  Map<CurrencyPrefKey, CurrencyPref> stored,
  DateTime now,
) {
  final own = stored[(certificationId: m.certification.id, ruleId: m.rule.id)];
  if (own != null) return own;
  final supersedes = m.rule.supersedesRuleId;
  final inherited = supersedes == null
      ? null
      : stored[(certificationId: m.certification.id, ruleId: supersedes)];
  if (inherited != null) {
    return rebuildCurrencyPref(
      CurrencyPref(
        id: '',
        certificationId: inherited.certificationId,
        ruleId: m.rule.id,
        muted: inherited.muted,
        createdAt: inherited.createdAt,
        updatedAt: inherited.updatedAt,
      ),
      lapse: inherited.lapseDaysOverride,
      lead: inherited.leadDaysOverride,
      types: inherited.countedDiveTypeIds,
      modes: inherited.countedDiveModes,
    );
  }
  return CurrencyPref(
    id: '',
    certificationId: m.certification.id,
    ruleId: m.rule.id,
    createdAt: now,
    updatedAt: now,
  );
}

/// [change] of each of [group]'s members' preferences, by full value, so
/// every card the row stands for changes together. [stored] holds the
/// preferences as they are now, by card and rule.
List<CurrencyPref> currencyPrefsFor(
  CurrencyGroup group,
  Map<CurrencyPrefKey, CurrencyPref> stored,
  CurrencyPref Function(CurrencyPref current) change, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  return [for (final m in group.members) change(_currentPref(m, stored, at))];
}

/// The stored preferences of [group]'s members' cards, by card and rule.
Future<Map<CurrencyPrefKey, CurrencyPref>> storedCurrencyPrefs(
  CurrencyGroup group, {
  CertificationCurrencyRepository? repository,
}) async {
  final repo = repository ?? CertificationCurrencyRepository();
  // Each card's are read at once: they are independent.
  final prefs = await Future.wait(group.certificationIds.map(repo.getPrefs));
  return {
    for (final list in prefs)
      for (final p in list) _keyOf(p): p,
  };
}

const String _prefsNote = 'certification.currencyPrefs';
const String _prefKeyPrefix = 'certification.currencyPref:';

String _heldKey(CurrencyPrefKey k) =>
    '$_prefKeyPrefix${k.certificationId}:${k.ruleId}';

/// The preferences [session] holds, by card and rule.
Map<CurrencyPrefKey, CurrencyPref> currencyPrefsInSitting(
  EditSession<Certification> session,
) => session.isDisposed
    ? const {}
    : session.recall<Map<CurrencyPrefKey, CurrencyPref>>(_prefsNote) ??
          const {};

/// Holds [change] of every preference [group] stands for, to be written at
/// Save: one held change of Currency per card and rule. [stored] is what
/// the cards hold now ([storedCurrencyPrefs]); a preference the sitting
/// already holds is changed from its held value. One that comes back to
/// what is stored is no longer held.
void holdCurrencyPrefs(
  EditSession<Certification> session,
  CurrencyGroup group,
  Map<CurrencyPrefKey, CurrencyPref> stored,
  CurrencyPref Function(CurrencyPref current) change, {
  DateTime? now,
}) {
  if (session.isDisposed || session.isFrozen) return;
  final held = {...currencyPrefsInSitting(session)};
  final at = now ?? DateTime.now();
  final current = {...stored, ...held};
  final baseline = currencyPrefsFor(group, stored, (p) => p, now: at);
  final next = currencyPrefsFor(group, current, change, now: at);
  final released = <CurrencyPrefKey>[];
  for (var i = 0; i < next.length; i++) {
    final key = _keyOf(next[i]);
    if (next[i] == baseline[i]) {
      held.remove(key);
      released.add(key);
    } else {
      held[key] = next[i];
    }
  }
  // Kept before the held changes notify, so what they redraw reads it.
  session.remember(_prefsNote, Map<CurrencyPrefKey, CurrencyPref>.of(held));
  for (final key in released) {
    session.releaseWrite(_heldKey(key));
  }
  for (final pref in next) {
    final key = _keyOf(pref);
    if (!held.containsKey(key)) continue;
    session.holdChange(
      _heldKey(key),
      cardId: _currency,
      write: () => CertificationCurrencyRepository().upsertPref(pref),
    );
  }
}
