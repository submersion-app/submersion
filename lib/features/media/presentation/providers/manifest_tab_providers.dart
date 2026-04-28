// State + notifier for the Manifest mode panel inside the URL tab
// (Phase 3b, Task 13).
//
// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3b.md`
// Task 13. Deviations from the plan code:
//
// - The plan re-declares `manifestFetchServiceProvider` here (with an
//   `UnimplementedError` body, expecting tests to override it). The
//   provider already exists in
//   `lib/features/media/presentation/providers/media_resolver_providers.dart`
//   (added by Task 7 / wired by Task 12). To avoid two competing
//   providers with the same name, this file imports the existing one and
//   reuses it for the `manifestTabProvider` composition. Tests override
//   the same provider — no behavioral change.
//
// - `ManifestTabFetching` and `ManifestTabError` carry the URL string
//   they were triggered with so the panel widget can keep the field
//   populated across the async boundary. The plan code has the same
//   shape.
//
// - `changeFormatOverride` re-fetches with the override (matching the
//   plan's semantics). On a `ManifestFetchNotModified` outcome it
//   returns the current preview but with the new override marker —
//   exactly what the plan describes ("Re-show old preview with the new
//   override marker").
import 'package:flutter_riverpod/legacy.dart';

import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';
import 'package:submersion/features/media/data/services/manifest_fetch_service.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';

/// Sealed discriminated union describing the lifecycle of the Manifest
/// mode panel: paste-URL → fetch → preview → (subscribe / commit).
///
/// State machine:
/// ```
/// idle
///   -> fetching       (Fetch tap)
///        -> showingPreview(success)
///        -> error(message)
///   -> committing     (Import tap, wired in Task 14)
///        -> idle      (after success snackbar)
/// ```
sealed class ManifestTabState {
  const ManifestTabState();
}

/// Initial state — the URL field is empty (or the user is typing).
class ManifestTabIdle extends ManifestTabState {
  const ManifestTabIdle();
}

/// In flight: the user tapped Fetch and we are awaiting
/// [ManifestFetchService.fetch]. The original [url] is preserved so the
/// panel can keep the input field populated.
class ManifestTabFetching extends ManifestTabState {
  final String url;
  const ManifestTabFetching(this.url);
}

/// Successful fetch and parse. The preview pane renders [result].
///
/// [formatOverride] is the user's manual format selection (if any),
/// applied via the format-chip dropdown. [subscribe] / [pollIntervalSeconds]
/// are bound to the Subscribe checkbox + poll-interval dropdown; Task 14
/// wires the actual subscription persistence on Import.
class ManifestTabShowingPreview extends ManifestTabState {
  final String url;
  final ManifestParseResult result;
  final ManifestFormat? formatOverride;
  final bool subscribe;
  final int pollIntervalSeconds;

  const ManifestTabShowingPreview({
    required this.url,
    required this.result,
    this.formatOverride,
    this.subscribe = false,
    this.pollIntervalSeconds = 86400,
  });

  ManifestTabShowingPreview copyWith({
    ManifestParseResult? result,
    ManifestFormat? formatOverride,
    bool? subscribe,
    int? pollIntervalSeconds,
  }) {
    return ManifestTabShowingPreview(
      url: url,
      result: result ?? this.result,
      formatOverride: formatOverride ?? this.formatOverride,
      subscribe: subscribe ?? this.subscribe,
      pollIntervalSeconds: pollIntervalSeconds ?? this.pollIntervalSeconds,
    );
  }
}

/// Terminal failure — bad URL, HTTP error, sniff failure, parse failure,
/// or 304 Not-Modified (which is treated as "nothing new to preview").
class ManifestTabError extends ManifestTabState {
  final String url;
  final String message;
  const ManifestTabError({required this.url, required this.message});
}

/// In flight: the user tapped Import and we are awaiting the commit /
/// subscription persistence. Task 14 wires the actual commit flow.
class ManifestTabCommitting extends ManifestTabState {
  final ManifestTabShowingPreview from;
  const ManifestTabCommitting(this.from);
}

