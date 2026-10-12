import 'package:flutter/material.dart';

import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_region.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Form state shared by the S3 sync settings page and the shared site
/// library connect page.
class S3FormController extends ChangeNotifier {
  S3FormController({String defaultPrefix = 'submersion-sync/'})
    : prefix = TextEditingController(text: defaultPrefix) {
    endpoint.addListener(_onEndpointChanged);
    // The auto-detected region helper hides while the field holds a value.
    region.addListener(notifyListeners);
  }

  final endpoint = TextEditingController();
  final region = TextEditingController();
  final bucket = TextEditingController();
  final TextEditingController prefix;
  final accessKey = TextEditingController();
  final secretKey = TextEditingController();

  bool get pathStyle => _pathStyle;
  bool _pathStyle = false;

  /// Once the user flips the switch (or a stored config sets it), it stops
  /// tracking the endpoint field.
  bool _pathStyleTouched = false;

  bool get secretVisible => _secretVisible;
  bool _secretVisible = false;

  void toggleSecretVisible() {
    _secretVisible = !_secretVisible;
    notifyListeners();
  }

  void setPathStyle(bool value) {
    _pathStyle = value;
    _pathStyleTouched = true;
    notifyListeners();
  }

  void _onEndpointChanged() {
    final trimmed = endpoint.text.trim();
    final host = Uri.tryParse(trimmed)?.host.toLowerCase() ?? '';
    // The auto-flip is for MinIO, NAS, and other self-hosted servers. AWS
    // prefers virtual-hosted addressing, and the global endpoint only
    // reaches cross-region buckets in that mode.
    final wantsPathStyle =
        trimmed.isNotEmpty &&
        host != 'amazonaws.com' &&
        !host.endsWith('.amazonaws.com');
    if (!_pathStyleTouched) _pathStyle = wantsPathStyle;
    notifyListeners();
  }

  bool get isInsecure =>
      endpoint.text.trim().toLowerCase().startsWith('http://');

  /// Whether the user typed a bucket or keys, so a slow load of a stored
  /// config must not overwrite them.
  bool get hasTyping =>
      bucket.text.isNotEmpty ||
      accessKey.text.isNotEmpty ||
      secretKey.text.isNotEmpty;

  void load(S3Config existing) {
    // Legacy configs stored AWS as a blank endpoint; surface the real URL
    // so the (now required) field re-saves without retyping.
    endpoint.text = existing.isAws
        ? 'https://s3.${existing.region}.amazonaws.com'
        : existing.endpoint;
    region.text = existing.region;
    bucket.text = existing.bucket;
    prefix.text = existing.prefix;
    accessKey.text = existing.accessKeyId;
    secretKey.text = existing.secretAccessKey;
    // A stored choice (even an auto-derived one) must not silently flip.
    _pathStyle = existing.pathStyle;
    _pathStyleTouched = true;
    notifyListeners();
  }

  S3Config build() {
    final manualRegion = region.text.trim();
    return S3Config(
      endpoint: endpoint.text,
      region: manualRegion.isEmpty ? deriveRegion(endpoint.text) : manualRegion,
      bucket: bucket.text,
      prefix: prefix.text,
      pathStyle: _pathStyle,
      accessKeyId: accessKey.text,
      secretAccessKey: secretKey.text,
    );
  }

  @override
  void dispose() {
    for (final c in [endpoint, region, bucket, prefix, accessKey, secretKey]) {
      c.dispose();
    }
    super.dispose();
  }
}

/// The S3 server fields: endpoint, bucket, keys, and an Advanced section
/// with region, key prefix (when [showPrefix]) and addressing style. The
/// caller supplies the surrounding [Form].
class S3ServerFields extends StatelessWidget {
  const S3ServerFields({
    super.key,
    required this.controller,
    this.showPrefix = true,
    this.keyPrefix = 's3',
  });

  final S3FormController controller;

