import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/active_filter_chips.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

final _otherFilterProvider = StateProvider<DiveFilterState>(
  (ref) => DiveFilterState(
    startDate: DateTime(2021),
    endDate: DateTime(2024, 12, 31),
    favoritesOnly: true,
  ),
);

void main() {
  testWidgets('chips edit the provider they are given, not the dive list', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Wrap(
                children: activeDiveFilterChips(
                  context,
                  ref,
                  _otherFilterProvider,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Chip), findsNWidgets(2));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();
    final after = container.read(_otherFilterProvider);
    expect(after.startDate, isNull);
    expect(after.endDate, isNull);
    expect(after.favoritesOnly, isTrue);
    expect(container.read(diveFilterProvider).hasActiveFilters, isFalse);
  });
}
