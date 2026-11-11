import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/gear_photo_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';

/// What stands for a gear item in the equipment list and its page header
/// (issue #3355): the cover photo the diver chose, or the type icon when
/// there is none, the photo is not on this device, or it fails to load.
///
/// An item with no cover reads nothing, so a long list pays for the photos
/// it shows and no more.
class EquipmentAvatar extends ConsumerStatefulWidget {
  const EquipmentAvatar({
    super.key,
    required this.item,
    required this.radius,
    this.backgroundColor,
    this.iconColor,
    this.iconSize,
  });

  final EquipmentItem item;
  final double radius;

  /// The icon fallback's colours; the theme's tertiary pair when null.
  final Color? backgroundColor;
  final Color? iconColor;

  /// The icon's size; the ambient icon size when null.
  final double? iconSize;

  @override
  ConsumerState<EquipmentAvatar> createState() => _EquipmentAvatarState();
}

class _EquipmentAvatarState extends ConsumerState<EquipmentAvatar> {
  /// The cover photo that failed to load, so it is not retried every build.
  String? _failedId;

  @override
  Widget build(BuildContext context) {
    final coverId = widget.item.coverMediaId;
    final cover = coverId == null || coverId == _failedId
        ? null
        : ref
              .watch(
                equipmentCoverProvider((
                  equipmentId: widget.item.id,
                  coverMediaId: coverId,
                )),
              )
              .value;
    if (cover == null) return _icon(context);

    final size = widget.radius * 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius / 2),
      child: SizedBox.square(
        dimension: size,
        child: MediaItemView(
          key: ValueKey('equipment_cover_${cover.id}'),
          item: cover,
          thumbnail: true,
          targetSize: Size.square(size * 2),
          fit: BoxFit.cover,
          onImageFailed: () {
            if (mounted) setState(() => _failedId = cover.id);
          },
        ),
      ),
    );
  }

  Widget _icon(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.backgroundColor ?? scheme.tertiaryContainer,
      child: Icon(
        equipmentTypeIcon(widget.item.type),
        size: widget.iconSize,
        color: widget.iconColor ?? scheme.onTertiaryContainer,
      ),
    );
  }
}
