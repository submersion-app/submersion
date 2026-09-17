import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/import_target_chip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('names an existing profile', (tester) async {
    await tester.pumpWidget(
      _host(
        const ImportTargetChip(
          target: ImportTarget(key: 'diver:me', name: 'Me', isNew: false),
        ),
      ),
    );
    expect(find.text('Me'), findsOneWidget);
  });

  testWidgets('marks a profile the import will create', (tester) async {
    await tester.pumpWidget(
      _host(
        const ImportTargetChip(
          target: ImportTarget(key: 'new:bo', name: 'Bo Ray', isNew: true),
        ),
      ),
    );
    expect(find.text('New: Bo Ray'), findsOneWidget);
  });
}
