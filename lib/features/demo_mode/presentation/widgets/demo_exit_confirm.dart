import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/demo_mode/presentation/widgets/demo_question_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asks before leaving demo mode, since leaving discards every change made to
/// the sample logbook, then leaves on confirm.
Future<void> confirmAndExitDemo(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final confirmed = await askDemoQuestion(
    context,
    title: l10n.demo_exit_confirm_title,
    body: l10n.demo_exit_confirm_body,
    action: l10n.demo_exit_confirm_action,
  );
  // The page that asked may have gone while the question was open, and its
  // ref with it.
  if (!confirmed || !context.mounted) return;
  await ref.read(demoExitActionProvider)();
}
