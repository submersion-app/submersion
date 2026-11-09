import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/info_sheet/info_button.dart';

/// Shared building blocks for the settings section pages.

Widget buildSettingsSectionHeader(
  BuildContext context,
  String title, {
  InfoContentBuilder? info,
}) {
  final text = Text(
    title,
    style: Theme.of(context).textTheme.titleSmall?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.bold,
    ),
  );
  if (info == null) return text;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: text),
      HeaderInfoButton(title: title, content: info, height: 20),
    ],
  );
}

Widget buildSettingsInfoCard(
  BuildContext context,
  String title,
  String content,
) {
  return Card(
    color: Theme.of(
      context,
    ).colorScheme.primaryContainer.withValues(alpha: 0.3),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}
