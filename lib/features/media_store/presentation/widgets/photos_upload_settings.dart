import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "Upload new photos automatically", "Use cellular data" and Uploads, for a
/// device that keeps copies (spec section 8.3).
class PhotosUploadSettings extends ConsumerStatefulWidget {
  const PhotosUploadSettings({super.key});

  @override
  ConsumerState<PhotosUploadSettings> createState() =>
      _PhotosUploadSettingsState();
}

class _PhotosUploadSettingsState extends ConsumerState<PhotosUploadSettings> {
  // Null until loaded; the switches render only once values are known.
  bool? _autoUpload;
  bool? _photosOnCellular;

  /// A policy write is saving: both switches wait for it, so a later tap
  /// cannot race it and be overwritten by the older value.
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    logFailure(_load(), _PhotosUploadSettingsState, 'load policies');
  }

  Future<void> _load() async {
    final policies = ref.read(mediaStorePoliciesProvider);
    final autoUpload = await policies.autoUpload();
    final photosOnCellular = await policies.photosOnCellular();
    if (!mounted) return;
    setState(() {
      _autoUpload = autoUpload;
      _photosOnCellular = photosOnCellular;
    });
  }

  /// Shows [value] at once, and puts the switch back and says so when
  /// [write] fails, so it never shows a choice that was not saved. The
  /// switches are held until [write] settles.
  Future<void> _save(
    Future<void> Function() write, {
    required void Function(bool) apply,
    required bool value,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.equipmentConditionSettings_saveFailed;
    setState(() {
      apply(value);
      _saving = true;
    });
    try {
      await write();
    } catch (_) {
      if (!mounted) return;
      setState(() => apply(!value));
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_autoUpload case final autoUpload?)
          SwitchListTile(
            key: const Key('media-s3-policy-auto-upload'),
            secondary: const Icon(Icons.cloud_upload_outlined),
            title: Text(l10n.settings_photos_autoUpload),
            value: autoUpload,
            onChanged: _saving
                ? null
                : (value) => _save(
                    () => ref
                        .read(mediaStorePoliciesProvider)
                        .setAutoUpload(value),
                    apply: (v) => _autoUpload = v,
                    value: value,
                  ),
          ),
        if (_photosOnCellular case final onCellular?)
          SwitchListTile(
            key: const Key('media-s3-policy-photos-cellular'),
            secondary: const Icon(Icons.signal_cellular_alt),
            title: Text(l10n.settings_photos_cellular),
            value: onCellular,
            onChanged: _saving
                ? null
                : (value) => _save(
                    () => ref
                        .read(mediaStorePoliciesProvider)
                        .setPhotosOnCellular(value),
                    apply: (v) => _photosOnCellular = v,
                    value: value,
                  ),
          ),
        ListTile(
          key: const Key('media-s3-transfers'),
          leading: const Icon(Icons.swap_vert),
          title: Text(l10n.settings_photos_uploads),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              context.pushSettingsPage('/settings/photos-media/uploads'),
        ),
      ],
    );
  }
}
