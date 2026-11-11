import 'package:country_flags/country_flags.dart' as package;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/geography/country_names.generated.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/country_flag.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool flagsOn = true,
  double width = 400,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [showCountryFlagsProvider.overrideWithValue(flagsOn)],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
}

const _pin = Icon(Icons.location_on_outlined, key: ValueKey('pin'));

/// The drawn flag: the outlined box inside [CountryFlag]. The harness hands
/// it a tight 400-wide slot, which the flag must not stretch to fill.
Finder _drawnFlag() => find.descendant(
  of: find.byType(CountryFlag),
  matching: find.byType(DecoratedBox),
);

void main() {
  group('CountryFlag', () {
    testWidgets('draws 16 by 11 at the default height', (tester) async {
      await _pump(tester, const CountryFlag(code: 'MX'));
      expect(tester.getSize(_drawnFlag()), const Size(16, 11));
    });

    testWidgets('keeps the 16:11 ratio at another height', (tester) async {
      await _pump(tester, const CountryFlag(code: 'MX', height: 22));
      expect(tester.getSize(_drawnFlag()), const Size(32, 22));
    });

    testWidgets('is hidden from screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const CountryFlag(code: 'MX'));
      expect(
        find.descendant(
          of: find.byType(CountryFlag),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    test('every assigned country code has a flag to draw', () {
      final missing = [
        for (final code in assignedAlpha2Codes)
          if (package.FlagCode.fromCountryCode(code) == null) code,
      ];
      expect(missing, isEmpty);
    });
  });

  group('LocationWithFlag', () {
    testWidgets('a known country with flags on shows its flag', (tester) async {
      await _pump(
        tester,
        const LocationWithFlag(
          country: 'Mexico',
          fallbackLeading: _pin,
          text: Text('Cozumel, Mexico'),
        ),
      );
      final flag = tester.widget<CountryFlag>(find.byType(CountryFlag));
      expect(flag.code, 'MX');
      expect(find.byKey(const ValueKey('pin')), findsNothing);
    });

    testWidgets('flags off shows the fallback and no flag', (tester) async {
      await _pump(
        tester,
        const LocationWithFlag(
          country: 'Mexico',
          fallbackLeading: _pin,
          text: Text('Cozumel, Mexico'),
        ),
        flagsOn: false,
      );
      expect(find.byType(CountryFlag), findsNothing);
      expect(find.byKey(const ValueKey('pin')), findsOneWidget);
    });

    testWidgets('an unknown country shows the fallback', (tester) async {
      await _pump(
        tester,
        const LocationWithFlag(
          country: 'Atlantis',
          fallbackLeading: _pin,
          text: Text('Atlantis'),
        ),
      );
      expect(find.byType(CountryFlag), findsNothing);
      expect(find.byKey(const ValueKey('pin')), findsOneWidget);
    });

    testWidgets('no fallback and no flag shows just the text', (tester) async {
      await _pump(
        tester,
        const LocationWithFlag(country: null, text: Text('Somewhere')),
      );
      expect(find.byType(CountryFlag), findsNothing);
      expect(find.text('Somewhere'), findsOneWidget);
    });

    testWidgets('a long location ellipsizes beside the flag on one line', (
      tester,
    ) async {
      final long = 'Cozumel ${'very long reef name ' * 12}, Mexico';
      await _pump(
        tester,
        LocationWithFlag(
          country: 'Mexico',
          text: Text(long, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        width: 320,
      );
      expect(tester.takeException(), isNull);
      final flagTop = tester.getTopLeft(find.byType(CountryFlag)).dy;
      final textRect = tester.getRect(find.text(long));
      final rowRect = tester.getRect(find.byType(LocationWithFlag));
      expect(textRect.right, lessThanOrEqualTo(rowRect.right + 0.5));
      expect(textRect.height, lessThan(30)); // one line
      // The flag sits beside the text's line, not on a line of its own.
      expect(flagTop, greaterThanOrEqualTo(textRect.top));
      expect(flagTop, lessThan(textRect.bottom));
    });

    testWidgets('the flag lines up with the first line of wrapped text', (
      tester,
    ) async {
      await _pump(
        tester,
        const LocationWithFlag(
          country: 'United States',
          text: Text('New Jersey, United States of a long wrapping name'),
        ),
        width: 160,
      );
      final textRect = tester.getRect(
        find.text('New Jersey, United States of a long wrapping name'),
      );
      final flagRect = tester.getRect(find.byType(CountryFlag));
      expect(textRect.height, greaterThan(flagRect.height * 2));
      // Centred on the first line: within one line height of the top.
      expect(flagRect.top - textRect.top, lessThan(textRect.height / 2));
    });
  });
}