  /// False where the folder is fixed by the caller (a shared site library
  /// keeps its own), so the prefix field would only mislead.
  final bool showPrefix;
  final String keyPrefix;

  Key _k(String name) => Key('$keyPrefix-$name');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.isInsecure)
            Card(
              key: _k('http-warning'),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_open,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l10n.settings_s3Config_warning_http)),
                  ],
                ),
              ),
            ),
          TextFormField(
            key: _k('endpoint'),
            controller: controller.endpoint,
            decoration: InputDecoration(
              labelText: l10n.settings_s3Config_field_endpoint_label,
              // In-field hint: visible only while blank, so it cannot be
              // misread as describing the Bucket field below.
              hintText: l10n.settings_s3Config_field_endpoint_helper,
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            // Sub-paths break SigV4 key addressing; host-only endpoints are
            // accepted.
            validator: (value) {
              final trimmed = (value ?? '').trim();
              if (trimmed.isEmpty) {
                return l10n.settings_s3Config_validation_required;
              }
              final uri = Uri.tryParse(trimmed);
              final valid =
                  uri != null &&
                  (uri.scheme == 'http' || uri.scheme == 'https') &&
                  uri.host.isNotEmpty;
              if (!valid) {
                return l10n.settings_s3Config_validation_endpointInvalid;
              }
              if (uri.path.isNotEmpty && uri.path != '/') {
                return l10n.settings_s3Config_validation_endpointPath;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: _k('bucket'),
            controller: controller.bucket,
            decoration: InputDecoration(
              labelText: l10n.settings_s3Config_field_bucket_label,
            ),
            autocorrect: false,
            validator: (value) => (value ?? '').trim().isEmpty
                ? l10n.settings_s3Config_validation_required
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: _k('access-key'),
            controller: controller.accessKey,
            decoration: InputDecoration(
              labelText: l10n.settings_s3Config_field_accessKeyId_label,
            ),
            autocorrect: false,
            enableSuggestions: false,
            validator: (value) => (value ?? '').trim().isEmpty
                ? l10n.settings_s3Config_validation_required
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: _k('secret-key'),
            controller: controller.secretKey,
            decoration: InputDecoration(
              labelText: l10n.settings_s3Config_field_secretAccessKey_label,
              suffixIcon: IconButton(
                icon: Icon(
                  controller.secretVisible
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: controller.toggleSecretVisible,
              ),
            ),
            obscureText: !controller.secretVisible,
            autocorrect: false,
            enableSuggestions: false,
            validator: (value) => (value ?? '').trim().isEmpty
                ? l10n.settings_s3Config_validation_required
                : null,
          ),
          ExpansionTile(
            key: _k('advanced'),
            title: Text(l10n.settings_s3Config_advanced_title),
            tilePadding: EdgeInsets.zero,
            // Top inset keeps the first child's floating label clear of the
            // header row.
            childrenPadding: const EdgeInsets.only(top: 12, bottom: 8),
            // Suppress the M3 outline the tile draws when expanded.
            shape: const Border(),
            collapsedShape: const Border(),
            children: [
              TextFormField(
                key: _k('region'),
                controller: controller.region,
                decoration: InputDecoration(
                  labelText: l10n.settings_s3Config_field_region_label,
                  helperText: controller.region.text.trim().isEmpty
                      ? l10n.settings_s3Config_field_region_helperAuto(
                          deriveRegion(controller.endpoint.text),
                        )
                      : null,
                ),
                autocorrect: false,
              ),
              if (showPrefix) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: _k('prefix'),
                  controller: controller.prefix,
                  decoration: InputDecoration(
                    labelText: l10n.settings_s3Config_field_prefix_label,
                  ),
                  autocorrect: false,
                ),
              ],
              SwitchListTile(
                key: _k('path-style'),
                title: Text(l10n.settings_s3Config_field_pathStyle_label),
                subtitle: Text(l10n.settings_s3Config_field_pathStyle_subtitle),
                value: controller.pathStyle,
                onChanged: controller.setPathStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
