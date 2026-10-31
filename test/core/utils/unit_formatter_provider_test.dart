import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/mock_providers.dart';

/// Issue #3818: most whole-`AppSettings` watches in the app only built a
/// formatter, so any settings edit rebuilt every list row that shows a depth.
void main() {
  group('unitFormatterProvider', () {
    late MockSettingsNotifier notifier;
    late ProviderContainer container;

    setUp(() {
      notifier = MockSettingsNotifier();
      container = ProviderContainer(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
      );
      addTearDown(container.dispose);
      container.listen(unitFormatterProvider, (_, _) {});
    });

    test('keeps the same formatter when a setting it cannot read changes', () {
      final before = container.read(unitFormatterProvider);

      notifier.state = notifier.state.copyWith(showDataSourceBadges: false);

      expect(identical(container.read(unitFormatterProvider), before), isTrue);
    });

    test('gives a new formatter when a unit changes', () {
      final before = container.read(unitFormatterProvider);

      notifier.state = notifier.state.copyWith(depthUnit: DepthUnit.feet);

      final after = container.read(unitFormatterProvider);
      expect(identical(after, before), isFalse);
      expect(after.settings.depthUnit, DepthUnit.feet);
    });

    test('gives a new formatter when the language changes', () {
      // Formatted digits follow Intl.defaultLocale, which no setting read by
      // the formatter reveals.
      final before = container.read(unitFormatterProvider);

      notifier.state = notifier.state.copyWith(locale: 'de');

      expect(identical(container.read(unitFormatterProvider), before), isFalse);
    });

    test('hands out the settings as they are after an unrelated edit', () {
      notifier.state = notifier.state.copyWith(showDataSourceBadges: false);
      notifier.state = notifier.state.copyWith(gfHigh: 70);

      expect(container.read(unitFormatterProvider).settings.gfHigh, 70);
    });
  });

  testWidgets('a widget that only formats sits out an unrelated edit', (
    tester,
  ) async {
    final notifier = MockSettingsNotifier();
    var builds = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Consumer(
            builder: (context, ref, _) {
              builds++;
              return Text(ref.watch(unitFormatterProvider).formatDepth(10));
            },
          ),
        ),
      ),
    );
    expect(builds, 1);

    notifier.state = notifier.state.copyWith(showDataSourceBadges: false);
    await tester.pump();
    expect(builds, 1);

    notifier.state = notifier.state.copyWith(depthUnit: DepthUnit.feet);
    await tester.pump();
    expect(builds, 2);
    expect(find.text('32.8ft'), findsOneWidget);
  });
}
