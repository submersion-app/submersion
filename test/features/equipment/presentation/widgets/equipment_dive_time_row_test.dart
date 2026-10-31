import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_dive_time_row.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The item page's Dive Time row (issue #3550): hours in the Exposure card's
/// format, and no row when there is no time to show.
void main() {
  const id = 'item';

  Future<void> pump(
    WidgetTester tester,
    Future<int> Function(Ref ref) seconds, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [equipmentDiveTimeProvider(id).overrideWith(seconds)].cast(),
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: EquipmentDiveTimeRow(equipmentId: id)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the total as hours with one decimal', (tester) async {
    await pump(tester, (ref) async => 113040);

    expect(find.text('Dive Time'), findsOneWidget);
    expect(find.text('31.4 hours'), findsOneWidget);
  });

  testWidgets('keeps the decimal on a whole number of hours', (tester) async {
    await pump(tester, (ref) async => 7200);

    expect(find.text('2.0 hours'), findsOneWidget);
  });

  testWidgets('shows the number in the active locale', (tester) async {
    final previous = Intl.defaultLocale;
    Intl.defaultLocale = 'de';
    addTearDown(() => Intl.defaultLocale = previous);

    await pump(tester, (ref) async => 113040, locale: const Locale('de'));

    expect(find.text('Tauchzeit'), findsOneWidget);
    expect(find.textContaining('31,4'), findsOneWidget);
  });

  testWidgets('draws nothing for a zero total', (tester) async {
    await pump(tester, (ref) async => 0);

    expect(find.text('Dive Time'), findsNothing);
  });

  testWidgets('draws nothing on a failed read', (tester) async {
    await pump(tester, (ref) async => throw StateError('no database'));

    expect(find.text('Dive Time'), findsNothing);
    expect(find.textContaining('no database'), findsNothing);
  });

  testWidgets('draws nothing while loading', (tester) async {
    final pending = Completer<int>();
    await pump(tester, (ref) => pending.future);

    expect(find.text('Dive Time'), findsNothing);

    pending.complete(3600);
    await tester.pumpAndSettle();
    expect(find.text('1.0 hours'), findsOneWidget);
  });
}
