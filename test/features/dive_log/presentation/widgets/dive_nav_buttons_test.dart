import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_nav_buttons.dart';

Widget _host({
  required String diveId,
  required List<String> ids,
  required void Function(String) onNavigate,
}) {
  return ProviderScope(
    overrides: [orderedDiveIdsProvider.overrideWith((ref) async => ids)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) {
            ref.watch(orderedDiveIdsProvider);
            return DiveNavButtons(diveId: diveId, onNavigate: onNavigate);
          },
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('middle item: both enabled, tap navigates', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      _host(diveId: 'b', ids: ['a', 'b', 'c'], onNavigate: tapped.add),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.tap(find.byIcon(Icons.chevron_right));
    expect(tapped, ['a', 'c']);
  });

  testWidgets('first item: previous disabled', (tester) async {
    await tester.pumpWidget(
      _host(diveId: 'a', ids: ['a', 'b', 'c'], onNavigate: (_) {}),
    );
    await tester.pumpAndSettle();

    final prev = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.chevron_left),
        matching: find.byType(IconButton),
      ),
    );
    expect(prev.onPressed, isNull);
  });
}
