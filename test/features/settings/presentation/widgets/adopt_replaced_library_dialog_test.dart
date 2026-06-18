import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/features/settings/presentation/widgets/adopt_replaced_library_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  testWidgets('renders the replacing device name and the two actions', (
    tester,
  ) async {
    const marker = LibraryEpochMarker(
      epochId: 'e1',
      replacedAt: 1764000000000,
      deviceId: 'replacer',
      deviceName: 'Eric Mac',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () =>
                      showAdoptReplacedLibraryDialog(context, ref, marker),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Adopt Restored Library?'), findsOneWidget);
    expect(find.textContaining('Eric Mac'), findsOneWidget);
    expect(find.text('Not Now'), findsOneWidget);

    // Cancelling closes cleanly without touching backup/sync providers.
    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();
    expect(find.text('Adopt Restored Library?'), findsNothing);
  });
}
