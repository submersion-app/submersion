import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_providers.dart';
import 'package:submersion/features/explore/presentation/widgets/explore_charts.dart';
import 'package:submersion/features/explore/presentation/widgets/explore_chip_rows.dart';
import 'package:submersion/features/explore/presentation/widgets/explore_results_list.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A sentence in, a verifiable answer out: the filter it understood as
/// chips, the words it could not place, a count, charts and the dives.
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Hide the model's cold start behind the page transition.
    Future<void>.microtask(
      () => ref.read(nlEngineProvider).prepare().catchError((_) {}),
    );
    _controller.text = ref.read(exploreQueryProvider).sentence;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() =>
      ref.read(exploreQueryProvider.notifier).run(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(exploreQueryProvider);
    final recent = ref.watch(recentQueriesProvider).value ?? const [];
    final availability = ref.watch(exploreAvailabilityProvider).value;
    final count = ref.watch(exploreCountProvider);
    final compiled = state.compiled;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.explore_title)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  key: const ValueKey('explore-sentence'),
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: l10n.explore_hint,
                    prefixIcon: const Icon(Icons.auto_awesome),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: state.running ? null : _submit,
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submit(),
                  minLines: 1,
                  maxLines: 3,
                ),
                if (availability == NlAvailability.downloadable ||
                    availability == NlAvailability.downloading)
                  _DownloadPrompt(
                    downloading: availability == NlAvailability.downloading,
                  ),
                if (recent.isNotEmpty && compiled == null) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.explore_recent_title,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final r in recent.take(5))
                        ActionChip(
                          label: Text(r.sentence),
                          onPressed: () {
                            _controller.text = r.sentence;
                            ref
                                .read(exploreQueryProvider.notifier)
                                .rerun(r.sentence, r.parsed);
                          },
                        ),
                    ],
                  ),
                ],
                if (state.running)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _errorText(l10n, state.error!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (compiled != null) ...[
                  const SizedBox(height: 12),
                  ExploreUnderstoodRow(compiled: compiled),
                  const SizedBox(height: 8),
                  ExploreAttentionRow(compiled: compiled),
                  const SizedBox(height: 12),
                  Text(
                    l10n.explore_count(count.value ?? 0),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ExploreCharts(requests: compiled.charts),
                  const ExploreResultsList(),
                ],
              ],
            ),
          ),
          if (compiled != null && compiled.filter.hasActiveFilters)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          ref.read(diveFilterProvider.notifier).state =
                              compiled.filter;
                          // go, not push: the handoff moves to a shell tab.
                          context.go('/dives');
                        },
                        child: Text(l10n.explore_handoff_diveList),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          ref.read(statisticsFilterProvider.notifier).state =
                              compiled.filter;
                          context.go('/statistics');
                        },
                        child: Text(l10n.explore_handoff_statistics),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _errorText(AppLocalizations l10n, NlError e) => switch (e) {
    NlError.unsupportedLocale => l10n.explore_error_unsupportedLocale,
    NlError.contextExceeded => l10n.explore_error_contextExceeded,
    NlError.guardrail => l10n.explore_error_guardrail,
    NlError.refusal => l10n.explore_error_refusal,
    NlError.decodingFailure => l10n.explore_error_decodingFailure,
    NlError.modelNotReady => l10n.explore_error_modelNotReady,
    NlError.quotaExceeded => l10n.explore_error_quotaExceeded,
    NlError.schemaMismatch => l10n.explore_error_schemaMismatch,
    NlError.unknown => l10n.explore_error_unknown,
  };
}

class _DownloadPrompt extends ConsumerWidget {
  const _DownloadPrompt({required this.downloading});
  final bool downloading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (downloading) {
      return ListTile(
        leading: const CircularProgressIndicator(),
        title: Text(l10n.explore_download_running),
      );
    }
    return ListTile(
      leading: const Icon(Icons.download),
      title: Text(l10n.explore_download_button),
      onTap: () {
        ref
            .read(nlEngineProvider)
            .download()
            .listen(
              (_) {},
              onDone: () => ref.invalidate(exploreAvailabilityProvider),
            );
      },
    );
  }
}
