import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/refine_count_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/show_refine_panel.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/query/presentation/providers/saved_query_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

/// Opens the real Refine panel over a phone-sized page targeting
/// [target], and returns the container to read the target from.
Future<ProviderContainer> openRefinePanel(
  WidgetTester tester, {
  required StateProvider<DiveFilterState> target,
  FutureOr<int> Function(DiveFilterState draft)? count,
  List<SavedQueryLoad> saved = const [],
  List<Override> extra = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 900);
  addTearDown(tester.view.reset);
  final base = await getBaseOverrides();
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        refineMatchCountProvider.overrideWith(
          (ref, draft) async => (count ?? (_) => 0)(draft),
        ),
        savedQueryLoadsProvider('dives').overrideWith((ref) async => saved),
        queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
        ...extra,
      ].cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return ElevatedButton(
                onPressed: () =>
                    showRefinePanel(context, filterProvider: target),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return container;
}
