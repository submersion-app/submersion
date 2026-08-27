/// Enough for a busy Saturday without letting a synced blob grow forever.
const int kMaxBilledFills = 100;

/// One line of a saved fill: a gas, the bar it delivered, and what it cost.
class BilledGasLine {
  const BilledGasLine({
    required this.gas,
    required this.addedBar,
    required this.cost,
  });

  /// The gas as it was labelled when the fill was saved, e.g. "He" or
  /// "Tx 18/45". Stored as text rather than as a mix because an invoice line
  /// is a record of what was charged, not something to recompute later.
  final String gas;

  final double addedBar;
  final double? cost;

  Map<String, dynamic> toJson() => {
    'gas': gas,
    'addedBar': addedBar,
    if (cost != null) 'cost': cost,
  };

  static BilledGasLine? fromJson(Object? json) {
    if (json is! Map) return null;
    final gas = json['gas'];
    final bar = json['addedBar'];
    if (gas is! String || bar is! num) return null;
    final cost = json['cost'];
    return BilledGasLine(
      gas: gas,
      addedBar: bar.toDouble(),
      cost: cost is num ? cost.toDouble() : null,
    );
  }
}

/// A cylinder the blender has finished and wants on the bill.
///
/// Saved rather than recomputed: the blend that produced it is about to be
/// replaced by the next cylinder's, and a fill station billing four cylinders
/// needs all four to survive the fifth. The stored total is what gets charged,
/// so it stays editable independently of [lines] for the rounding and
/// discounts that happen at a real counter.
class BilledFill {
  const BilledFill({
    required this.id,
    required this.label,
    required this.lines,
    required this.total,
  });

  final String id;

  /// What was filled, e.g. "Tx 18/45", or free text for a manually added
  /// line such as "O2 analyser cell".
  final String label;

  /// Empty for a manually added line: there is no fill behind it to itemise.
  final List<BilledGasLine> lines;

  /// Null when the fill was saved before every gas had a price.
  final double? total;

  bool get isManual => lines.isEmpty;

  /// [clearTotal] is how an amount gets removed. Null is meaningful here: it
  /// marks a line as not yet priced, which is what makes the grand total
  /// report itself incomplete, and `total ?? this.total` could not express it,
  /// so deleting an amount silently kept the old one (PR #1215 review).
  ///
  /// A boolean rather than an `Object?` sentinel because the sentinel form
  /// gives up compile-time typing: `copyWith(total: 40)` then compiles and
  /// throws at run time on the int literal.
  BilledFill copyWith({
    String? label,
    double? total,
    bool clearTotal = false,
  }) => BilledFill(
    id: id,
    label: label ?? this.label,
    lines: lines,
    total: clearTotal ? null : (total ?? this.total),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'lines': lines.map((l) => l.toJson()).toList(),
    if (total != null) 'total': total,
  };

  static BilledFill? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final label = json['label'];
    if (id is! String || label is! String) return null;
    final rawLines = json['lines'];
    final total = json['total'];
    return BilledFill(
      id: id,
      label: label,
      lines: rawLines is List
          ? rawLines
                .map(BilledGasLine.fromJson)
                .whereType<BilledGasLine>()
                .toList()
          : const [],
      total: total is num ? total.toDouble() : null,
    );
  }
}

/// The sum of every priced line, and whether anything was left unpriced.
///
/// A bill with an unpriced line is reported as incomplete rather than as a
/// smaller total, so nobody undercharges by reading past a blank.
class BilledTotal {
  const BilledTotal({required this.amount, required this.complete});

  final double amount;
  final bool complete;
}

BilledTotal totalOf(List<BilledFill> fills) {
  var amount = 0.0;
  var complete = true;
  for (final f in fills) {
    if (f.total == null) {
      complete = false;
    } else {
      amount += f.total!;
    }
  }
  return BilledTotal(amount: amount, complete: complete);
}

/// [fills] with [fill] on the end, dropping the oldest to stay within
/// [kMaxBilledFills].
///
/// The cap used to be applied only on read, as `take(max)` over an oldest-first
/// list, so a session past the cap persisted everything and then lost its most
/// RECENT lines on the next launch: exactly backwards (PR #1215 review).
List<BilledFill> appendCapped(List<BilledFill> fills, BilledFill fill) {
  final next = [...fills, fill];
  if (next.length <= kMaxBilledFills) return next;
  return next.sublist(next.length - kMaxBilledFills);
}
