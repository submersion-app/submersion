import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/ui/app_actions.dart';
import 'package:submersion/features/global_search/presentation/providers/global_search_providers.dart';
import 'package:submersion/features/query/presentation/widgets/search_everywhere_row.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _field = Key('field');

/// A search field that shows the row only while it has focus, as the Dives
/// search header does, with nothing else putting the row in the field's tap
/// region.
class _FocusGatedRow extends StatefulWidget {
  const _FocusGatedRow();

  @override
  State<_FocusGatedRow> createState() => _FocusGatedRowState();
}

class _FocusGatedRowState extends State<_FocusGatedRow> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextField(key: _field, focusNode: _focus),
        if (_focus.hasFocus) const SearchEverywhereRow(text: 'wreck'),
        const Expanded(child: SizedBox.expand()),
      ],
    ),
  );
}

void main() {
  testWidgets('a finger tap opens global search though it drops the focus', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const _FocusGatedRow()),
        GoRoute(
          path: '/search',
          builder: (_, _) => const Scaffold(body: Text('page /search')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          // The app's own: a tap off the field drops its focus (#4813).
          actions: appActions(),
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.tap(find.byKey(_field));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(_field)),
    );

    // A frame between down and up, as a finger gives: the row must count as
    // part of the field, or the down unmounts it before the finger lifts.
    final finger = await tester.startGesture(
      tester.getCenter(find.byKey(kSearchEverywhereRowKey)),
    );
    await tester.pump();
    await finger.up();
    await tester.pumpAndSettle();

    expect(find.text('page /search'), findsOneWidget);
    expect(container.read(globalSearchRequestProvider)?.text, 'wreck');
  });
}
