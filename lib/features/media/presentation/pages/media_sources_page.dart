import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings page listing all media sources: the platform photo library,
/// local-file diagnostics, network sources, and the Adobe Lightroom
/// connector.
class MediaSourcesPage extends ConsumerWidget {
  const MediaSourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings_mediaSources_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(context.l10n.media_source_gallery),
                  subtitle: Text(
                    context.l10n.settings_mediaSources_photoLibrarySubtitle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final asyncDiag = ref.watch(localFilesDiagnosticsProvider);
                    return ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(context.l10n.media_source_localFile),
                      subtitle: asyncDiag.when(
                        data: (d) => Text(
                          context.l10n.settings_mediaSources_localFilesCounts(
                            d.available,
                            d.unavailable,
                          ),
                        ),
                        loading: () =>
                            Text(context.l10n.settings_mediaSources_counting),
                        error: (e, _) => Text(
                          context.l10n.settings_mediaSources_error('$e'),
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                Consumer(
                  builder: (context, ref, _) {
                    return ListTile(
                      leading: const Icon(Icons.refresh),
                      title: Text(
                        context.l10n.settings_mediaSources_reverifyAll,
                      ),
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final l10n = context.l10n;
                        final sweep = ref.read(mediaVerificationSweepProvider);
                        try {
                          final outcome = await sweep.run(
                            sourceTypes: {MediaSourceType.localFile},
                          );
                          if (!context.mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.settings_mediaSources_reverifyResult(
                                  outcome.flipped,
                                ),
                              ),
                            ),
                          );
                          ref.invalidate(localFilesDiagnosticsProvider);
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.settings_mediaSources_reverifyFailed('$e'),
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
                const Divider(height: 1),
                // Unfiltered counterpart to the re-verify action above, which
                // only ever looked at local files. A gallery, URL or connector
                // row had its orphan flag written at link time and never
                // again, so nothing downstream of isOrphaned could report the
                // truth about it.
                Consumer(
                  builder: (context, ref, _) {
                    return ListTile(
                      leading: const Icon(Icons.fact_check_outlined),
                      title: Text(context.l10n.settings_mediaSources_checkAll),
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final l10n = context.l10n;
                        final sweep = ref.read(mediaVerificationSweepProvider);
                        try {
                          final outcome = await sweep.run();
                          if (!context.mounted) return;
                          // Only a WHOLLY inconclusive pass is reported as
                          // blocked. That pass checked nothing, so "0 items
                          // updated" would read as a clean bill of health.
                          // A partial one did real work, and inconclusive
                          // aggregates several causes, so letting a single
                          // unreachable row take over the message would both
                          // hide the real result and name a cause that may
                          // not apply to it.
                          final blocked =
                              outcome.processed > 0 &&
                              outcome.inconclusive == outcome.processed;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                blocked
                                    ? l10n.settings_mediaSources_checkAllBlocked(
                                        outcome.inconclusive,
                                      )
                                    : l10n.settings_mediaSources_checkAllResult(
                                        outcome.flipped,
                                      ),
                              ),
                            ),
                          );
                          ref.invalidate(localFilesDiagnosticsProvider);
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.settings_mediaSources_reverifyFailed('$e'),
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
                // coverage:ignore-start
                // Android-only URI usage gauge (Android caps persistable URIs
                // at 128 per app). Test suite runs on macOS hosts so this
                // branch is unreachable; provider is unit-tested separately
                // in media_resolver_providers_test.
                if (Platform.isAndroid) ...[
                  const Divider(height: 1),
                  Consumer(
                    builder: (context, ref, _) {
                      final asyncUsage = ref.watch(androidUriUsageProvider);
                      return ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: Text(
                          context.l10n.settings_mediaSources_androidUriTitle,
                        ),
                        subtitle: asyncUsage.when(
                          data: (usage) => Text(
                            context.l10n.settings_mediaSources_androidUriUsage(
                              usage,
                              128,
                            ),
                          ),
                          loading: () =>
                              Text(context.l10n.settings_mediaSources_loading),
                          error: (e, _) => Text(
                            context.l10n.settings_mediaSources_error('$e'),
                          ),
                        ),
                      );
                    },
                  ),
                ],
                // coverage:ignore-end
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: Text(
                context.l10n.settings_photosMedia_networkSources_title,
              ),
              subtitle: Text(
                context.l10n.settings_photosMedia_networkSources_subtitle,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  context.push('/settings/media-sources/network-sources'),
            ),
          ),
          // Lightroom entry point hidden pending Adobe review
          // (lightroomUiEnabled). Wraps the spacer too so no orphan gap
          // is left behind when hidden.
          if (lightroomUiEnabled) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_sync_outlined),
                title: Text(context.l10n.settings_lightroom_title),
                subtitle: Text(context.l10n.settings_lightroom_subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/lightroom'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
