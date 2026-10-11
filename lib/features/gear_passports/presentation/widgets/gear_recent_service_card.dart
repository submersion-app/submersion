import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/service_category_label.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The newest service records, and See all on the detail page, where the
/// full history lives (gear tag spec 9).
class GearRecentServiceCard extends ConsumerWidget {
  const GearRecentServiceCard({super.key, required this.equipmentId});

  static const int shown = 3;

  final String equipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final records = [
      ...?ref.watch(serviceRecordsForEquipmentProvider(equipmentId)).value,
    ]..sort((a, b) => b.serviceDate.compareTo(a.serviceDate));
    final kindsById = <String, ServiceKind>{
      ...?ref.watch(allServiceKindsByIdProvider).value,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.gearPassport_recent_title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (records.isNotEmpty)
                  TextButton(
                    onPressed: () => context.push('/equipment/$equipmentId'),
                    child: Text(l10n.gearPassport_recent_seeAll),
                  ),
              ],
            ),
            if (records.isEmpty)
              Text(l10n.gearPassport_recent_none)
            else
              Column(
                key: const Key('gearRecentService_rows'),
                children: [
                  for (final ServiceRecord r in records.take(shown))
                    ListTile(
                      key: ValueKey('gearRecentService_${r.id}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        kindsById[r.serviceKindId]?.name ??
                            r.serviceCategory.label(l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          units.formatDate(r.serviceDate),
                          if (r.provider?.trim().isNotEmpty ?? false)
                            r.provider!.trim(),
                        ].join(' · '),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
