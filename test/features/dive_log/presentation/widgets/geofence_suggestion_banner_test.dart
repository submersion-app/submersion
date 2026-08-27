import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/geofence_suggestion_banner.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('shows set + location and fires callbacks', (tester) async {
    var applied = false;
    var dismissed = false;
    await tester.pumpWidget(
      testApp(
        child: GeofenceSuggestionBanner(
          setName: 'Cold Water',
          locationLabel: 'Monterey Bay',
          onApply: () => applied = true,
          onDismiss: () => dismissed = true,
        ),
      ),
    );

    expect(find.textContaining('Monterey Bay'), findsOneWidget);
    expect(find.textContaining('Cold Water'), findsOneWidget);

    await tester.tap(find.text('Apply'));
    expect(applied, isTrue);
    await tester.tap(find.text('Dismiss'));
    expect(dismissed, isTrue);
  });

  testWidgets('falls back to the generic title when location is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        child: GeofenceSuggestionBanner(
          setName: 'Cold Water',
          locationLabel: null,
          onApply: () {},
          onDismiss: () {},
        ),
      ),
    );

    // The "near {location}" headline is replaced by the generic title.
    expect(find.textContaining('Cold Water'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
  });
}
