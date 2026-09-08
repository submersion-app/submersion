/// Enough for a busy Saturday without letting a synced blob grow forever.
const int kMaxBilledFills = 100;

/// One line of a saved fill: a gas, the bar it delivered, and what it cost.
class BilledGasLine {
  const BilledGasLine({
    required this.gas,
    required this.addedBar,
    required this.cost,
    this.freeGasLiters,
  });

  /// The gas as it was labelled when the fill was saved, e.g. "He" or
  /// "Tx 18/45". Stored as text rather than as a mix because an invoice line
  /// is a record of what was charged, not something to recompute later.
  final String gas;

  final double addedBar;
  final double? cost;

  /// Free gas at the surface, in litres, frozen at save time the same way
  /// [addedBar] is. Nullable rather than required: a fill saved before this
  /// field existed has no volume to fall back on, and recomputing it would
  /// need the cylinder's water capacity *at the time*, which was never kept
  /// per line. The invoice shows volume when this is present and falls back
  /// to pressure for older rows rather than guessing.
  final double? freeGasLiters;

  Map<String, dynamic> toJson() => {
    'gas': gas,
    'addedBar': addedBar,
    if (cost != null) 'cost': cost,
    if (freeGasLiters != null) 'freeGasLiters': freeGasLiters,
  };

  static BilledGasLine? fromJson(Object? json) {
    if (json is! Map) return null;
    final gas = json['gas'];
    final bar = json['addedBar'];
    if (gas is! String || bar is! num) return null;
    final cost = json['cost'];
    final liters = json['freeGasLiters'];
    return BilledGasLine(
      gas: gas,
      addedBar: bar.toDouble(),
      cost: cost is num ? cost.toDouble() : null,
      freeGasLiters: liters is num ? liters.toDouble() : null,
    );
  }
}

/// The cylinder and mix behind a manually entered bill line.
///
/// Kept alongside the free-typed [BilledFill.total] rather than replacing it:
/// the amount charged at a real counter is still whatever the blender typed,
/// this only records what was actually filled so the line reads as more than
/// a bare number (issue #1335).
class BilledCustomMix {
  const BilledCustomMix({
    required this.cylinderLiters,
    required this.o2,
    required this.he,
  });

  final double cylinderLiters;
  final double o2;
  final double he;

  Map<String, dynamic> toJson() => {
    'cylinderLiters': cylinderLiters,
    'o2': o2,
    'he': he,
  };

  static BilledCustomMix? fromJson(Object? json) {
    if (json is! Map) return null;
    final liters = json['cylinderLiters'];
    final o2 = json['o2'];
    final he = json['he'];
    if (liters is! num || o2 is! num || he is! num) return null;
    return BilledCustomMix(
      cylinderLiters: liters.toDouble(),
      o2: o2.toDouble(),
      he: he.toDouble(),
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
    this.customMix,
  });

  final String id;

  /// What was filled, e.g. "Tx 18/45", or free text for a manually added
  /// line such as "O2 analyser cell".
  final String label;

  /// Empty for a manually added line: there is no fill behind it to itemise.
  final List<BilledGasLine> lines;

  /// Null when the fill was saved before every gas had a price.
  final double? total;

  /// The cylinder and mix entered for a manual line, when the blender chose
  /// to record one. Always null for a computed fill: [lines] already
  /// itemises it.
  final BilledCustomMix? customMix;

  bool get isManual => lines.isEmpty;

  /// [clearTotal] is how an amount gets removed. Null is meaningful here: it
  /// marks a line as not yet priced, which is what makes the grand total
  /// report itself incomplete, and `total ?? this.total` could not express it,
  /// so deleting an amount silently kept the old one (PR #1215 review).
  ///
  /// A boolean rather than an `Object?` sentinel because the sentinel form
  /// gives up compile-time typing: `copyWith(total: 40)` then compiles and
  /// throws at run time on the int literal.
  ///
  /// [clearCustomMix] follows the same shape: re-editing a manual line to
  /// remove its mix has to be expressible, and `customMix ?? this.customMix`
  /// could not tell "unchanged" from "cleared" any more than `total` could.
  BilledFill copyWith({
    String? label,
    double? total,
    bool clearTotal = false,
    BilledCustomMix? customMix,
    bool clearCustomMix = false,
  }) => BilledFill(
    id: id,
    label: label ?? this.label,
    lines: lines,
    total: clearTotal ? null : (total ?? this.total),
    customMix: clearCustomMix ? null : (customMix ?? this.customMix),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'lines': lines.map((l) => l.toJson()).toList(),
    if (total != null) 'total': total,
    if (customMix != null) 'customMix': customMix!.toJson(),
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
      customMix: BilledCustomMix.fromJson(json['customMix']),
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

/// Enough recent invoices to be useful without letting a synced blob grow
/// forever, matching [kMaxBilledFills]'s reasoning.
const int kMaxArchivedInvoices = 50;

/// A running bill as it stood when "Pay" archived it: the invoice date, who
/// it was billed to, every line, and the total.
///
/// A minimal record rather than a full invoice history feature (that is
/// issue #22) - just enough that archiving loses nothing, so a later
/// history view has real data to build on instead of starting from zero.
class ArchivedInvoice {
  const ArchivedInvoice({
    required this.id,
    required this.date,
    required this.billedTo,
    required this.fills,
    required this.total,
    this.currencyCode,
  });

  final String id;
  final DateTime date;
  final String billedTo;
  final List<BilledFill> fills;

  /// Null when the bill was paid with an unpriced line still on it.
  final double? total;

  /// The currency [total] was priced in when this bill was paid. Nullable
  /// because [blenderCurrencyProvider] can drift between two "Pay" actions -
  /// without a snapshot, an older archived total would silently be read back
  /// in whatever currency happens to be configured today. A row archived
  /// before this field existed falls back to the currency configured at
  /// display time, the best guess available for it.
  final String? currencyCode;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'billedTo': billedTo,
    'fills': fills.map((f) => f.toJson()).toList(),
    if (total != null) 'total': total,
    if (currencyCode != null) 'currencyCode': currencyCode,
  };

  static ArchivedInvoice? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final dateRaw = json['date'];
    if (id is! String || dateRaw is! String) return null;
    final date = DateTime.tryParse(dateRaw);
    if (date == null) return null;
    final billedTo = json['billedTo'];
    final rawFills = json['fills'];
    final total = json['total'];
    final currencyCode = json['currencyCode'];
    return ArchivedInvoice(
      id: id,
      date: date,
      billedTo: billedTo is String ? billedTo : '',
      fills: rawFills is List
          ? rawFills.map(BilledFill.fromJson).whereType<BilledFill>().toList()
          : const [],
      total: total is num ? total.toDouble() : null,
      currencyCode: currencyCode is String ? currencyCode : null,
    );
  }
}

/// [invoices] with [invoice] on the end, dropping the oldest to stay within
/// [kMaxArchivedInvoices]. See [appendCapped] for why the cap is applied here
/// rather than on read.
List<ArchivedInvoice> appendArchivedCapped(
  List<ArchivedInvoice> invoices,
  ArchivedInvoice invoice,
) {
  final next = [...invoices, invoice];
  if (next.length <= kMaxArchivedInvoices) return next;
  return next.sublist(next.length - kMaxArchivedInvoices);
}
