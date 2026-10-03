import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_ask_providers.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const kDiveAskRowKey = ValueKey('dive-ask-row');

/// The search row's Ask action (#2773): `Ask: <typed text>` where the
/// on-device model works, the model download where it can be fetched, and
/// nothing anywhere else.
class DiveAskRow extends ConsumerWidget {
  const DiveAskRow({super.key, required this.text, required this.onAsk});

  final String text;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(explorePlatformSupportedProvider)) {
      return const SizedBox.shrink();
    }
    final availability = ref.watch(exploreAvailabilityProvider);
    // Closed while a probe runs: a locale change re-probes, and the
    // previous locale's answer is still in the AsyncValue meanwhile.
    if (availability.isLoading) return const SizedBox.shrink();
    final l10n = context.l10n;
    final ask = ref.watch(diveAskProvider);
    final Widget row = switch (availability.value) {
      NlAvailability.available => ListTile(
        key: kDiveAskRowKey,
        dense: true,
        leading: ask.running
            ? const _Spinner()
            : const Icon(Icons.auto_awesome),
        title: Text(
          ask.running
              ? l10n.diveLog_ask_running
              : l10n.diveLog_ask_row(text.trim()),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: ask.error == null
            ? null
            : Text(
                nlErrorText(l10n, ask.error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
        onTap: ask.running ? null : onAsk,
      ),
      NlAvailability.downloadable => ListTile(
        key: kDiveAskRowKey,
        dense: true,
        leading: const Icon(Icons.download),
        title: Text(l10n.explore_download_button),
        onTap: () => _download(context, ref),
      ),
      NlAvailability.downloading => ListTile(
        key: kDiveAskRowKey,
        dense: true,
        leading: _Spinner(value: ref.watch(exploreDownloadProgressProvider)),
        title: Text(l10n.explore_download_running),
      ),
      _ => const SizedBox.shrink(),
    };
    // Inside the field's tap region, like the jump rows: on desktop a
    // mouse press elsewhere unfocuses the field before the tap lands.
    return TextFieldTapRegion(child: row);
  }

  void _download(BuildContext context, WidgetRef ref) {
    // The container, not this widget's ref: the download outlives the row.
    // Re-probe however the stream ends, so a failed download offers the
    // button again instead of an uncaught error.
    final container = ProviderScope.containerOf(context, listen: false);
    final progress = container.read(exploreDownloadProgressProvider.notifier);
    void reprobe() {
      progress.state = null;
      container.invalidate(exploreAvailabilityProvider);
    }

    ref
        .read(nlEngineProvider)
        .download()
        .listen(
          (fraction) => progress.state = fraction.clamp(0.0, 1.0),
          onError: (Object _) => reprobe(),
          onDone: reprobe,
        );
    // Once started, the platform reports it as downloading.
    reprobe();
  }
}

/// Indeterminate unless [value] (0 to 1) says how far a download has got.
class _Spinner extends StatelessWidget {
  const _Spinner({this.value});

  final double? value;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 20,
    child: CircularProgressIndicator(strokeWidth: 2, value: value),
  );
}

/// The diver-facing sentence for a model failure.
String nlErrorText(AppLocalizations l10n, NlError e) => switch (e) {
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
