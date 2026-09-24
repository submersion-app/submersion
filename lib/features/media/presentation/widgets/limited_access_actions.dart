import 'package:flutter/material.dart';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/presentation/providers/photo_access_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "Allow full access" and "Choose photo again", for a photo outside the
/// user's limited selection (media sync program spec 6.3). Each hands off
/// to the system and calls [onChanged] when the user comes back, so the
/// caller can look for the photo again.
class LimitedAccessActions extends ConsumerWidget {
  const LimitedAccessActions({super.key, required this.onChanged});

  /// Called after either action returns, whether or not it succeeded:
  /// the user may have changed access in the meantime.
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final actions = ref.watch(photoAccessActionsProvider);

    Future<void> run(Future<void> Function() action) async {
      try {
        await action();
      } on Object catch (e, stackTrace) {
        // An OS without the limited-selection sheet, or a platform channel
        // failure. The buttons are an offer; a failure is logged, not shown.
        LoggerService.forClass(
          LimitedAccessActions,
          category: LogCategory.media,
        ).warning(
          'Photo access action failed',
          error: e,
          stackTrace: stackTrace,
        );
      }
      if (context.mounted) onChanged();
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        TextButton(
          onPressed: () => run(actions.openSettings),
          child: Text(l10n.media_limitedAccess_allowFullAccess),
        ),
        TextButton(
          onPressed: () => run(actions.chooseMorePhotos),
          child: Text(l10n.media_limitedAccess_choosePhotoAgain),
        ),
      ],
    );
  }
}
