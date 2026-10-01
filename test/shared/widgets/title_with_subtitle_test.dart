import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/models/subtitle_text.dart';
import 'package:submersion/shared/widgets/title_with_subtitle.dart';

Widget _inBox(double width, SubtitleText? subtitle) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: TitleWithSubtitle(
          title: const Text('Dives'),
          subtitle: subtitle,
        ),
      ),
    ),
  ),
);

const _count = SubtitleText('34 of 812 dives', compact: '34 of 812');

void main() {
  testWidgets('shows the full subtitle where it fits', (tester) async {
    await tester.pumpWidget(_inBox(400, _count));

    expect(find.text('34 of 812 dives'), findsOneWidget);
    expect(find.text('34 of 812'), findsNothing);
  });

  // A phone app bar with six actions leaves the title about 86px; the count
  // drops its noun there rather than ellipsising the number away (#2669).
  testWidgets('falls back to the compact form where it does not', (
    tester,
  ) async {
    final fullWidth = await _fullWidth(tester);
    await tester.pumpWidget(_inBox(fullWidth - 1, _count));

    expect(find.text('34 of 812'), findsOneWidget);
    expect(find.text('34 of 812 dives'), findsNothing);
  });

  testWidgets('keeps the full form at exactly its own width', (tester) async {
    final fullWidth = await _fullWidth(tester);
    await tester.pumpWidget(_inBox(fullWidth.ceilToDouble(), _count));

    expect(find.text('34 of 812 dives'), findsOneWidget);
  });

  testWidgets('ellipsises the full form when there is no compact one', (
    tester,
  ) async {
    await tester.pumpWidget(_inBox(40, const SubtitleText('34 of 812 dives')));

    final text = tester.widget<Text>(find.text('34 of 812 dives'));
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('returns the title alone without a subtitle', (tester) async {
    await tester.pumpWidget(_inBox(400, null));

    expect(find.byType(Text), findsOneWidget);
    expect(find.byType(Column), findsNothing);
  });
}

/// The rendered width of the full subtitle, measured unconstrained.
Future<double> _fullWidth(WidgetTester tester) async {
  await tester.pumpWidget(_inBox(1000, _count));
  return tester.getSize(find.text('34 of 812 dives')).width;
}
