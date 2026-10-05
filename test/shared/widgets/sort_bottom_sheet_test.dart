import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';

Widget _host(Widget? footer) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(
    body: SingleChildScrollView(
      child: SortBottomSheet<SiteSortField>(
        title: 'Sort Sites',
        currentField: SiteSortField.name,
        currentDirection: SortDirection.descending,
        fields: SiteSortField.values,
        getFieldDisplayName: (f) => f.displayName,
        getFieldIcon: (f) => f.icon,
        onSortChanged: (_, _) {},
        footer: footer,
      ),
    ),
  ),
);

void main() {
  testWidgets('renders an optional footer under the fields', (tester) async {
    await tester.pumpWidget(_host(const Text('footer here')));
    expect(find.text('footer here'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('footer here')).dy,
      greaterThan(tester.getTopLeft(find.text('Last Dived')).dy),
    );
  });

  testWidgets('renders no footer by default', (tester) async {
    await tester.pumpWidget(_host(null));
    expect(find.text('footer here'), findsNothing);
    expect(find.text('Last Dived'), findsOneWidget);
  });
}
