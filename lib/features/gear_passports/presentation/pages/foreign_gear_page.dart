import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_codec.dart';
import 'package:submersion/features/gear_passports/presentation/providers/gear_passport_providers.dart';
import 'package:submersion/features/gear_passports/presentation/utils/gear_routes.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A read-only snapshot built from a gear tag alone (gear tag spec 10): what
/// the tag said when it was written, for gear that is not the diver's.
class ForeignGearPage extends ConsumerStatefulWidget {
  const ForeignGearPage({
    super.key,
    required this.tag,
    this.newerFormat = false,
  });

  /// The page for a foreign gear route's query, decoding it once.
  factory ForeignGearPage.fromQuery(String? t, {Key? key}) {
    final decoded = t == null ? null : GearTagCodec.decode(t);
    return decoded is GearTagDecoded
        ? ForeignGearPage(
            key: key,
            tag: decoded.payload,
            newerFormat: decoded.newerFormat,
          )
        : ForeignGearPage(key: key, tag: null);
  }

  final GearTagPayload? tag;
  final bool newerFormat;

  @override
  ConsumerState<ForeignGearPage> createState() => _ForeignGearPageState();
}

class _ForeignGearPageState extends ConsumerState<ForeignGearPage> {
  static final _log = LoggerService.forClass(ForeignGearPage);
  bool _busy = false;

  String _typeLabel(GearTagPayload tag) =>
      tag.type?.localizedName(context.l10n) ??
      context.l10n.gearPassport_unknownType;

  Future<void> _addToGear(GearTagPayload tag) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final l10n = context.l10n;
    final fallbackName = _typeLabel(tag);
    setState(() => _busy = true);
    try {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      final item = await ref
          .read(gearAdoptionServiceProvider)
          .adopt(tag, diverId: diverId, fallbackName: fallbackName);
      if (!mounted) return;
      router.pushReplacement(gearPassportLocation(item.id));
    } on PassportIdInUse catch (e) {
      // The holder's name is a courtesy: if it cannot be read, name the id
      // rather than leave the button disabled with no message.
      String? holderName;
      try {
        holderName =
            (await ref
                    .read(equipmentRepositoryProvider)
                    .getEquipmentById(e.equipmentId))
                ?.name;
      } catch (lookupError, stackTrace) {
        _log.error(
          'Failed to read the item holding a tag',
          error: lookupError,
          stackTrace: stackTrace,
        );
      }
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.passport_tag_linkInUse(holderName ?? e.equipmentId),
          ),
        ),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to add scanned gear',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.gearPassport_foreign_addFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final tag = widget.tag;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.gearPassport_foreign_title)),
      body: tag == null
          ? Center(child: Text(l10n.gearPassport_tag_linkInvalid))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tag.name ?? _typeLabel(tag),
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Chip(
                      avatar: Icon(
                        tag.type == null
                            ? Icons.inventory_2_outlined
                            : equipmentTypeIcon(tag.type!),
                        size: 18,
                      ),
                      label: Text(_typeLabel(tag)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  if ([tag.brand, tag.model].whereType<String>().isNotEmpty)
                    Text(
                      [tag.brand, tag.model].whereType<String>().join(' '),
                      style: theme.textTheme.titleMedium,
                    ),
                  if (tag.serial case final serial?)
                    Text(l10n.passport_foreign_serial(serial)),
                  if (tag.lastService case final last?) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.gearPassport_entry_lastService(
                        units.formatDate(last),
                      ),
                    ),
                  ],
                  if (tag.writtenOn case final written?)
                    Text(
                      l10n.passport_foreign_writtenOn(
                        units.formatDate(written),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  if (widget.newerFormat) ...[
                    const SizedBox(height: 8),
                    Text(l10n.passport_scan_newerFormat),
                  ],
                  const SizedBox(height: 16),
                  Text(l10n.gearPassport_foreign_notInGear),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _addToGear(tag),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.passport_foreign_addToGear),
                  ),
                ],
              ),
            ),
    );
  }
}
