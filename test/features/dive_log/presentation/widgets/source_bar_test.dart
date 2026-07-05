import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/source_bar.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

SourceBarItem _item({
  required String sourceId,
  required String label,
  bool isActive = false,
  bool isPrimary = false,
  bool isOverlaid = false,
  bool hasProfile = true,
}) {
  return SourceBarItem(
    sourceId: sourceId,
    label: label,
    color: Colors.cyan,
    isActive: isActive,
    isPrimary: isPrimary,
    isOverlaid: isOverlaid,
    hasProfile: hasProfile,
  );
}

void main() {
  testWidgets('renders nothing for a single source', (tester) async {
    await tester.pumpWidget(
      _harness(
        SourceBar(
          sources: [
            _item(sourceId: 'src-a', label: 'Kiyans Teric', isActive: true),
          ],
          onActivate: (_) {},
          onToggleOverlay: (_, _) {},
          onMenuAction: (_, _) {},
        ),
      ),
    );

    expect(find.text('Kiyans Teric'), findsNothing);
  });

  testWidgets('shows both chips; only non-active chips get an overlay eye', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        SourceBar(
          sources: [
            _item(
              sourceId: 'src-a',
              label: 'Kiyans Teric',
              isActive: true,
              isPrimary: true,
            ),
            _item(sourceId: 'src-b', label: 'Erics Teric'),
          ],
          onActivate: (_) {},
          onToggleOverlay: (_, _) {},
          onMenuAction: (_, _) {},
        ),
      ),
    );

    expect(find.text('Kiyans Teric'), findsOneWidget);
    expect(find.text('Erics Teric'), findsOneWidget);
    // One eye icon only (the non-active chip's), currently not overlaid.
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility), findsNothing);
  });

  testWidgets('tapping a non-active chip body activates it', (tester) async {
    final activated = <String>[];
    await tester.pumpWidget(
      _harness(
        SourceBar(
          sources: [
            _item(
              sourceId: 'src-a',
              label: 'Kiyans Teric',
              isActive: true,
              isPrimary: true,
            ),
            _item(sourceId: 'src-b', label: 'Erics Teric'),
          ],
          onActivate: activated.add,
          onToggleOverlay: (_, _) {},
          onMenuAction: (_, _) {},
        ),
      ),
    );

    await tester.tap(find.text('Erics Teric'));
    await tester.pump();

    expect(activated, ['src-b']);
  });

  testWidgets('tapping the eye toggles overlay on', (tester) async {
    final toggles = <(String, bool)>[];
    await tester.pumpWidget(
      _harness(
        SourceBar(
          sources: [
            _item(
              sourceId: 'src-a',
              label: 'Kiyans Teric',
              isActive: true,
              isPrimary: true,
            ),
            _item(sourceId: 'src-b', label: 'Erics Teric'),
          ],
          onActivate: (_) {},
          onToggleOverlay: (id, overlaid) => toggles.add((id, overlaid)),
          onMenuAction: (_, _) {},
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();

    expect(toggles, [('src-b', true)]);
  });

  testWidgets('primary chip shows the star icon', (tester) async {
    await tester.pumpWidget(
      _harness(
        SourceBar(
          sources: [
            _item(
              sourceId: 'src-a',
              label: 'Kiyans Teric',
              isActive: true,
              isPrimary: true,
            ),
            _item(sourceId: 'src-b', label: 'Erics Teric'),
          ],
          onActivate: (_) {},
          onToggleOverlay: (_, _) {},
          onMenuAction: (_, _) {},
        ),
      ),
    );

    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('menu offers set primary and split; split fires', (tester) async {
    final actions = <(String, SourceMenuAction)>[];
    await tester.pumpWidget(
      _harness(
        SourceBar(
          sources: [
            _item(
              sourceId: 'src-a',
              label: 'Kiyans Teric',
              isActive: true,
              isPrimary: true,
            ),
            _item(sourceId: 'src-b', label: 'Erics Teric'),
          ],
          onActivate: (_) {},
          onToggleOverlay: (_, _) {},
          onMenuAction: (id, action) => actions.add((id, action)),
        ),
      ),
    );

    // Open the non-primary chip's menu (the second more_vert icon).
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();

    expect(find.text('Set as primary'), findsOneWidget);
    expect(find.text('Split into separate dive'), findsOneWidget);

    await tester.tap(find.text('Split into separate dive'));
    await tester.pumpAndSettle();

    expect(actions, [('src-b', SourceMenuAction.split)]);
  });

  testWidgets('primary chip menu omits set primary', (tester) async {
    await tester.pumpWidget(
      _harness(
        SourceBar(
          sources: [
            _item(
              sourceId: 'src-a',
              label: 'Kiyans Teric',
              isActive: true,
              isPrimary: true,
            ),
            _item(sourceId: 'src-b', label: 'Erics Teric'),
          ],
          onActivate: (_) {},
          onToggleOverlay: (_, _) {},
          onMenuAction: (_, _) {},
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();

    expect(find.text('Set as primary'), findsNothing);
    expect(find.text('Split into separate dive'), findsOneWidget);
  });

  testWidgets('profile-less source has a disabled eye', (tester) async {
    await tester.pumpWidget(
      _harness(
        SourceBar(
          sources: [
            _item(
              sourceId: 'src-a',
              label: 'Kiyans Teric',
              isActive: true,
              isPrimary: true,
            ),
            _item(sourceId: 'src-b', label: 'Erics Teric', hasProfile: false),
          ],
          onActivate: (_) {},
          onToggleOverlay: (_, _) {},
          onMenuAction: (_, _) {},
        ),
      ),
    );

    final eye = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.visibility_off_outlined),
    );
    expect(eye.onPressed, isNull);
  });
}
