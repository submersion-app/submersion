import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/auto_update/domain/entities/update_status.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';

class UpdateBanner extends ConsumerStatefulWidget {
  const UpdateBanner({super.key});

  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final status = ref.watch(updateStatusProvider);
    final version = switch (status) {
      UpdateAvailable(:final version) => version,
      ReadyToInstall(:final version) => version,
      _ => null,
    };

    if (version == null) return const SizedBox.shrink();

    final downloadUrl = switch (status) {
      UpdateAvailable(:final downloadUrl) => downloadUrl,
      _ => null,
    };

    final theme = Theme.of(context);

    return MaterialBanner(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(Icons.system_update, color: theme.colorScheme.primary),
      content: Text(
        'Version $version is available.',
        style: theme.textTheme.bodyMedium,
      ),
      actions: [
        if (downloadUrl != null)
          TextButton(
            onPressed: () => _openDownload(downloadUrl),
            child: const Text('Download'),
          ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          tooltip: 'Dismiss',
          onPressed: () => setState(() => _dismissed = true),
        ),
      ],
    );
  }

  Future<void> _openDownload(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
