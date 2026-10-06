import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/weight_name_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import '../../../../helpers/test_app.dart';

void main() {
  const named = DiveWeight(
    id: 'w1',
    diveId: 'd1',
    weightType: WeightType.trimWeights,
    amountKg: 2,
    label: 'Top pocket',
  );
  const unnamed = DiveWeight(
    id: 'w2',
    diveId: 'd1',
    weightType: WeightType.belt,
    amountKg: 4,
  );

  test('weightNameParts splits the trimmed name from the placement', () {
    final en = l10nForLocaleTag('en');
    expect(weightNameParts(named, en), (
      name: 'Top pocket',
      type: 'Trim Weights',
    ));
    expect(weightNameParts(unnamed.copyWith(label: '  '), en), (
      name: '',
      type: 'Weight Belt',
    ));
  });

  testWidgets('mutes the placement after a name', (tester) async {
    await tester.pumpWidget(
      testApp(locale: const Locale('en'), child: const WeightNameText(named)),
    );
    final text = tester.widget<Text>(find.byType(Text));
    final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(spans.first.text, 'Top pocket');
    expect(spans.last.text, ' · Trim Weights');
    final context = tester.element(find.byType(WeightNameText));
    expect(
      spans.last.style!.color,
      Theme.of(context).colorScheme.onSurfaceVariant,
    );
  });

  testWidgets('an unnamed weight shows its placement as before', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(locale: const Locale('en'), child: const WeightNameText(unnamed)),
    );
    expect(find.text('Weight Belt'), findsOneWidget);
  });
}
