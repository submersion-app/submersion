import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dialog for quickly creating a dive site from GPS coordinates extracted
/// from a photo.
///
/// Shows the coordinates, lets the user enter a site name, and prefills
/// Country / Region / City from a best-effort reverse geocode at open time
/// (fill-empty only, the same rule as the site edit page's "Use my
/// location"; never at save time). Returns the drafted [DiveSite] on
/// success, or null if cancelled.
class QuickSiteFromGpsDialog extends ConsumerStatefulWidget {
  final double latitude;
  final double longitude;

  const QuickSiteFromGpsDialog({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  /// Show the dialog and return the created site, or null if cancelled.
  static Future<DiveSite?> show(
    BuildContext context, {
    required double latitude,
    required double longitude,
  }) {
    return showDialog<DiveSite>(
      context: context,
      builder: (context) =>
          QuickSiteFromGpsDialog(latitude: latitude, longitude: longitude),
    );
  }

  @override
  ConsumerState<QuickSiteFromGpsDialog> createState() =>
      _QuickSiteFromGpsDialogState();
}

class _QuickSiteFromGpsDialogState
    extends ConsumerState<QuickSiteFromGpsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _countryController = TextEditingController();
  final _regionController = TextEditingController();
  final _cityController = TextEditingController();
  final _uuid = const Uuid();
  String? _locality;

  @override
  void initState() {
    super.initState();
    unawaited(_prefill());
  }

  /// Fill-empty geocoding at explicit capture time; a failure (offline,
  /// unsupported platform) leaves the fields for the diver to type.
  Future<void> _prefill() async {
    try {
      final place = await ref
          .read(locationServiceProvider)
          .reverseGeocode(
            widget.latitude,
            widget.longitude,
            languageCode: ref.read(placeNameLanguageProvider),
          );
      if (!mounted) return;
      setState(() {
        if (_countryController.text.isEmpty) {
          _countryController.text = place.country ?? '';
        }
        if (_regionController.text.isEmpty) {
          _regionController.text = place.region ?? '';
        }
        if (_cityController.text.isEmpty) {
          _cityController.text = place.locality ?? '';
        }
        _locality = place.locality;
      });
    } catch (_) {
      // The diver types what they know.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countryController.dispose();
    _regionController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final coordinates = units.formatCoordinates(
      widget.latitude,
      widget.longitude,
    );

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_location_alt, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(context.l10n.media_quickSiteDialog_title),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.media_quickSiteDialog_description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                label: context.l10n.media_gpsBanner_coordinates(coordinates),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.location_on,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          coordinates,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: context.l10n.media_quickSiteDialog_siteNameLabel,
                  hintText:
                      _locality ??
                      context.l10n.media_quickSiteDialog_siteNameHint,
                  prefixIcon: const Icon(Icons.edit),
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.l10n.media_quickSiteDialog_siteNameError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _countryController,
                decoration: InputDecoration(
                  labelText: context.l10n.diveSites_edit_field_country_label,
                  prefixIcon: const Icon(Icons.public),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _regionController,
                decoration: InputDecoration(
                  labelText: context.l10n.diveSites_edit_field_region_label,
                  prefixIcon: const Icon(Icons.map_outlined),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                decoration: InputDecoration(
                  labelText: context.l10n.diveSites_edit_field_city_label,
                  prefixIcon: const Icon(Icons.location_city),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.media_quickSiteDialog_cancelButton),
        ),
        FilledButton(
          onPressed: _createSite,
          child: Text(context.l10n.media_quickSiteDialog_createButton),
        ),
      ],
    );
  }

  void _createSite() {
    if (!_formKey.currentState!.validate()) return;

    String? orNull(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    final site = DiveSite(
      id: _uuid.v4(),
      name: _nameController.text.trim(),
      location: GeoPoint(widget.latitude, widget.longitude),
      country: orNull(_countryController),
      region: orNull(_regionController),
      city: orNull(_cityController),
    );

    Navigator.of(context).pop(site);
  }
}
