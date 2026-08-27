import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/dive_picker_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeDiveRepo implements DiveRepository {
  @override
  Future<List<Dive>> getAllDives({String? diverId}) async => [
    Dive(
      id: 'dive-2',
      diveNumber: 2,
      name: 'Night dive',
      dateTime: DateTime(2026, 6, 12),
    ),
    Dive(id: 'dive-1', diveNumber: 1, dateTime: DateTime(2026, 6, 11)),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedDiverIdNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _FixedDiverIdNotifier() : super('d1');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget host({required Future<void> Function(BuildContext) onPressed}) {
    return ProviderScope(
      overrides: [
        diveRepositoryProvider.overrideWithValue(_FakeDiveRepo()),
        currentDiverIdProvider.overrideWith((ref) => _FixedDiverIdNotifier()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => onPressed(context),
              child: const Text('OPEN'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('lists dives, filters by search, returns the tapped dive id', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      host(
        onPressed: (context) async {
          picked = await showDivePickerSheet(context);
        },
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.textContaining('#1'), findsOneWidget);
    expect(find.textContaining('#2'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'night');
    await tester.pumpAndSettle();
    expect(find.textContaining('#1'), findsNothing);
    expect(find.textContaining('#2'), findsOneWidget);

    await tester.tap(find.textContaining('#2'));
    await tester.pumpAndSettle();
    expect(picked, 'dive-2');
  });

  testWidgets('dismissing resolves null', (tester) async {
    String? picked = 'sentinel';
    await tester.pumpWidget(
      host(
        onPressed: (context) async {
          picked = await showDivePickerSheet(context);
        },
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(400, 20)); // barrier dismiss
    await tester.pumpAndSettle();
    expect(picked, isNull);
  });
}