/// StateNotifier driving the Manifest panel. Mirrors the URL tab notifier
/// pattern: a single sealed state, a handful of intent-named methods that
/// transition between states, and a concrete subclass-friendly setter
/// for the "subscribe" + "poll interval" inputs.
class ManifestTabNotifier extends StateNotifier<ManifestTabState> {
  ManifestTabNotifier({required ManifestFetchService fetchService})
    : _fetchService = fetchService,
      super(const ManifestTabIdle());

  final ManifestFetchService _fetchService;

  /// Triggered by the Fetch button. Validates the URL, transitions to
  /// `Fetching`, then either `ShowingPreview` (success) or `Error`
  /// (any failure mode).
  Future<void> fetch(String urlText) async {
    final trimmed = urlText.trim();
    final url = Uri.tryParse(trimmed);
    if (url == null || !url.hasScheme || !url.hasAuthority) {
      // TODO(media): l10n
      state = ManifestTabError(url: trimmed, message: 'Invalid URL');
      return;
    }
    state = ManifestTabFetching(trimmed);
    final outcome = await _fetchService.fetch(url);
    switch (outcome) {
      case ManifestFetchSuccess():
        state = ManifestTabShowingPreview(url: trimmed, result: outcome.parsed);
      case ManifestFetchNotModified():
        // TODO(media): l10n
        state = ManifestTabError(
          url: trimmed,
          message: 'Server reports unchanged',
        );
      case ManifestFetchFailure():
        // TODO(media): l10n
        final reason = outcome.unauthorized
            ? 'Unauthorized — sign in via Settings → Network Sources'
            : outcome.message;
        state = ManifestTabError(url: trimmed, message: reason);
    }
  }

  /// Triggered by the format-chip dropdown when the user wants to override
  /// the auto-detected format. Re-fetches with the new format. A 304 is
  /// treated as "no body change, just remember the override marker"
  /// because the parsed result is still the same bytes.
  Future<void> changeFormatOverride(ManifestFormat? format) async {
    final current = state;
    if (current is! ManifestTabShowingPreview) return;
    state = ManifestTabFetching(current.url);
    final url = Uri.parse(current.url);
    final outcome = await _fetchService.fetch(url, formatOverride: format);
    switch (outcome) {
      case ManifestFetchSuccess():
        state = ManifestTabShowingPreview(
          url: current.url,
          result: outcome.parsed,
          formatOverride: format,
          subscribe: current.subscribe,
          pollIntervalSeconds: current.pollIntervalSeconds,
        );
      case ManifestFetchFailure():
        // TODO(media): l10n
        final reason = outcome.unauthorized
            ? 'Unauthorized — sign in via Settings → Network Sources'
            : outcome.message;
        state = ManifestTabError(url: current.url, message: reason);
      case ManifestFetchNotModified():
        // 304 → re-show the existing preview but with the new override
        // marker recorded.
        state = current.copyWith(formatOverride: format);
    }
  }

  /// Toggle the "Subscribe to updates" checkbox in the preview pane. Only
  /// valid in [ManifestTabShowingPreview]; no-op otherwise.
  void setSubscribe(bool subscribe) {
    final s = state;
    if (s is ManifestTabShowingPreview) {
      state = s.copyWith(subscribe: subscribe);
    }
  }

  /// Set the poll interval (in seconds) chosen via the dropdown. Only
  /// valid in [ManifestTabShowingPreview]; no-op otherwise.
  void setPollInterval(int seconds) {
    final s = state;
    if (s is ManifestTabShowingPreview) {
      state = s.copyWith(pollIntervalSeconds: seconds);
    }
  }

  /// Drop back to the idle state (used by the panel's "try again" /
  /// reset path after an error).
  void reset() => state = const ManifestTabIdle();
}

/// StateNotifierProvider for the Manifest panel. Composes the existing
/// [manifestFetchServiceProvider] from
/// `media_resolver_providers.dart` so both the panel and the
/// subscription poller share one fetch service instance.
final manifestTabProvider =
    StateNotifierProvider<ManifestTabNotifier, ManifestTabState>(
      (ref) => ManifestTabNotifier(
        fetchService: ref.watch(manifestFetchServiceProvider),
      ),
    );
