import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/data/data_facts_repository.dart';
import 'package:submersion/features/settings/presentation/providers/data_health_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/data_facts_line.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  testWidgets('facts line joins counts and size', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataFactsProvider.overrideWith(
            (ref) async => const DataFacts(
              dives: 2,
              sites: 1,
              media: 3,
              databaseBytes: 1572864,
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DataFactsLine()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('2 dives · 1 site · 3 photos and videos · 1.5 MB'),
      findsOneWidget,
    );
  });
}
