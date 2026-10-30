/// One coded choice from a Suunto journal, such as visibility or current:
/// a stable [id] (`good`, `none`) and the text the Suunto app showed, in the
/// diver's language.
class SuuntoCoded {
  const SuuntoCoded({required this.id, required this.text});

  /// The language-independent code, empty when the workout carried none.
  /// Only this is ever mapped to a Submersion value.
  final String id;

  /// What the diver saw in the Suunto app ("Gut"), or [id] when the workout
  /// carried no text.
  final String text;
}

/// The dive details a diver logged in the Suunto app, from the cloud
/// workout's `journal` object. The dive export never carries any of them
/// (issues #3266 and #3491).
///
/// Every value is trimmed, blank values are dropped, and a list keeps each
/// value once (ignoring case). A field of the wrong shape reads as absent,
/// so one odd field never costs the workout the rest of its journal.
class SuuntoJournal {
  const SuuntoJournal({
    this.buddies = const [],
    this.diveCenter,
    this.visibility,
    this.current,
    this.weightKg,
    this.suit = const [],
    this.environment = const [],
    this.marineLife = const [],
    this.comfort = const [],
    this.buoyancy = const [],
    this.stateOfMind = const [],
    this.privateNotes,
  });

  static const empty = SuuntoJournal();

  static const double _kgPerPound = 0.45359237;

  /// `diveBuddy`: the people the diver logged as buddies.
  final List<String> buddies;

  /// `diveCenter`: the dive center's name.
  final String? diveCenter;

  /// `diveVisibility`.
  final SuuntoCoded? visibility;

  /// `diveCurrent`.
  final SuuntoCoded? current;

  /// `diveWeights`, in kilograms.
  final double? weightKg;

  /// `diveSuit`.
  final List<String> suit;

  /// `diveEnvironmentalFeatures`.
  final List<String> environment;

  /// `diveMarineEncounters`: animal names in the diver's language.
  final List<String> marineLife;

  /// `diveComfort`.
  final List<String> comfort;

  /// `diveBuoyancy`.
  final List<String> buoyancy;

  /// `diveStateOfMind`.
  final List<String> stateOfMind;

  /// `privateNotes`.
  final String? privateNotes;

  bool get isEmpty =>
      buddies.isEmpty &&
      diveCenter == null &&
      visibility == null &&
      current == null &&
      weightKg == null &&
      suit.isEmpty &&
      environment.isEmpty &&
      marineLife.isEmpty &&
      comfort.isEmpty &&
      buoyancy.isEmpty &&
      stateOfMind.isEmpty &&
      privateNotes == null;

  /// Reads a workout's `journal`, which is absent on a workout logged
  /// without dive details.
  static SuuntoJournal parse(Object? journal) {
    if (journal is! Map) return empty;
    return SuuntoJournal(
      buddies: _values(journal['diveBuddy']),
      diveCenter: _text(_entryValue(journal['diveCenter'])),
      visibility: _coded(journal['diveVisibility']),
      current: _coded(journal['diveCurrent']),
      weightKg: _weightKg(journal['diveWeights']),
      suit: _values(journal['diveSuit']),
      environment: _values(journal['diveEnvironmentalFeatures']),
      marineLife: _values(journal['diveMarineEncounters']),
      comfort: _values(journal['diveComfort']),
      buoyancy: _values(journal['diveBuoyancy']),
      stateOfMind: _values(journal['diveStateOfMind']),
      privateNotes: _text(journal['privateNotes']),
    );
  }

  /// The trimmed, non-blank text of [value], or null.
  static String? _text(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  /// The `value` of one `{id, value}` entry.
  static Object? _entryValue(Object? entry) =>
      entry is Map ? entry['value'] : null;

  /// The values of a list of `{id, value}` entries, each kept once.
  static List<String> _values(Object? entries) {
    if (entries is! List) return const [];
    final seen = <String>{};
    final values = <String>[];
    for (final entry in entries) {
      final text = _text(_entryValue(entry));
      if (text == null || !seen.add(text.toLowerCase())) continue;
      values.add(text);
    }
    return List.unmodifiable(values);
  }

  /// A coded entry, kept when it has an id or text: text with no id is
  /// still what the diver logged, kept as text since nothing can map it.
  static SuuntoCoded? _coded(Object? entry) {
    if (entry is! Map) return null;
    final id = _text(entry['id']);
    final text = _text(entry['value']) ?? id;
    if (text == null) return null;
    return SuuntoCoded(id: id ?? '', text: text);
  }

  /// Kilograms from `{value, unit}`. An unknown unit is skipped rather than
  /// guessed, and so is a weight of zero or less, which would otherwise
  /// stand on the dive as a real one.
  static double? _weightKg(Object? weights) {
    if (weights is! Map) return null;
    final value = weights['value'];
    final unit = weights['unit'];
    if (value is! num || value <= 0 || unit is! String) return null;
    return switch (unit.trim().toUpperCase()) {
      'KG' => value.toDouble(),
      'LB' || 'LBS' => value * _kgPerPound,
      _ => null,
    };
  }
}
