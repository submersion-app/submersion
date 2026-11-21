import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/images/profile_photo_codec.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/presentation/certification_entry_display.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_level_dropdown_items.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_option.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

/// The certification form's own widgets, kept for the certification
/// page's card editors (issue #4527, phase 3).

/// Reads a picked image: its bytes and its declared name. A test hands in
/// its own in place of the platform picker.
typedef CertificationPhotoSource =
    Future<({Uint8List bytes, String name})?> Function(ImageSource source);

/// Asks for the camera or the gallery, picks a card photo and encodes it
/// as a stored card image; null when the diver backs out, or when it cannot
/// be used, which a snackbar says. Stops at demo mode's seal first.
Future<Uint8List?> pickCertificationCardPhoto(
  BuildContext context, {
  CertificationPhotoSource? pickOverride,
}) async {
  if (!demoSealGuard(context, DemoSealedFeature.mediaImport)) return null;
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: Text(context.l10n.certifications_edit_photo_takePhoto),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: Text(
              context.l10n.certifications_edit_photo_chooseFromGallery,
            ),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;

  try {
    // No maxWidth / maxHeight / imageQuality here: image_picker_macos,
    // image_picker_windows and image_picker_linux all document those
    // arguments as silently ignored, so a desktop pick entered the database
    // at full size and rode into every sync changeset as base64. The cap is
    // enforced below instead, in Dart, where it holds on every platform.
    final ({Uint8List bytes, String name})? picked;
    if (pickOverride != null) {
      picked = await pickOverride(source);
    } else {
      final file = await ImagePicker().pickImage(source: source);
      // Read through the XFile handle, not File(picked.path). A picked file
      // is a HANDLE: on Android SAF the path can be unusable, and
      // image_picker makes no promise it addresses a real filesystem entry.
      picked = file == null
          ? null
          : (bytes: await file.readAsBytes(), name: file.name);
    }
    if (picked == null) return null;

    final encoded = await encodeStoredImage(
      ImageEncodeRequest.fromBytes(
        bytes: picked.bytes,
        spec: ImageEncodeSpec.certificationCard,
        declaredName: picked.name,
      ),
    );
    if (encoded.outcome != ImageEncodeOutcome.encoded) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            encoded.outcome == ImageEncodeOutcome.tooLarge
                ? l10n.profilePhoto_error_tooLarge
                : l10n.profilePhoto_error_undecodable,
          ),
        ),
      );
      return null;
    }
    return encoded.bytes;
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.certifications_edit_snackBar_errorPhoto('$e')),
      ),
    );
    return null;
  }
}

/// One side of the card: its photo with a remove button, or a place to add
/// one.
class CertificationPhotoCard extends StatelessWidget {
  const CertificationPhotoCard({
    super.key,
    required this.label,
    required this.imageData,
    required this.onPick,
    required this.onDelete,
  });

  final String label;
  final Uint8List? imageData;
  final VoidCallback onPick;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final imageData = this.imageData;
    final hasPhoto = imageData != null;

    return Semantics(
      button: true,
      label: hasPhoto
          ? context.l10n.certifications_edit_photo_attachedSemanticLabel(label)
          : context.l10n.certifications_edit_photo_addSemanticLabel(label),
      child: AspectRatio(
        aspectRatio: 1.6, // Standard card aspect ratio
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPick,
            child: hasPhoto
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        imageData,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _EmptyPhoto(label: label),
                      ),
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: context.l10n
                              .certifications_edit_photo_removeTooltip(label),
                          color: Colors.white,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                          ),
                          iconSize: 18,
                          onPressed: onDelete,
                        ),
                      ),
                    ],
                  )
                : _EmptyPhoto(label: label),
          ),
        ),
      ),
    );
  }
}

class _EmptyPhoto extends StatelessWidget {
  const _EmptyPhoto({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo_outlined,
            size: 32,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A date the diver taps to pick, with a button to clear it.
class CertificationDatePickerField extends ConsumerWidget {
  final String label;
  final DateTime? value;
  final IconData icon;
  final String? helpText;
  final ValueChanged<DateTime?> onChanged;

  const CertificationDatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.helpText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(certificationCatalogSyncProvider);
    final units = ref.watch(unitFormatterProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: value != null
              ? '$label: ${units.formatDate(value)}. Tap to change'
              : '$label: not set. Tap to select',
          child: InkWell(
            onTap: () => _pickDate(context),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: Icon(icon),
                suffixIcon: value != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: context.l10n
                            .certifications_edit_datePicker_clearTooltip(label),
                        onPressed: () => onChanged(null),
                      )
                    : const Icon(Icons.calendar_today),
              ),
              child: Text(
                value != null
                    ? units.formatDate(value)
                    : context.l10n.certifications_edit_datePicker_tapToSelect,
                style: TextStyle(
                  color: value != null
                      ? null
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        if (helpText != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, top: 4),
            child: Text(
              helpText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: value ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onChanged(picked);
    }
  }
}

/// Items for the certification dropdown of [agency] in [catalog], grouped
/// into the agency's progression ladder and the cross-agency specialties.
///
/// Headers are disabled items carrying their own [CertificationOption.header]
/// value, so no two rows share a value: see [CertificationOption] for why
/// DropdownButton requires that. "Not specified" leads the list because it is
/// the clear-selection choice, not for any correctness reason.
List<DropdownMenuItem<CertificationOption>> certificationLevelItems(
  BuildContext context,
  CertificationCatalog catalog,
  String agency,
  String? level,
) {
  final theme = Theme.of(context);
  final ladder = catalog.ladderFor(agency);
  final specialties = catalog.specialtiesFor(agency);

  // A stored value from another agency's catalog still has to render.
  final extra =
      (level != null &&
          level != CertificationLevel.other.name &&
          !ladder.any((e) => e.id == level) &&
          !specialties.any((e) => e.id == level))
      ? catalog.level(level)
      : null;

  DropdownMenuItem<CertificationOption> header(String key, String text) =>
      DropdownMenuItem<CertificationOption>(
        enabled: false,
        value: CertificationOption.header(key),
        child: Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  DropdownMenuItem<CertificationOption> item(LevelEntry value) =>
      DropdownMenuItem<CertificationOption>(
        value: CertificationOption.value(value.id),
        child: Text(value.localizedName(context.l10n)),
      );

  final grouped = buildGroupedCertificationItems(
    agency: agency,
    ladder: ladder,
    specialties: specialties,
    extra: extra,
    l10n: context.l10n,
    header: header,
    item: item,
  );

  return [
    DropdownMenuItem<CertificationOption>(
      value: const CertificationOption.value(null),
      child: Text(context.l10n.certifications_edit_certification_notSpecified),
    ),
    ...grouped.items,
    if (extra != null && !grouped.extraRenderedInGroup) item(extra),
    // Another diver's custom agency takes certifications from its owner
    // only (issue #690).
    if (catalog.customAgency(agency) == null || catalog.canEditAgency(agency))
      DropdownMenuItem<CertificationOption>(
        value: const CertificationOption.addCustom(),
        child: Text(
          context.l10n.certificationAgencies_addCustomCertification,
          style: TextStyle(color: theme.colorScheme.primary),
        ),
      ),
    item(catalog.level(CertificationLevel.other.name)),
  ];
}
