import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';

/// The certification currency rows a UDDF full backup carries (issue
/// #2267): the diver's custom rules, and the prefs and ledger events of the
/// certifications being exported. Built-in rules are never carried; the
/// writer drops any that arrive here.
class CurrencyBackupData {
  final List<CurrencyRule> rules;
  final List<CurrencyPref> prefs;
  final List<CurrencyEvent> events;

  const CurrencyBackupData({
    this.rules = const [],
    this.prefs = const [],
    this.events = const [],
  });

  /// What a backup of [certifications] carries: every custom rule given
  /// (the caller passes the active diver's), and only the prefs and events
  /// that belong to one of [certifications], so a pref of a card the file
  /// does not describe never travels without its certref target.
  factory CurrencyBackupData.forCertifications(
    Iterable<Certification> certifications, {
    required List<CurrencyRule> rules,
    required List<CurrencyPref> prefs,
    required List<CurrencyEvent> events,
  }) {
    final ids = {for (final c in certifications) c.id};
    return CurrencyBackupData(
      rules: [
        for (final r in rules)
          if (!r.isBuiltIn) r,
      ],
      prefs: [
        for (final p in prefs)
          if (ids.contains(p.certificationId)) p,
      ],
      events: [
        for (final e in events)
          if (ids.contains(e.certificationId)) e,
      ],
    );
  }

  /// The custom rules only: what the writer actually emits.
  List<CurrencyRule> get customRules => [
    for (final r in rules)
      if (!r.isBuiltIn) r,
  ];

  bool get isEmpty => customRules.isEmpty && prefs.isEmpty && events.isEmpty;
}
