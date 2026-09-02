import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/experience_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late TextEditingController notesController;
  final ratings = <int>[];

  setUp(() {
    notesController = TextEditingController();
    ratings.clear();
  });

  tearDown(() => notesController.dispose());

  Widget host({required int rating}) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ExperienceSection(
            expanded: true,
            onToggle: () {},
            summary: '',
            isEmpty: false,
            rating: rating,
            onRatingChanged: ratings.add,
            notesController: notesController,
            notesPlaceholder: 'Notes',
            sightingsChild: const SizedBox.shrink(),
            tagsChild: const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  testWidgets('a rated dive offers a clear affordance that reports zero', (
    tester,
  ) async {
    await tester.pumpWidget(host(rating: 3));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.star), findsNWidgets(3));
    expect(find.byTooltip('Clear rating'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear rating'));
    await tester.pump();

    expect(ratings, [0]);
  });

  testWidgets('re-tapping the current rating reports zero', (tester) async {
    await tester.pumpWidget(host(rating: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.star).at(2));
    await tester.pump();

    expect(ratings, [0]);
  });

  testWidgets('an unrated dive shows no clear affordance', (tester) async {
    await tester.pumpWidget(host(rating: 0));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.byTooltip('Clear rating'), findsNothing);
  });
}
