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
