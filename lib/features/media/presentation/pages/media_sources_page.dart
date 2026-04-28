import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';

/// Settings page listing all media sources.
///
/// Phase 1 only renders the platform photo library status and a
/// Diagnostics toggle that exposes the picker's hidden Files/URL tabs.
/// Phase 2 appends a Local files subsection; Phase 3 a Network Sources
/// subsection; Phase 4 a Connected Services subsection.
class MediaSourcesPage extends ConsumerWidget {
  const MediaSourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Media Sources')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.photo_library_outlined),
                  title: Text('Photo library'),
                  subtitle: Text('Apple Photos / Google Photos / iCloud'),
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
                    final shown = ref.watch(mediaPickerHiddenTabsProvider);
                    return ListTile(
                      leading: const Icon(Icons.bug_report_outlined),
                      title: const Text('Show hidden picker tabs'),
                      subtitle: Text(
                        shown
                            ? 'Files and URL tabs visible in picker (debug)'
                            : 'Hidden by default',
                      ),
                      trailing: Switch(
                        value: shown,
                        onChanged: (v) =>
                            ref
                                    .read(
                                      mediaPickerHiddenTabsProvider.notifier,
                                    )
                                    .state =
                                v,
                      ),
                    );
                  },
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
                      title: const Text('Local files'),
                      subtitle: asyncDiag.when(
                        data: (d) =>
                            // TODO(media): l10n
                            Text(
                              '${d.available} available, ${d.unavailable} unavailable',
                            ),
                        loading: () => const Text('Counting…'),
                        error: (e, _) => Text('Error: $e'),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                Consumer(
                  builder: (context, ref, _) {
                    return ListTile(
                      leading: const Icon(Icons.refresh),
                      // TODO(media): l10n
                      title: const Text('Re-verify all local files'),
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final updated = await ref
                            .read(localFilesDiagnosticsServiceProvider)
                            .reverifyAll();
                        // TODO(media): l10n
                        messenger.showSnackBar(
                          SnackBar(content: Text('$updated items updated')),
                        );
                        ref.invalidate(localFilesDiagnosticsProvider);
                      },
                    );
                  },
                ),
                if (Platform.isAndroid) ...[
                  const Divider(height: 1),
                  Consumer(
                    builder: (context, ref, _) {
                      final asyncUsage = ref.watch(androidUriUsageProvider);
                      return ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: const Text('Android URI permissions'),
                        subtitle: asyncUsage.when(
                          data: (usage) =>
                              // TODO(media): l10n
                              Text('$usage / 128 persistable URIs in use'),
                          loading: () => const Text('Loading…'),
                          error: (e, _) => Text('Error: $e'),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
