import 'package:equatable/equatable.dart';

import 'package:submersion/features/gas_calculators/domain/blending/billed_fill.dart';

/// The year half of the archive section's two-stage filter: either narrowed
/// to one calendar year, or "all years" (issue #44).
class BlenderInvoiceArchiveYearFilter extends Equatable {
  const BlenderInvoiceArchiveYearFilter.all() : year = null;
  const BlenderInvoiceArchiveYearFilter.year(int this.year);

  final int? year;

  bool get isAll => year == null;

  bool matches(DateTime date) => year == null || date.year == year;

  @override
  List<Object?> get props => [year];
}

/// The month half of the filter, narrowed by the year filter it sits under:
/// either one calendar month, or "all months".
class BlenderInvoiceArchiveMonthFilter extends Equatable {
  const BlenderInvoiceArchiveMonthFilter.all() : month = null;
  const BlenderInvoiceArchiveMonthFilter.month(int this.month);

  final int? month;

  bool get isAll => month == null;

  bool matches(DateTime date) => month == null || date.month == month;

  @override
  List<Object?> get props => [month];
}

/// The years [invoices] actually fall in, newest first, with "all years"
/// leading - the options the archive section's year filter offers.
List<BlenderInvoiceArchiveYearFilter> blenderInvoiceArchiveYearFilters(
  List<ArchivedInvoice> invoices,
) {
  final years = {for (final invoice in invoices) invoice.date.year}.toList()
    ..sort((a, b) => b.compareTo(a));
  return [
    const BlenderInvoiceArchiveYearFilter.all(),
    for (final year in years) BlenderInvoiceArchiveYearFilter.year(year),
  ];
}

/// The months [invoices] actually fall in under [yearFilter], newest first,
/// with "all months" leading - the options the archive section's month
/// filter offers once a year is picked. Considers every year on file when
/// [yearFilter] is "all years", matching only that one year otherwise.
List<BlenderInvoiceArchiveMonthFilter> blenderInvoiceArchiveMonthFilters(
  List<ArchivedInvoice> invoices,
  BlenderInvoiceArchiveYearFilter yearFilter,
) {
  final months = {
    for (final invoice in invoices)
      if (yearFilter.matches(invoice.date)) invoice.date.month,
  }.toList()..sort((a, b) => b.compareTo(a));
  return [
    const BlenderInvoiceArchiveMonthFilter.all(),
    for (final month in months) BlenderInvoiceArchiveMonthFilter.month(month),
  ];
}
