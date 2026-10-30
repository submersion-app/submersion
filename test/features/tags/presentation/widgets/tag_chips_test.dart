import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/full_themes/submersion_theme.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';

import '../../../../helpers/contrast_ratio.dart';

Tag _tag(String id) => Tag(
  id: id,
  name: 'Tag $id',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  // The "+N" overflow count was 11px grey600 on a 15% grey wash, under WCAG
  // AA on dark surfaces.
  for (final theme in [submersionLight, submersionDark]) {
    testWidgets('the overflow count reads in ${theme.brightness.name} mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: TagChips(tags: [for (var i = 0; i < 5; i++) _tag('$i')]),
          ),
        ),
      );

      final count = find.text('+2');
      final text = tester.widget<Text>(count);
      final pill = tester.widget<DecoratedBox>(
        find.ancestor(of: count, matching: find.byType(DecoratedBox)).first,
      );
      // The pill may be a translucent wash: resolve it over the page.
      final fill = Color.alphaBlend(
        (pill.decoration as BoxDecoration).color!,
        theme.colorScheme.surface,
      );
      expect(
        contrastRatio(text.style!.color!, fill),
        greaterThanOrEqualTo(4.5),
      );
    });
  }
}
