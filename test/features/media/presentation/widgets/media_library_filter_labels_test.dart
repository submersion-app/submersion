import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_filter_labels.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// #1512: the media filter chip and the filter sheet both showed the range
/// from a locale-derived format, so a diver on DD/MM/YYYY read "Jun 1, 2025".
/// Both surfaces share this one function, so pinning it here pins both.
void main() {
  // Formatted by intl, which resolves against Intl.defaultLocale. This is a
  // pure unit test with no MaterialApp to pin it, so set it explicitly and
  // restore it afterwards; intl then wants real symbol data, hence the
  // initialization.
  late String? previousLocale;

  setUpAll(() => initializeDateFormatting('en'));

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });

  tearDown(() => Intl.defaultLocale = previousLocale);

  const dayFirst = UnitFormatter(
    AppSettings(dateFormat: DateFormatPreference.ddmmyyyy),
  );
  const monthFirst = UnitFormatter(
    AppSettings(dateFormat: DateFormatPreference.mmmDYYYY),
  );

  final from = DateTime(2025, 6, 1);
  final to = DateTime(2025, 6, 8);

  group('formatFilterDateRange', () {
    test('renders both bounds in the diver order', () {
      expect(
        formatFilterDateRange(dayFirst, from, to),
        '01/06/2025 - 08/06/2025',
      );
      expect(
        formatFilterDateRange(monthFirst, from, to),
        'Jun 1, 2025 - Jun 8, 2025',
      );
    });

    // A one-sided range renders the bound it has, with no "From"/"Until"
    // word: the chip has no room for one and the sheet labels it already.
    test('renders a lower bound alone', () {
      expect(formatFilterDateRange(dayFirst, from, null), '01/06/2025');
    });

    test('renders an upper bound alone', () {
      expect(formatFilterDateRange(dayFirst, null, to), '08/06/2025');
    });
  });
}
