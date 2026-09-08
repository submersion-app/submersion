import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gas_calculators/domain/blending/billed_fill.dart';
import 'package:submersion/features/gas_calculators/domain/blending/invoice_archive_period.dart';

ArchivedInvoice _invoice(DateTime date) => ArchivedInvoice(
  id: date.toIso8601String(),
  date: date,
  billedTo: '',
  fills: const [],
  total: 10,
);

void main() {
  group('blenderInvoiceArchiveYearFilters', () {
    test('is just "all years" for an empty archive', () {
      expect(blenderInvoiceArchiveYearFilters(const []), [
        const BlenderInvoiceArchiveYearFilter.all(),
      ]);
    });

    test('leads with "all years", then every year on file newest first', () {
      final filters = blenderInvoiceArchiveYearFilters([
        _invoice(DateTime(2025, 12, 1)),
        _invoice(DateTime(2026, 4, 3)),
        _invoice(DateTime(2025, 2, 1)),
      ]);

      expect(filters, [
        const BlenderInvoiceArchiveYearFilter.all(),
        const BlenderInvoiceArchiveYearFilter.year(2026),
        const BlenderInvoiceArchiveYearFilter.year(2025),
      ]);
    });
  });

  group('blenderInvoiceArchiveMonthFilters', () {
    test('leads with "all months", then months in that year newest first', () {
      final invoices = [
        _invoice(DateTime(2025, 12, 1)),
        _invoice(DateTime(2026, 4, 3)),
        _invoice(DateTime(2026, 1, 5)),
      ];

      expect(
        blenderInvoiceArchiveMonthFilters(
          invoices,
          const BlenderInvoiceArchiveYearFilter.year(2026),
        ),
        [
          const BlenderInvoiceArchiveMonthFilter.all(),
          const BlenderInvoiceArchiveMonthFilter.month(4),
          const BlenderInvoiceArchiveMonthFilter.month(1),
        ],
      );
    });

    test('considers every year when the year filter is "all years"', () {
      final invoices = [
        _invoice(DateTime(2025, 12, 1)),
        _invoice(DateTime(2026, 4, 3)),
        _invoice(DateTime(2026, 1, 5)),
      ];

      expect(
        blenderInvoiceArchiveMonthFilters(
          invoices,
          const BlenderInvoiceArchiveYearFilter.all(),
        ),
        [
          const BlenderInvoiceArchiveMonthFilter.all(),
          const BlenderInvoiceArchiveMonthFilter.month(12),
          const BlenderInvoiceArchiveMonthFilter.month(4),
          const BlenderInvoiceArchiveMonthFilter.month(1),
        ],
      );
    });
  });

  group('BlenderInvoiceArchiveYearFilter.matches', () {
    test('"all years" matches any date', () {
      const filter = BlenderInvoiceArchiveYearFilter.all();
      expect(filter.matches(DateTime(2020, 1, 1)), isTrue);
      expect(filter.matches(DateTime(2030, 12, 31)), isTrue);
    });

    test('a specific year matches only that year', () {
      const filter = BlenderInvoiceArchiveYearFilter.year(2026);
      expect(filter.matches(DateTime(2026, 1, 1)), isTrue);
      expect(filter.matches(DateTime(2026, 12, 31)), isTrue);
      expect(filter.matches(DateTime(2025, 12, 31)), isFalse);
    });
  });

  group('BlenderInvoiceArchiveMonthFilter.matches', () {
    test('"all months" matches any date', () {
      const filter = BlenderInvoiceArchiveMonthFilter.all();
      expect(filter.matches(DateTime(2026, 1, 1)), isTrue);
      expect(filter.matches(DateTime(2026, 12, 31)), isTrue);
    });

    test('a specific month matches only that month, in any year', () {
      const filter = BlenderInvoiceArchiveMonthFilter.month(4);
      expect(filter.matches(DateTime(2026, 4, 1)), isTrue);
      expect(filter.matches(DateTime(2025, 4, 30)), isTrue);
      expect(filter.matches(DateTime(2026, 5, 1)), isFalse);
    });
  });
}
