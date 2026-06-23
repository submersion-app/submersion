import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_collection_mode_selector.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  testWidgets('selecting Replace reports the mode', (tester) async {
    BulkCollectionMode? mode;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => BulkCollectionModeSelector(
              mode: mode,
              allowed: const [
                BulkCollectionMode.add,
                BulkCollectionMode.replace,
              ],
              onChanged: (m) => setState(() => mode = m),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(mode, BulkCollectionMode.replace);
  });

  testWidgets('tapping the selected chip turns the edit off', (tester) async {
    BulkCollectionMode? mode = BulkCollectionMode.add;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => BulkCollectionModeSelector(
              mode: mode,
              allowed: const [
                BulkCollectionMode.add,
                BulkCollectionMode.replace,
              ],
              onChanged: (m) => setState(() => mode = m),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(mode, isNull);
  });
}
