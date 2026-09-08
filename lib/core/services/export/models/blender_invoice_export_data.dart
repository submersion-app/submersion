/// What the blender invoice export services (PDF, Excel) need, already
/// formatted for display.
///
/// The export services never convert units or money themselves: the invoice
/// card already knows the diver's unit and currency preferences, so every
/// figure is formatted once, at the source, rather than duplicated per
/// export format. This mirrors how the card itself never lets a second
/// conversion path creep in (see `blender_formatting.dart`).
library;

/// One priced gas line within a saved fill.
class BlenderInvoiceExportLine {
  const BlenderInvoiceExportLine({
    required this.gas,
    required this.volume,
    required this.cost,
  });

  final String gas;
  final String volume;
  final String cost;
}

/// One fill on the bill, with its itemisation.
class BlenderInvoiceExportFill {
  const BlenderInvoiceExportFill({
    required this.label,
    required this.total,
    required this.lines,
  });

  final String label;
  final String total;
  final List<BlenderInvoiceExportLine> lines;
}

/// The whole running bill, ready to hand to a PDF or Excel writer.
class BlenderInvoiceExportData {
  const BlenderInvoiceExportData({
    required this.date,
    required this.billedTo,
    required this.tariff,
    required this.fills,
    required this.total,
    required this.incomplete,
  });

  final String date;
  final String billedTo;

  /// The configured gas tariff, e.g. "O2 1.20/100L, He 4.50/100L". Empty
  /// when nothing is priced yet.
  final String tariff;

  final List<BlenderInvoiceExportFill> fills;
  final String total;

  /// True when one or more lines had no price, so [total] is a partial sum.
  final bool incomplete;
}
